import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'draft_strings.dart';
import 'builder_strings.dart';
import 'builder_form_strings.dart';
import 'builder_integration_strings.dart';
import 'github_strings.dart';
import 'github_sync_strings.dart';
import 'auth_strings.dart';
import 'sync_strings.dart';
import 'suggestion_strings.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;
  static const supportedLocales = [Locale('ru'), Locale('en')];
  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('ru'));

  Map<String, String> get _messages =>
      locale.languageCode == 'en' ? englishAppStrings : russianAppStrings;

  Set<String> get keys => Set.unmodifiable(_messages.keys);

  String projectCount(int count) =>
      tr('home.projects.${_countForm(count)}', {'count': count});

  String skillCount(int count) =>
      tr('home.skills.${_countForm(count)}', {'count': count});

  String _countForm(int count) {
    if (locale.languageCode == 'en') return count == 1 ? 'one' : 'many';
    if (count % 100 >= 11 && count % 100 <= 14) return 'many';
    return switch (count % 10) {
      1 => 'one',
      2 || 3 || 4 => 'few',
      _ => 'many',
    };
  }

  String tr(String key, [Map<String, Object> params = const {}]) {
    final message = _messages[key];
    if (message == null) {
      throw ArgumentError.value(key, 'key', 'Missing translation');
    }
    return message.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final name = match[1]!;
      final value = params[name];
      if (value == null) {
        throw ArgumentError.value(name, 'params', 'Missing parameter');
      }
      return value.toString();
    });
  }
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  SynchronousFuture<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

