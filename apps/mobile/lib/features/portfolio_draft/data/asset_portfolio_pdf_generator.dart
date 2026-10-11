import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/portfolio_content.dart';
import '../domain/portfolio_pdf.dart';

const _iconIds = {
  'folder',
  'file-text',
  'panels-top-left',
  'home',
  'image',
  'camera',
  'user-round',
};

/// Original TTF/SVG читаются из assets; контент и фото не загружаются по URL.
final class AssetPortfolioPdfGenerator implements PortfolioPdfGenerator {
  AssetPortfolioPdfGenerator({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<Uint8List> generate(
    PortfolioContent savedContent, {
    Uint8List? avatarBytes,
  }) async {
    try {
      final regular = await _bundle.load('assets/fonts/Manrope-Regular.ttf');
      final bold = await _bundle.load('assets/fonts/Manrope-Bold.ttf');
      final icons = <String, String>{};
      for (final id in _iconIds) {
        icons[id] = await _bundle.loadString('assets/icons/lucide/$id.svg');
      }
      return await generatePortfolioPdfBytes(
        savedContent,
        regularFont: regular,
        boldFont: bold,
        stockIconSvg: icons,
        avatarBytes: avatarBytes,
      );
    } on PortfolioPdfFailure {
      rethrow;
    } catch (_) {
      throw const PortfolioPdfFailure(PortfolioPdfFailureKind.generation);
    }
  }
}

/// Отделён от Flutter assets для проверок настоящих PDF без SDK/network IO.
Future<Uint8List> generatePortfolioPdfBytes(
  PortfolioContent content, {
  required ByteData regularFont,
  required ByteData boldFont,
  required Map<String, String> stockIconSvg,
  Uint8List? avatarBytes,
}) async {
  try {
    final regular = pw.Font.ttf(regularFont);
    final bold = pw.Font.ttf(boldFont);
    final document = pw.Document(title: 'Портфолио', creator: 'StackCard');
    final visible = content.blocks
        .where((block) => block.visible)
        .map((block) => block.kind)
        .toSet();
    bool includes(PortfolioBlockKind kind) => visible.contains(kind);
    final widgets = <pw.Widget>[];
    const ink = PdfColor.fromInt(0xff151518);
    const meta = PdfColor.fromInt(0xff66666f);
    final bodyStyle = pw.TextStyle(font: regular, fontSize: 11, color: ink);
    final headingStyle = pw.TextStyle(font: bold, fontSize: 15, color: ink);
    pw.Widget text(
      String value, {
      pw.TextStyle? style,
      bool centered = false,
    }) => pw.Text(
      value,
      style: style ?? bodyStyle,
      textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
      overflow: pw.TextOverflow.visible,
    );
    void paragraph(String value, {bool centered = false}) {
      if (value.trim().isEmpty) return;
      // Wrap переносит целые строки между страницами, сохраняя верхнее поле.
      // TextOverflow.span в pdf 3.13 переносит continuation выше page margin.
      for (final line in value.split('\n')) {
        if (line.trim().isEmpty) {
          widgets.add(pw.SizedBox(height: 14));
          continue;
        }
        widgets.add(
          _FullWidthWrap(
            alignment: centered
                ? pw.WrapAlignment.center
                : pw.WrapAlignment.start,
            spacing:
                regular
                    .getFont(pw.Context(document: document.document))
                    .stringMetrics(' ')
                    .advanceWidth *
                11,
            runSpacing: 3,
            children: line
                .trim()
                .split(RegExp(r'\s+'))
                .map((word) => text(word))
                .toList(),
          ),
        );
      }
      widgets.add(pw.SizedBox(height: 8));
    }

    void heading(String value) {
      widgets.add(pw.NewPage(freeSpace: 52));
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(text(value, style: headingStyle));
      widgets.add(pw.SizedBox(height: 8));
    }

    void link(String label, String value) {
      final destination = _safeHref(value);
      if (destination == null) return;
      final title = label.trim().isEmpty ? value : '$label — $value';
      widgets.add(
        pw.UrlLink(
          destination: destination,
          child: text(
            title,
            style: bodyStyle.copyWith(decoration: pw.TextDecoration.underline),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    final profile = content.profile;
    if (includes(PortfolioBlockKind.profile)) {
      if ((profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty) &&
          (avatarBytes == null || avatarBytes.isEmpty)) {
        throw const PortfolioPdfFailure(PortfolioPdfFailureKind.unavailable);
      }
      if (avatarBytes != null && avatarBytes.isNotEmpty) {
        widgets.add(
          pw.Center(
            child: pw.ClipOval(
              child: pw.Image(
                pw.MemoryImage(avatarBytes),
                width: 80,
                height: 80,
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 12));
      }
      if (profile.name.trim().isNotEmpty) {
        widgets.add(
          pw.Center(
            child: text(
              profile.name,
              centered: true,
              style: headingStyle.copyWith(fontSize: 22),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
      }
      paragraph(profile.headline, centered: true);
    }
    if (includes(PortfolioBlockKind.about)) {
      paragraph(profile.bio, centered: true);
    }
    if (includes(PortfolioBlockKind.location) && profile.publishLocation) {
      paragraph(profile.locationText, centered: true);
    }
    final projects = includes(PortfolioBlockKind.featuredProjects)
        ? content.projects.where((project) => project.visible).toList()
        : <PortfolioProject>[];
    if (projects.isNotEmpty) {
      heading('Проекты');
      for (final project in projects) {
        final id = _iconIds.contains(project.iconId)
            ? project.iconId
            : 'folder';
        final svg = stockIconSvg[id] ?? stockIconSvg['folder'];
        if (svg == null) {
          throw const PortfolioPdfFailure(PortfolioPdfFailureKind.invalidData);
        }
        widgets.add(pw.NewPage(freeSpace: 48));
        widgets.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SvgImage(
                svg: svg.replaceAll('currentColor', '#151518'),
                width: 20,
                height: 20,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: text(
                  project.title,
                  style: headingStyle.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
        paragraph(project.description);
        paragraph(project.contribution);
        if (project.technologies.isNotEmpty) {
          paragraph(project.technologies.join(' · '));
        }
        link('Проект', project.liveUrl);
        link('Исходный код', project.repositoryUrl);
        widgets.add(pw.SizedBox(height: 8));
      }
    }
    final skills = includes(PortfolioBlockKind.skills)
        ? content.skills.where((skill) => skill.name.trim().isNotEmpty).toList()
        : <Skill>[];
    if (skills.isNotEmpty) {
      heading('Навыки');
      paragraph(skills.map((skill) => skill.name).join(' · '));
    }
    final experience = includes(PortfolioBlockKind.experience)
        ? content.experience.where(
            (item) => [
              item.role,
              item.organization,
              item.period,
              item.description,
            ].any((value) => value.trim().isNotEmpty),
          )
        : <Experience>[];
    if (experience.isNotEmpty) {
      heading('Опыт');
      for (final item in experience) {
        paragraph(item.role);
        paragraph(
          [
            item.organization,
            item.period,
          ].where((value) => value.trim().isNotEmpty).join(' · '),
        );
        paragraph(item.description);
      }
    }
    final education = includes(PortfolioBlockKind.education)
        ? content.education.where(
            (item) => [
              item.qualification,
              item.institution,
              item.period,
              item.description,
            ].any((value) => value.trim().isNotEmpty),
          )
        : <Education>[];
    if (education.isNotEmpty) {
      heading('Образование');
      for (final item in education) {
        paragraph(item.qualification);
        paragraph(
          [
            item.institution,
            item.period,
          ].where((value) => value.trim().isNotEmpty).join(' · '),
        );
        paragraph(item.description);
      }
    }
    final contacts = content.links.where(
      (contact) =>
          contact.visible &&
          contact.publishAllowed &&
          includes(
            contact.kind == SocialLinkKind.github
                ? PortfolioBlockKind.github
                : PortfolioBlockKind.links,
          ) &&
          _safeHref(contact.url) != null,
    );
    if (contacts.isNotEmpty) {
      heading('Контакты и ссылки');
      for (final contact in contacts) {
        link(contact.label, contact.url);
      }
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        maxPages: 500,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: bodyStyle.copyWith(fontSize: 9, color: meta),
              ),
            ],
          ),
        ),
        build: (_) => widgets.isEmpty ? [pw.SizedBox()] : widgets,
      ),
    );
    final bytes = await document.save();
    if (!isPortfolioPdfBytes(bytes)) {
      throw const PortfolioPdfFailure(PortfolioPdfFailureKind.generation);
    }
    return bytes;
  } on PortfolioPdfFailure {
    rethrow;
  } catch (_) {
    throw const PortfolioPdfFailure(PortfolioPdfFailureKind.generation);
  }
}

String? _safeHref(String value) {
  if (value.isEmpty || value.contains(RegExp(r'[\s\x00-\x1f\\]'))) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty) return null;
  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.port <= 65535) {
    return uri.toString();
  }
  if ((uri.scheme == 'mailto' || uri.scheme == 'tel') &&
      uri.path.isNotEmpty &&
      !uri.hasAuthority) {
    return uri.toString();
  }
  return null;
}

/// Прямой дочерний Wrap разбивается между страницами и центрирует короткие строки.
final class _FullWidthWrap extends pw.Wrap {
  _FullWidthWrap({
    required super.children,
    required super.spacing,
    required super.runSpacing,
    required super.alignment,
  });

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    super.layout(
      context,
      constraints.copyWith(minWidth: constraints.maxWidth),
      parentUsesSize: parentUsesSize,
    );
  }
}
