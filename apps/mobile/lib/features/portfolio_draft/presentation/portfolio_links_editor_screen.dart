import 'package:flutter/material.dart';

import '../domain/portfolio_content.dart';
import 'builder_collection_editor.dart';
import 'builder_editor_widgets.dart';

class PortfolioLinksEditorScreen extends StatelessWidget {
  const PortfolioLinksEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => BuilderCollectionEditor<SocialLink>(
    titleKey: 'builderForm.linksTitle',
    readItems: (content) => content.links,
    writeItems: (content, items) => content.copyWith(links: items),
    itemId: (link) => link.id,
    itemTitle: (link) => link.label,
    itemSummary: (link) => link.url,
    fields: (link) => [
      BuilderFieldSpec(
        name: 'linkLabel',
        labelKey: 'builderForm.linkLabel',
        value: link?.label ?? '',
        maxLength: 80,
        required: true,
      ),
      BuilderFieldSpec(
        name: 'linkUrl',
        labelKey: 'builderForm.linkUrl',
        value: link?.url ?? '',
        maxLength: 2048,
        required: true,
        kind: BuilderFieldKind.url,
      ),
      BuilderFieldSpec(
        name: 'linkKind',
        labelKey: 'builderForm.linkKind',
        value: (link?.kind ?? SocialLinkKind.other).name,
        choices: const {
          'other': 'builderForm.kindOther',
          'github': 'builderForm.kindGitHub',
          'website': 'builderForm.kindWebsite',
          'linkedin': 'builderForm.kindLinkedIn',
        },
      ),
    ],
    createItem: (id, values) => SocialLink(
      id: id,
      label: values['linkLabel']!,
      url: values['linkUrl']!,
      kind: SocialLinkKind.values.firstWhere(
        (kind) => kind.name == values['linkKind'],
      ),
    ),
  );
}