const russianAppStrings = <String, String>{
  "project.importGitHub": "Импорт из GitHub",
  "project.create": "Создать проект",
  "project.emptyTitle": "Пока нет проектов",
  "project.emptyMessage": "Создай проект или импортируй репозиторий из GitHub.",
  "project.noResultsTitle": "Ничего не найдено",
  "project.noResultsMessage": "Попробуй другое название или технологию.",
  "project.clearSearch": "Очистить поиск",
  "project.moreTechnologies": "Ещё {count} технологий. Открыть полный список",
  "project.noImage": "Обложка проекта не добавлена",
  "settings.profile": "Профиль",
  "settings.profileUnavailable": "Общий профиль и фото пока недоступны. Данные существующего черновика редактируются отдельно.",
  "settings.editLocalProfile": "Профиль локального черновика",
  "settings.localDraftRequired":
      "Сначала создайте локальный черновик в редакторе портфолио.",
  "settings.contacts": "Контакты и ссылки",
  "settings.contactsUnavailable": "Общие публичные контакты пока недоступны. Почта для входа не становится контактной почтой.",
  "settings.editLocalLinks": "Ссылки локального черновика",
  "settings.accountSecurity": "Аккаунт и безопасность",
  "settings.accountSecurityNote": "Вход, пароль и Google",
  "settings.privacy": "Приватность",
  "settings.privacyUnavailable": "Общие правила показа контактов и приёма обращений пока недоступны. Этот экран не меняет опубликованные версии.",
  "settings.application": "Приложение",
  "settings.applicationNote": "Тема, язык и настройки этого устройства",
  "settings.session": "Сеанс",
  "settings.deleteAccount": "Удалить аккаунт",
  "settings.deleteAccountUnavailable":
      "Удаление аккаунта и его данных пока недоступно.",
  "settings.localPreferencesNote": "Настройки сохраняются автоматически на этом устройстве. Они не меняют тему или содержимое портфолио.",
  "settings.notifications": "Уведомления",
  "settings.notificationsUnavailable": "Настройка уведомлений пока недоступна. Разрешения устройства не запрашиваются.",
  "settings.reducedMotion": "Уменьшить анимации",
  "settings.reducedMotionUnavailable":
      "Отдельная настройка уменьшения анимаций пока недоступна.",
  "settings.accountManagementUnavailable":
      "Управление аккаунтом пока недоступно",
  "settings.accountManagementReason": "Смена почты и пароля, привязка Google и удаление аккаунта пока не поддерживаются. Вход, выход и восстановление пароля на экране входа используют существующие действия.",
  "settings.changeLoginEmail": "Почта для входа",
  "settings.changeLoginEmailUnavailable": "Смена почты пока недоступна. Это отдельный адрес для входа, не публичный контакт.",
  "settings.changePassword": "Пароль",
  "settings.changePasswordUnavailable": "Смена пароля пока недоступна. Для восстановления используйте экран входа.",
  "settings.manageGoogle": "Привязка Google",
  "settings.manageGoogleUnavailable":
      "Управление способами входа пока недоступно.",
  "settings.backToSession": "Вернуться к сеансу",
  "settings.localDraftUnavailable":
      "Локальный черновик недоступен. Проверьте ошибку загрузки в редакторе.",
  "settings.shareContacts": "Поделиться публичными контактами",
  "settings.shareContactsUnavailable": "Публичная карточка контактов и отправка через меню устройства пока недоступны.",
  'router.notFound': 'Экран не найден',
  'router.notFoundHint': 'Вернитесь на главную страницу демо.',
  'startup.loading': 'Открываем StackCard',
  'startup.hint': 'Восстанавливаем настройки и локальные данные.',
  'startup.error': 'Локальные данные недоступны',
  'startup.errorHint': 'Не удалось открыть хранилище. Сохранённые данные не удалены. Повторите попытку.',
  'common.details': 'Подробности',
  'home.projects.one': '{count} проект',
  'home.projects.few': '{count} проекта',
  'home.projects.many': '{count} проектов',
  'home.skills.one': '{count} навык',
  'home.skills.few': '{count} навыка',
  'home.skills.many': '{count} навыков',
  "nav.home": "Главная",
  "nav.portfolio": "Портфолио",
  "nav.projects": "Проекты",
  "nav.settings": "Настройки",
  "common.back": "Назад",
  "nav.signIn": "Экран входа",
  "common.retry": "Повторить",
  "common.loading": "Загрузка",
  "async.loadingTitle": "Загрузка данных",
  "async.loadingMessage": "Готовим портфолио для просмотра.",
  "async.errorTitle": "Не удалось загрузить данные",
  "async.errorMessage": "Попробуйте ещё раз.",
  "auth.hero": "Ваш код.\nВаша история.",
  "auth.intro": "Соберите проекты, навыки и опыт в одном портфолио. Покажите то, что умеете создавать.",
  "auth.skills": "Навыки",
  "auth.story": "Ваша история",
  "auth.title": "Знакомство со StackCard",
  "auth.description":
      "Откройте демонстрационное портфолио и изучите интерфейс.",
  "auth.email": "Email для примера",
  "auth.open": "Открыть демо",
  "auth.invalidEmail": "Укажите корректный email",
  "auth.error":
      "Не удалось открыть демо. Нажмите «Открыть демо», чтобы повторить.",
  "auth.note": "Это демо на примерах данных. Email проверяется только на экране и не сохраняется. Авторизация будет подключена позднее.",
  "home.greeting": "Привет, {name}",
  "home.subtitle": "Твои проекты. Твоя история. Один StackCard.",
  "home.featured": "На первом плане",
  "home.featuredSubtitle": "Избранный проект демонстрационного портфолио",
  "home.demoNote": "Пример портфолио. Создайте своё в редакторе.",
  "home.hero": "Идеи становятся\nработающими продуктами.",
  "home.heroDescription":
      "Собери лучшее из того, что создаёшь, и покажи свой подход к работе.",
  "home.myPortfolio": "Моё портфолио",
  "home.readiness": "Готовность профиля",
  "home.readinessDescription":
      "Пример заполнения · {completed} из {total} блоков",
  "home.readinessSemantics":
      "Демонстрационное заполнение профиля: {percent} процентов",
  "common.draft": "Черновик",
  "home.unpublished": "Не опубликован",
  "home.publicLink": "Публичная ссылка",
  "home.afterPublish": "Появится после публикации",
  "home.noFeatured": "Нет избранных проектов",
  "home.noFeaturedMessage": "Здесь появятся проекты на первом плане.",
  "home.viewProjects": "Смотреть проекты",
  "home.workspace": "В твоём workspace",
  "home.featuredCount": "{count} featured · демонстрационные данные",
  "home.projectCount": "{count} проекта",
  "home.skillCount": "{count} навыков",
  "home.development": "Мобильная и веб-разработка",
  "home.githubTitle": "Публичные данные GitHub",
  "home.githubNote": "Выберите репозитории для своего портфолио.",
  "portfolio.subtitle": "Профиль, проекты и детали, которые расскажут о тебе.",
  "portfolio.blocks": "Блоки портфолио",
  "portfolio.demoNote": "Это макет на демонстрационных данных. Редактирование профиля, порядок блоков, резюме и публикация будут подключаться по плану разработки.",
  "portfolio.available": "Открыт к интересным задачам",
  "portfolio.demoProfile": "Демонстрационный профиль",
  "portfolio.private": "Только для тебя",
  "portfolio.previewNote": "Предпросмотр показывает пример будущей страницы. Этот профиль не опубликован.",
  "portfolio.preview": "Предпросмотр",
  "portfolio.publishNote":
      "Публикация станет доступна после подключения аккаунта и облака.",
  "portfolio.about": "Обо мне",
  "portfolio.skills": "Навыки",
  "portfolio.featured": "Избранные проекты",
  "portfolio.experience": "Опыт и обучение",
  "portfolio.demoEntries": "Все записи в этом блоке демонстрационные.",
  "portfolio.links": "05 / Ссылки и резюме",
  "portfolio.github": "Профиль GitHub",
  "portfolio.noLink": "В демо ссылка не подключена",
  "portfolio.resume": "Резюме",
  "portfolio.noResume": "Файл пока не добавлен",
  "portfolio.previewTitle": "Предпросмотр портфолио",
  "portfolio.previewStatus": "Демо · черновик не опубликован",
  "portfolio.closePreview": "Закрыть предпросмотр",
  "projects.title": "Сделано тобой",
  "projects.subtitle":
      "От pet project до большого продукта — каждой работе есть место.",
  "projects.search": "Поиск проектов",
  "projects.searchHint": "Название или технология",
  "projects.count": "Проекты: {count}",
  "projects.emptyTitle": "Ничего не найдено",
  "projects.emptyMessage":
      "Попробуй другое название, технологию или сбрось фильтры.",
  "projects.reset": "Сбросить фильтры",
  "projects.demoNote": "Все карточки — демонстрационные. Поиск и фильтры работают с примерами. GitHub Import показывает публичные репозитории отдельно; добавление в портфолио и редактирование появятся на следующих этапах.",
  "projects.view": "Посмотреть {title}",
  "projects.demoCase": "Демонстрационный кейс",
  "projects.sourceNote": "{source} · демонстрационные данные",
  "projects.close": "Закрыть проект",
  "filter.all": "Все",
  "filter.featured": "Featured",
  "filter.github": "GitHub",
  "filter.manual": "Вручную",
  "settings.appearance": "Внешний вид",
  "settings.appearanceNote":
      "Выберите комфортную тему. Настройки сохраняются на устройстве.",
  "settings.dark": "Тёмная",
  "settings.light": "Светлая",
  "settings.system": "Системная",
  "settings.language": "Язык интерфейса",
  "settings.languageNote":
      "Язык интерфейса не меняет содержимое профиля и проектов.",
  "settings.sourceDescriptions": "Описания GitHub",
  "settings.sourceDescriptionsNote":
      "Показывать описания в карточках публичных репозиториев.",
  "settings.saving": "Сохраняем настройки…",
  "settings.saveError": "Не удалось сохранить настройки",
  "settings.saveErrorNote": "Выбор действует сейчас. Повторите сохранение, чтобы восстановить его после запуска.",
  "settings.demoAccount": "Демонстрационный аккаунт",
  "settings.demoNote": "Демо-данные. Настройки сохраняются на устройстве.",
  "settings.signOut": "Вернуться ко входу",
  "settings.states": "Состояния интерфейса",
  "settings.statesNote": "Примеры загрузки, пустого списка и ошибки.",
  "settings.empty": "Пусто",
  "settings.error": "Ошибка",
  "settings.loadingTitle": "Загружаем проекты",
  "settings.emptyTitle": "Здесь появятся ваши проекты",
  "settings.errorTitle": "Не удалось загрузить проекты",
  "settings.loadingMessage": "Пример состояния ожидания.",
  "settings.emptyMessage":
      "Добавьте первый проект, когда будет доступен редактор.",
  "settings.errorMessage": "Пример ошибки. Повтор открывает пустое состояние.",
  ...russianGitHubStrings,
  ...russianGitHubSyncStrings,
  ...russianAuthStrings,
  ...russianSyncStrings,
  ...russianSuggestionStrings,
  ...russianDraftStrings,
  ...builderRussianStrings,
  ...builderFormRussianStrings,
  ...builderIntegrationRussianStrings,
};

