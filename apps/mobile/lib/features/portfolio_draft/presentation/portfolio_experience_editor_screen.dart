import 'package:flutter/material.dart';

import '../domain/portfolio_content.dart';
import 'builder_collection_editor.dart';
import 'builder_editor_widgets.dart';

class PortfolioExperienceEditorScreen extends StatelessWidget {
  const PortfolioExperienceEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => BuilderCollectionEditor<Experience>(
    titleKey: 'builderForm.experienceTitle',
    readItems: (content) => content.experience,
    writeItems: (content, items) => content.copyWith(experience: items),
    itemId: (item) => item.id,
    itemTitle: (item) => item.role,
    itemSummary: (item) => [
      item.organization,
      item.period,
      item.description,
    ].where((value) => value.isNotEmpty).join('\n'),
    fields: (item) => [
      BuilderFieldSpec(
        name: 'role',
        labelKey: 'builderForm.role',
        value: item?.role ?? '',
        required: true,
        maxLength: 120,
      ),
      BuilderFieldSpec(
        name: 'organization',
        labelKey: 'builderForm.organization',
        value: item?.organization ?? '',
        required: true,
        maxLength: 160,
      ),
      BuilderFieldSpec(
        name: 'period',
        labelKey: 'builderForm.period',
        value: item?.period ?? '',
        maxLength: 120,
      ),
      BuilderFieldSpec(
        name: 'description',
        labelKey: 'builderForm.description',
        value: item?.description ?? '',
        maxLength: 4000,
        kind: BuilderFieldKind.multiline,
      ),
    ],
    createItem: (id, values) => Experience(
      id: id,
      role: values['role']!,
      organization: values['organization']!,
      period: values['period']!,
      description: values['description']!,
    ),
  );
}
