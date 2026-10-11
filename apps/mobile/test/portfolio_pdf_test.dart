import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_stackcard/features/portfolio_draft/data/asset_portfolio_pdf_generator.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData regular;
  late ByteData bold;
  late Map<String, String> icons;

  setUpAll(() async {
    regular = ByteData.sublistView(
      await File('assets/fonts/Manrope-Regular.ttf').readAsBytes(),
    );
    bold = ByteData.sublistView(
      await File('assets/fonts/Manrope-Bold.ttf').readAsBytes(),
    );
    icons = {
      for (final id in [
        'folder',
        'file-text',
        'panels-top-left',
        'home',
        'image',
        'camera',
        'user-round',
      ])
        id: await File('assets/icons/lucide/$id.svg').readAsString(),
    };
  });

  Future<Uint8List> generate(PortfolioContent content, {Uint8List? avatar}) =>
      generatePortfolioPdfBytes(
        content,
        regularFont: regular,
        boldFont: bold,
        stockIconSvg: icons,
        avatarBytes: avatar,
      );

  Future<void> fixture(String name, Uint8List bytes) async {
    final directory = Platform.environment['STACKCARD_PDF_FIXTURE_DIR'];
    if (directory == null) return;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name').writeAsBytes(bytes);
  }

  test(
    'empty saved portfolio generates a genuine PDF without placeholder data',
    () async {
      final bytes = await generate(PortfolioContent());
      expect(isPortfolioPdfBytes(bytes), isTrue);
      final source = latin1.decode(bytes);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(source), hasLength(1));
      expect(source, contains('/ToUnicode'));
      expect(source, isNot(contains('/Subtype/Image')));
      await fixture('mobile-empty.pdf', bytes);
    },
  );

  test('long Cyrillic portfolio spans pages and preserves links, avatar and stock icons', () async {
    final avatarImage = image.Image(width: 64, height: 64);
    image.fill(avatarImage, color: image.ColorRgb8(196, 209, 220));
    final avatar = Uint8List.fromList(image.encodeJpg(avatarImage));
    final paragraph = List.filled(
      180,
      'Длинное описание проекта на русском языке: перенос текста не теряет содержание. ',
    ).join();
    final content = PortfolioContent(
      profile: const PortfolioProfile(
        name: 'Анна Ёлкина',
        headline: 'Разработчик приложений',
        bio: 'Сохранённое портфолио с кириллицей.',
        locationText: 'Алматы, Казахстан',
        publishLocation: true,
        avatarPath:
            'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg',
      ),
      projects: [
        for (final id in icons.keys)
          PortfolioProject(
            id: id,
            iconId: id,
            title: 'Проект $id',
            description: id == 'folder' ? paragraph : 'Описание проекта.',
            technologies: const ['Flutter', 'TypeScript'],
            repositoryUrl: 'https://github.com/example/$id',
            liveUrl: 'https://example.com/$id',
            imagePaths: const ['LEGACY_PROJECT_IMAGE_MUST_NOT_EXPORT'],
          ),
        PortfolioProject(
          id: 'hidden',
          title: 'SECRET_HIDDEN_PROJECT',
          description: 'private',
          technologies: const [],
          visible: false,
        ),
      ],
      skills: const [Skill(id: 'dart', name: 'Dart')],
      links: const [
        SocialLink(
          id: 'site',
          label: 'Сайт',
          url: 'https://example.com/contact',
          publishAllowed: true,
        ),
        SocialLink(
          id: 'email',
          label: 'Почта',
          kind: SocialLinkKind.email,
          url: 'mailto:anna@example.com',
          publishAllowed: true,
        ),
        SocialLink(
          id: 'private',
          label: 'PRIVATE_CONTACT',
          url: 'https://secret.example.com/private',
        ),
      ],
    );
    final bytes = await generate(content, avatar: avatar);
    final source = latin1.decode(bytes);
    expect(isPortfolioPdfBytes(bytes), isTrue);
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(source).length,
      greaterThan(1),
    );
    expect(source, contains('/ToUnicode'));
    expect(source, contains('/Subtype/Image'));
    expect(source, contains('https://example.com/contact'));
    expect(source, contains('mailto:anna@example.com'));
    expect(source, isNot(contains('secret.example.com')));
    expect(source, isNot(contains('LEGACY_PROJECT_IMAGE_MUST_NOT_EXPORT')));
    await fixture('mobile-long.pdf', bytes);
  });

  test(
    'an unavailable saved avatar prevents incomplete successful export',
    () async {
      await expectLater(
        generate(
          PortfolioContent(
            profile: const PortfolioProfile(
              avatarPath: 'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg',
            ),
          ),
        ),
        throwsA(
          isA<PortfolioPdfFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioPdfFailureKind.unavailable,
          ),
        ),
      );
    },
  );

  test(
    'available legacy URL avatar bytes are embedded in a genuine PDF',
    () async {
      final content = PortfolioContent(
        profile: const PortfolioProfile(
          name: 'Прежний профиль',
          avatarUrl: 'https://images.example.com/avatar.jpg',
        ),
      );
      final avatar = image.encodeJpg(image.Image(width: 64, height: 64));
      final bytes = await generate(content, avatar: avatar);
      expect(isPortfolioPdfBytes(bytes), isTrue);
      expect(latin1.decode(bytes), contains('/Subtype/Image'));
      await expectLater(
        generate(content),
        throwsA(
          isA<PortfolioPdfFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioPdfFailureKind.unavailable,
          ),
        ),
      );
    },
  );

  test('hidden photo and city remain excluded from the export', () async {
    final bytes = await generate(
      PortfolioContent(
        profile: const PortfolioProfile(
          avatarPath:
              'accounts/test-owner/media/0123456789abcdef0123456789abcdef.jpg',
          locationText: 'PRIVATE_CITY',
          publishLocation: false,
        ),
        blocks: const [
          PortfolioBlock(kind: PortfolioBlockKind.profile, visible: false),
          PortfolioBlock(kind: PortfolioBlockKind.location),
        ],
      ),
    );
    expect(latin1.decode(bytes), isNot(contains('/Subtype/Image')));
    await fixture('mobile-private.pdf', bytes);
  });
}