const englishAppStrings = <String, String>{
  "project.importGitHub": "Import from GitHub",
  "project.create": "Create project",
  "project.emptyTitle": "No projects yet",
  "project.emptyMessage":
      "Create a project or import a repository from GitHub.",
  "project.noResultsTitle": "No projects found",
  "project.noResultsMessage": "Try another name or technology.",
  "project.clearSearch": "Clear search",
  "project.moreTechnologies": "{count} more technologies. Open the full list",
  "project.noImage": "No project cover added",
  "settings.profile": "Profile",
  "settings.profileUnavailable": "Shared profile and photo are unavailable. Existing draft details are edited separately.",
  "settings.editLocalProfile": "Local draft profile",
  "settings.localDraftRequired":
      "Create a local draft in the portfolio editor first.",
  "settings.contacts": "Contacts and links",
  "settings.contactsUnavailable": "Shared public contacts are unavailable. Your sign-in email is not used as a contact email.",
  "settings.editLocalLinks": "Local draft links",
  "settings.accountSecurity": "Account and security",
  "settings.accountSecurityNote": "Sign-in, password and Google",
  "settings.privacy": "Privacy",
  "settings.privacyUnavailable": "Shared contact visibility and visitor requests are unavailable. This screen does not change published versions.",
  "settings.application": "Application",
  "settings.applicationNote": "Theme, language and preferences for this device",
  "settings.session": "Session",
  "settings.deleteAccount": "Delete account",
  "settings.deleteAccountUnavailable":
      "Deleting an account and its data is unavailable.",
  "settings.localPreferencesNote": "Preferences are saved automatically on this device. They do not change portfolio theme or content.",
  "settings.notifications": "Notifications",
  "settings.notificationsUnavailable": "Notification preferences are unavailable. Device permissions are not requested.",
  "settings.reducedMotion": "Reduce motion",
  "settings.reducedMotionUnavailable":
      "A separate reduced motion preference is unavailable.",
  "settings.accountManagementUnavailable": "Account management is unavailable",
  "settings.accountManagementReason": "Changing email or password, linking Google and deleting an account are not supported yet. Sign-in, sign-out and password recovery on the sign-in screen use existing actions.",
  "settings.changeLoginEmail": "Sign-in email",
  "settings.changeLoginEmailUnavailable": "Changing email is unavailable. This is a sign-in address, not a public contact.",
  "settings.changePassword": "Password",
  "settings.changePasswordUnavailable": "Changing the password is unavailable. Use the sign-in screen for recovery.",
  "settings.manageGoogle": "Google linking",
  "settings.manageGoogleUnavailable":
      "Managing sign-in methods is unavailable.",
  "settings.backToSession": "Return to session",
  "settings.localDraftUnavailable":
      "The local draft is unavailable. Check the loading error in the editor.",
  "settings.shareContacts": "Share public contacts",
  "settings.shareContactsUnavailable":
      "A public contacts card and device sharing are unavailable.",
  'router.notFound': 'Page not found',
  'router.notFoundHint': 'Return to the demo home page.',
  'startup.loading': 'Opening StackCard',
  'startup.hint': 'Restoring settings and local data.',
  'startup.error': 'Local data unavailable',
  'startup.errorHint':
      'Could not open storage. Saved data has been preserved. Try again.',
  'common.details': 'Details',
  'home.projects.one': '{count} project',
  'home.projects.few': '{count} projects',
  'home.projects.many': '{count} projects',
  'home.skills.one': '{count} skill',
  'home.skills.few': '{count} skills',
  'home.skills.many': '{count} skills',
  "nav.home": "Home",
  "nav.portfolio": "Portfolio",
  "nav.projects": "Projects",
  "nav.settings": "Settings",
  "common.back": "Back",
  "nav.signIn": "Sign in",
  "common.retry": "Retry",
  "common.loading": "Loading",
  "async.loadingTitle": "Loading data",
  "async.loadingMessage": "Preparing your portfolio.",
  "async.errorTitle": "Unable to load data",
  "async.errorMessage": "Please try again.",
  "auth.hero": "Your code.\nYour story.",
  "auth.intro": "Bring your projects, skills and experience into one portfolio. Show what you can build.",
  "auth.skills": "Skills",
  "auth.story": "Your story",
  "auth.title": "Meet StackCard",
  "auth.description": "Open the demo portfolio and explore the interface.",
  "auth.email": "Demo email",
  "auth.open": "Open demo",
  "auth.invalidEmail": "Enter a valid email",
  "auth.error": "Unable to open the demo. Select “Open demo” to retry.",
  "auth.note": "This demo uses example data. Email is checked on this screen and is not saved. Account sign-in will be added later.",
  "home.greeting": "Hello, {name}",
  "home.subtitle": "Your projects. Your story. One StackCard.",
  "home.featured": "In the spotlight",
  "home.featuredSubtitle": "A featured project from the demo portfolio",
  "home.demoNote": "Example portfolio. Create yours in the editor.",
  "home.hero": "Ideas become\nworking products.",
  "home.heroDescription":
      "Bring together your best work and show how you build.",
  "home.myPortfolio": "My portfolio",
  "home.readiness": "Profile readiness",
  "home.readinessDescription":
      "Example progress · {completed} of {total} blocks",
  "home.readinessSemantics": "Demo profile completion: {percent} percent",
  "common.draft": "Draft",
  "home.unpublished": "Not published",
  "home.publicLink": "Public link",
  "home.afterPublish": "Available after publishing",
  "home.noFeatured": "No featured projects",
  "home.noFeaturedMessage": "Featured projects will appear here.",
  "home.viewProjects": "View projects",
  "home.workspace": "In your workspace",
  "home.featuredCount": "{count} featured · demo data",
  "home.projectCount": "{count} projects",
  "home.skillCount": "{count} skills",
  "home.development": "Mobile and web development",
  "home.githubTitle": "Public GitHub data",
  "home.githubNote": "Choose repositories for your portfolio.",
  "portfolio.subtitle":
      "Your profile, projects and the details that tell your story.",
  "portfolio.blocks": "Portfolio blocks",
  "portfolio.demoNote": "This layout uses demo data. Profile editing, block order, resume and publishing will be added according to the roadmap.",
  "portfolio.available": "Open to interesting opportunities",
  "portfolio.demoProfile": "Demo profile",
  "portfolio.private": "Only for you",
  "portfolio.previewNote": "This preview shows an example of your future page. This profile is not published.",
  "portfolio.preview": "Preview",
  "portfolio.publishNote":
      "Publishing will be available after account and cloud integration.",
  "portfolio.about": "About me",
  "portfolio.skills": "Skills",
  "portfolio.featured": "Featured projects",
  "portfolio.experience": "Experience and education",
  "portfolio.demoEntries": "All entries in this section are examples.",
  "portfolio.links": "05 / Links and resume",
  "portfolio.github": "GitHub profile",
  "portfolio.noLink": "No link is connected in the demo",
  "portfolio.resume": "Resume",
  "portfolio.noResume": "No file has been added yet",
  "portfolio.previewTitle": "Portfolio preview",
  "portfolio.previewStatus": "Demo · draft is not published",
  "portfolio.closePreview": "Close preview",
  "projects.title": "Made by you",
  "projects.subtitle": "From a side project to a major product — every piece of work belongs here.",
  "projects.search": "Search projects",
  "projects.searchHint": "Name or technology",
  "projects.count": "Projects: {count}",
  "projects.emptyTitle": "No projects found",
  "projects.emptyMessage":
      "Try another name or technology, or reset the filters.",
  "projects.reset": "Reset filters",
  "projects.demoNote": "All cards use demo data. Search and filters work with these examples. GitHub Import shows public repositories separately; portfolio import and editing will be added later.",
  "projects.view": "View {title}",
  "projects.demoCase": "Demo case study",
  "projects.sourceNote": "{source} · demo data",
  "projects.close": "Close project",
  "filter.all": "All",
  "filter.featured": "Featured",
  "filter.github": "GitHub",
  "filter.manual": "Manual",
  "settings.appearance": "Appearance",
  "settings.appearanceNote":
      "Choose a comfortable theme. Settings are saved on this device.",
  "settings.dark": "Dark",
  "settings.light": "Light",
  "settings.system": "System",
  "settings.language": "Interface language",
  "settings.languageNote":
      "The interface language does not change profile or project content.",
  "settings.sourceDescriptions": "GitHub descriptions",
  "settings.sourceDescriptionsNote":
      "Show descriptions on public repository cards.",
  "settings.saving": "Saving settings…",
  "settings.saveError": "Unable to save settings",
  "settings.saveErrorNote": "Your choices apply now. Retry saving to restore them after the next launch.",
  "settings.demoAccount": "Demo account",
  "settings.demoNote": "Demo data. Settings are saved on this device.",
  "settings.signOut": "Return to sign in",
  "settings.states": "Interface states",
  "settings.statesNote": "Examples of loading, empty and error states.",
  "settings.empty": "Empty",
  "settings.error": "Error",
  "settings.loadingTitle": "Loading projects",
  "settings.emptyTitle": "Your projects will appear here",
  "settings.errorTitle": "Unable to load projects",
  "settings.loadingMessage": "An example loading state.",
  "settings.emptyMessage":
      "Add your first project when the editor is available.",
  "settings.errorMessage": "An example error. Retry opens the empty state.",
  ...englishGitHubStrings,
  ...englishGitHubSyncStrings,
  ...englishAuthStrings,
  ...englishSyncStrings,
  ...englishSuggestionStrings,
  ...englishDraftStrings,
  ...builderEnglishStrings,
  ...builderFormEnglishStrings,
  ...builderIntegrationEnglishStrings,
};
