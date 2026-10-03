import 'package:app_stackcard/features/projects/projects.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Default filters show the immutable demo list', () async {
    final container = ProviderContainer.test();
    await container.read(projectsProvider.future);
    final projects = container.read(visibleProjectsProvider).requireValue;

    expect(container.read(projectFiltersProvider), const ProjectFilters());
    expect(projects.map((project) => project.title), [
      'Atlas UI Kit',
      'Pocket Tasks',
      'Readme Studio',
      'Weather Notes',
    ]);
    expect(() => projects.clear(), throwsUnsupportedError);
  });

  test('Technology search ignores surrounding spaces and case', () async {
    final container = ProviderContainer.test();
    await container.read(projectsProvider.future);
    container.read(projectFiltersProvider.notifier).setQuery('  rEaCt  ');

    expect(container.read(projectFiltersProvider).query, '  rEaCt  ');
    expect(
      container
          .read(visibleProjectsProvider)
          .requireValue
          .map((project) => project.title),
      ['Readme Studio'],
    );
  });

  test('Search includes a project title and description', () async {
    final container = ProviderContainer.test();
    await container.read(projectsProvider.future);
    final notifier = container.read(projectFiltersProvider.notifier);

    notifier.setQuery('atlas');
    expect(
      container
          .read(visibleProjectsProvider)
          .requireValue
          .map((project) => project.title),
      ['Atlas UI Kit'],
    );
    notifier.setQuery('планировщик');
    expect(
      container
          .read(visibleProjectsProvider)
          .requireValue
          .map((project) => project.title),
      ['Pocket Tasks'],
    );
  });

  test(
    'Source and featured selections combine with the current query',
    () async {
      final container = ProviderContainer.test();
      await container.read(projectsProvider.future);
      final notifier = container.read(projectFiltersProvider.notifier);

      notifier.setQuery('Flutter');
      notifier.setFilter(ProjectFilter.github);
      expect(
        container
            .read(visibleProjectsProvider)
            .requireValue
            .map((project) => project.title),
        ['Atlas UI Kit'],
      );
      notifier.setFilter(ProjectFilter.manual);
      expect(
        container
            .read(visibleProjectsProvider)
            .requireValue
            .map((project) => project.title),
        ['Pocket Tasks', 'Weather Notes'],
      );
      notifier.setFilter(ProjectFilter.featured);
      expect(
        container
            .read(visibleProjectsProvider)
            .requireValue
            .map((project) => project.title),
        ['Atlas UI Kit', 'Pocket Tasks'],
      );
      notifier.setQuery('React');
      expect(container.read(visibleProjectsProvider).requireValue, isEmpty);
      expect(
        container.read(projectFiltersProvider).filter,
        ProjectFilter.featured,
      );
    },
  );

  test('Reset restores both the query and selected filter', () async {
    final container = ProviderContainer.test();
    await container.read(projectsProvider.future);
    final notifier = container.read(projectFiltersProvider.notifier);
    notifier.setQuery('does-not-exist');
    notifier.setFilter(ProjectFilter.manual);
    expect(container.read(visibleProjectsProvider).requireValue, isEmpty);

    notifier.reset();

    expect(container.read(projectFiltersProvider), const ProjectFilters());
    expect(
      container.read(visibleProjectsProvider).requireValue,
      container.read(projectsProvider).requireValue,
    );
  });

  test(
    'State survives an interval without listeners within the same session',
    () async {
      final container = ProviderContainer.test();
      await container.read(projectsProvider.future);
      container.read(projectFiltersProvider.notifier).setQuery('Atlas');

      final subscription = container.listen(projectFiltersProvider, (_, _) {});
      subscription.close();
      await container.pump();

      expect(container.read(projectFiltersProvider).query, 'Atlas');
      expect(
        container
            .read(visibleProjectsProvider)
            .requireValue
            .map((project) => project.title),
        ['Atlas UI Kit'],
      );
    },
  );

  test(
    'Containers are independent and a fresh session starts with defaults',
    () async {
      final first = ProviderContainer();
      final second = ProviderContainer.test();
      first.read(projectFiltersProvider.notifier).setQuery('Atlas');
      first
          .read(projectFiltersProvider.notifier)
          .setFilter(ProjectFilter.featured);

      expect(second.read(projectFiltersProvider), const ProjectFilters());
      first.dispose();

      final fresh = ProviderContainer.test();
      await fresh.read(projectsProvider.future);
      expect(fresh.read(projectFiltersProvider), const ProjectFilters());
      expect(fresh.read(visibleProjectsProvider).requireValue.length, 4);
    },
  );
}
