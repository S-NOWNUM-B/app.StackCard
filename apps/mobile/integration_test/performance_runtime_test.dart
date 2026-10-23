import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FrameTiming, ImageByteFormat;

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/features/portfolio_draft/data/asset_portfolio_pdf_generator.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/developer_card_qr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:qr/qr.dart';
import 'package:path_provider/path_provider.dart';

import '../tool/performance/baseline_projects.dart';
import '../tool/performance/fixture.dart';

/// Изолированный profile harness: VM timeline/GC и настоящие Android frames.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android native profile measurements', (tester) async {
    expect(const bool.fromEnvironment('RUN_PERFORMANCE_ACCEPTANCE'), isTrue);
    expect(kProfileMode, isTrue);
    debugProfileBuildsEnabled = true;
    final originalError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(
        'PROFILE_ERROR ${details.exceptionAsString()}\n${details.stack}',
      );
      originalError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalError);
    final workspace = performanceWorkspace().copyWith(
      githubUsername: 'dart-lang',
    );
    expect(validatePortfolioContent(workspace), isEmpty);
    final repository = MemoryPortfolioDraftRepository();
    await repository.save(workspace, expectedRevision: 0, notes: 'PRIVATE');
    final results = <String, Object?>{
      'mode': 'profile',
      'os': Platform.operatingSystem,
      'dart': Platform.version,
      'pid': pid,
      'fixture': {
        'projects': 200,
        'technologiesPerProject': 20,
        'skills': 200,
        'experience': 30,
        'education': 20,
        'links': 10,
        'documents': 21,
      },
    };
    final vm = await _Vm.connect();
    final traces = Directory(
      '${(await getExternalStorageDirectory())!.path}/phase16-$pid',
    );
    await traces.create(recursive: true);
    results['traceDirectory'] = traces.path;
    addTearDown(vm.close);
    Future<void> mount(Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: StackCardTheme.light,
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppStrings.supportedLocales,
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name, Future<void> Function() action) async {
      final frames = <FrameTiming>[];
      void timing(List<FrameTiming> values) => frames.addAll(values);
      await Future<void>.delayed(const Duration(seconds: 1));
      binding.addTimingsCallback(timing);
      final watch = Stopwatch()..start();
      await binding.traceAction(action, reportKey: '$name.timeline');
      watch.stop();
      await Future<void>.delayed(const Duration(seconds: 1));
      binding.removeTimingsCallback(timing);
      await _flushTrace(binding, traces, name);
      final heap = await vm.heap();
      results[name] = {
        'wallMs': watch.elapsedMicroseconds / 1000,
        'mountedElements': tester.allElements.length,
        'frames': [
          for (final f in frames)
            {
              'buildUs': f.buildDuration.inMicroseconds,
              'rasterUs': f.rasterDuration.inMicroseconds,
              'totalUs': f.totalSpan.inMicroseconds,
            },
        ],
        'postGcHeap': heap,
      };
      expect(frames, isNotEmpty);
      expect(find.textContaining('LEGACY_PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print('NATIVE_PROFILE $name ${jsonEncode(results[name])}');
    }

    for (var repeat = 0; repeat < 2; repeat++) {
      for (final baseline in [true, false]) {
        await mount(const SizedBox.shrink());
        await capture(
          'library.${baseline ? 'before' : 'after'}.$repeat',
          () async {
            await mount(
              baseline
                  ? const BaselineProjectsScreen()
                  : const ProjectsScreen(),
            );
            final scroll = find.byType(Scrollable).first;
            for (var i = 0; i < 8; i++) {
              await tester.drag(scroll, const Offset(0, -500));
              await tester.pumpAndSettle();
            }
          },
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final picture = await boundary.toImage(pixelRatio: 1);
        final png = await picture.toByteData(format: ImageByteFormat.png);
        await File(
          '${traces.path}/library.${baseline ? 'before' : 'after'}.$repeat.png',
        ).writeAsBytes(png!.buffer.asUint8List(), flush: true);
        picture.dispose();
      }
    }
    await capture('home', () => mount(const HomeScreen()));
    await capture(
      'editor.mount',
      () => mount(const MainPortfolioEditorScreen()),
    );
    // Разделы больше не переставляются; замеряем прокрутку до контактов.
    final contacts = find.byKey(const Key('main.editor.section.links'));
    final scroll = find.byType(Scrollable).first;
    await capture('editor.scroll', () async {
      await tester.scrollUntilVisible(
        contacts,
        500,
        scrollable: scroll,
        maxScrolls: 120,
      );
      await tester.pumpAndSettle();
    });
    expect((await repository.read())!.content, workspace);
    for (final baseline in [true, false]) {
      final url = Uri.parse(
        'http://127.0.0.1:3800/d/0123456789abcdef0123456789abcdef',
      );
      await capture('qr.${baseline ? 'before' : 'after'}', () async {
        for (var i = 0; i < 25; i++) {
          // Тот же parent/State: повторно строится только subtree.
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: baseline
                    ? _BaselineQr(url: url)
                    : DeveloperCardQr(url: url),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
      });
    }
    await capture('github.real.pagination', () async {
      await mount(const GitHubImportScreen());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GitHubImportScreen)),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (container
          .read(githubImportControllerProvider)
          .repositories
          .isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Actual GitHub UI loading deadline');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      final before = container.read(githubImportControllerProvider);
      expect(before.repositories.length, 30);
      final more = find.text(
        AppStrings.of(tester.element(find.byType(GitHubImportScreen)))
            .tr('github.more'),
      );
      await tester.scrollUntilVisible(
        more,
        600,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      await tester.tap(more);
      while (container.read(githubImportControllerProvider).loadingMore) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Actual GitHub page deadline');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      final after = container.read(githubImportControllerProvider);
      expect(after.repositories.length, greaterThan(30));
      expect(after.pageFailure, isNull);
      results['githubActualRepositories'] = after.repositories.length;
      await tester.pumpAndSettle();
    });
    await capture('card.avatar', () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            developerCardRepositoryProvider.overrideWithValue(_ProfileCards()),
            documentPublicationControllerProvider.overrideWith(
              () => _ProfilePublications(),
            ),
          ],
          child: MaterialApp(
            theme: StackCardTheme.light,
            home: const DeveloperCardScreen(documentId: 'profile-main'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperCardQr), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await tester.pumpAndSettle();
    });
    await capture('pdf.avatar', () async {
      final avatar = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 512, height: 512)),
      );
      final watch = Stopwatch()..start();
      final bytes = await AssetPortfolioPdfGenerator().generate(
        resolvedMainPortfolioContent(workspace)!,
        avatarBytes: avatar,
      );
      watch.stop();
      expect(isPortfolioPdfBytes(bytes), isTrue);
      results['pdf'] = {
        'bytes': bytes.length,
        'wallMs': watch.elapsedMicroseconds / 1000,
        'avatar': 'JPEG512',
      };
      await tester.pump();
    });
    await mount(const SizedBox.shrink());
    results['unmountedPostGcHeap'] = await vm.heap();
    binding.reportData!['measurements'] = results;
    final hold = const int.fromEnvironment('PERFORMANCE_HOLD_SECONDS');
    for (var i = 0; i < hold; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}

