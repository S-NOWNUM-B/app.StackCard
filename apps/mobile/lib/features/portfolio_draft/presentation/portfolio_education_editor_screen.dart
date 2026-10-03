import 'package:flutter/material.dart';

import '../domain/portfolio_content.dart';
import 'builder_collection_editor.dart';
import 'builder_editor_widgets.dart';

class PortfolioEducationEditorScreen extends StatelessWidget {
  const PortfolioEducationEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => BuilderCollectionEditor<Education>(
    titleKey: 'builderForm.educationTitle',
    readItems: (content) => content.education,
    writeItems: (content, items) => content.copyWith(education: items),
    itemId: (item) => item.id,
    itemTitle: (item) => item.institution,
    itemSummary: (item) => [
      item.qualification,
      item.period,
      item.description,
    ].where((value) => value.isNotEmpty).join('\n'),
    fields: (item) => [
      BuilderFieldSpec(
        name: 'institution',
        labelKey: 'builderForm.institution',
        value: item?.institution ?? '',
        required: true,
        maxLength: 160,
      ),
      BuilderFieldSpec(
        name: 'qualification',
        labelKey: 'builderForm.qualification',
        value: item?.qualification ?? '',
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
    createItem: (id, values) => Education(
      id: id,
      institution: values['institution']!,
      qualification: values['qualification']!,
      period: values['period']!,
      description: values['description']!,
    ),
  );
}
