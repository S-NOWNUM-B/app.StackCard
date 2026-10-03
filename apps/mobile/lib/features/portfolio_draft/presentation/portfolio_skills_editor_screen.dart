import 'package:flutter/material.dart';

import '../domain/portfolio_content.dart';
import 'builder_collection_editor.dart';
import 'builder_editor_widgets.dart';

class PortfolioSkillsEditorScreen extends StatelessWidget {
  const PortfolioSkillsEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => BuilderCollectionEditor<Skill>(
    titleKey: 'builderForm.skillsTitle',
    readItems: (content) => content.skills,
    writeItems: (content, items) => content.copyWith(skills: items),
    itemId: (skill) => skill.id,
    itemTitle: (skill) => skill.name,
    itemSummary: (_) => '',
    fields: (skill) => [
      BuilderFieldSpec(
        name: 'skillName',
        labelKey: 'builderForm.skillName',
        value: skill?.name ?? '',
        required: true,
        maxLength: 60,
      ),
    ],
    createItem: (id, values) => Skill(id: id, name: values['skillName']!),
  );
}