class _Vm {
  _Vm(this.socket) {
    socket.listen((message) {
      final value = jsonDecode(message as String) as Map<String, dynamic>;
      final completer = pending.remove(value['id']);
      if (value['error'] != null) {
        completer?.completeError(StateError('${value['error']}'));
      } else {
        completer?.complete(value['result'] as Map<String, dynamic>);
      }
    });
  }
  final WebSocket socket;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  var serial = 0;
  static Future<_Vm> connect() async {
    final info = await developer.Service.getInfo();
    return _Vm(
      await WebSocket.connect(
        'ws://127.0.0.1:${info.serverUri!.port}${info.serverUri!.path}ws',
      ),
    );
  }

  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, Object?>? params,
  ]) {
    final id = ++serial;
    final c = Completer<Map<String, dynamic>>();
    pending[id] = c;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params ?? {},
      }),
    );
    return c.future.timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> heap() async {
    final vm = await rpc('getVM');
    final isolate = (vm['isolates'] as List).first as Map;
    final profile = await rpc('getAllocationProfile', {
      'isolateId': isolate['id'],
      'gc': true,
    });
    final members = (profile['members'] as List).cast<Map<String, dynamic>>();
    const selected = {
      'ProjectLibraryCard',
      '_MainPortfolioEditorScreenState',
      '_DeveloperCardQrState',
      '_BaselineProjectsScreenState',
    };
    return {
      ...profile['memoryUsage'] as Map<String, dynamic>,
      'classes': [
        for (final member in members)
          if (selected.contains((member['class'] as Map)['name']))
            {
              'name': (member['class'] as Map)['name'],
              'instancesCurrent': member['instancesCurrent'],
              'bytesCurrent': member['bytesCurrent'],
            },
      ],
    };
  }

  Future<void> close() async {
    await socket.close();
  }
}

class _BaselineQr extends StatelessWidget {
  const _BaselineQr({required this.url});
  final Uri url;
  @override
  Widget build(BuildContext context) {
    final matrix = QrImage(
      QrCode.fromData(data: '$url', errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return CustomPaint(
      size: const Size(240, 240),
      painter: _BaselinePainter(matrix),
    );
  }
}

class _BaselinePainter extends CustomPainter {
  _BaselinePainter(this.image);
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final module = size.width / (image.moduleCount + 8);
    final ink = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH((x + 4) * module, (y + 4) * module, module, module),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BaselinePainter oldDelegate) => true;
}

final _profilePublication = DocumentPublication(
  documentId: 'profile-main',
  publicId: '0123456789abcdef0123456789abcdef',
  version: 1,
  visibility: DocumentPublicationVisibility.published,
  sourceMutationId: 'fixture',
  url: Uri.parse('http://127.0.0.1:3800/d/0123456789abcdef0123456789abcdef'),
);

class _ProfileCards implements DeveloperCardRepository {
  @override
  String get ownerUid => 'profile-fixture';
  @override
  Stream<DeveloperCard> watch(DocumentPublication publication) => Stream.value(
    DeveloperCard(
      publication: publication,
      title: 'Profile fixture',
      name: 'Анна Ёлкина',
      headline: 'Разработчик',
      username: 'anna',
      technologies: ['Dart', 'Flutter'],
      avatarBytes: Uint8List.fromList(
        image.encodeJpg(image.Image(width: 512, height: 512)),
      ),
    ),
  );
}

class _ProfilePublications extends DocumentPublicationController {
  @override
  DocumentPublicationState build() => DocumentPublicationState(
    loading: false,
    inventory: DocumentPublicationInventory(
      publications: [_profilePublication],
      lifecycleGeneration: 1,
    ),
  );
  @override
  Future<void> load() async {}
}

Future<void> _flushTrace(
  IntegrationTestWidgetsFlutterBinding binding,
  Directory output,
  String name,
) async {
  final trace = binding.reportData!.remove('$name.timeline');
  await File('${output.path}/$name.timeline.json.gz')
      .writeAsBytes(gzip.encode(utf8.encode(jsonEncode(trace))), flush: true);
}
