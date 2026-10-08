const russianDocumentPublicationStrings = <String, String>{
  'documentPublication.title': 'Публикация',
  'documentPublication.publish': 'Опубликовать',
  'documentPublication.republish': 'Обновить публикацию',
  'documentPublication.unpublish': 'Снять с публикации',
  'documentPublication.delete': 'Удалить документ',
  'documentPublication.draft': 'Черновик',
  'documentPublication.draftHint':
      'Документ доступен только вам до явной публикации.',
  'documentPublication.published': 'Опубликовано',
  'documentPublication.publishedHint': 'Публичная версия подтверждена сервером. Изменения черновика не меняют её автоматически.',
  'documentPublication.unpublished': 'Публикация снята',
  'documentPublication.unpublishedHint':
      'Публичный доступ закрыт. При повторной публикации адрес сохранится.',
  'documentPublication.deleted': 'Документ удалён',
  'documentPublication.deletedHint':
      'Публичный доступ закрыт; этот ID больше нельзя опубликовать.',
  'documentPublication.localSaved': 'Сохранено на устройстве',
  'documentPublication.localSavedHint':
      'Локальная запись завершена; публикация не менялась.',
  'documentPublication.synced': 'Синхронизировано',
  'documentPublication.syncedHint':
      'Сервер подтвердил именно текущую сохранённую версию.',
  'documentPublication.pendingSync': 'Ожидаем синхронизацию',
  'documentPublication.pendingSyncHint': 'Для публикации сервер должен подтвердить текущую версию. Повторите синхронизацию, если соединение восстановлено.',
  'documentPublication.retrySync': 'Повторить синхронизацию',
  'documentPublication.saveFirst': 'Сначала сохраните изменения',
  'documentPublication.saveFirstHint': 'Вернитесь в редактор и сохраните документ. Публикация использует только сохранённые данные.',
  'documentPublication.summary': 'Будет доступно по ссылке',
  'documentPublication.summaryHint': 'Имя, описание, выбранные секции и проекты. Только разрешённые в общей базе и видимые в документе контакты.',
  'documentPublication.consent': 'Публикация сделает выбранные сведения доступными всем, у кого есть ссылка.',
  'documentPublication.guest': 'Для публикации войдите в аккаунт. Гостевые документы сохраняются на устройстве.',
  'documentPublication.unconfigured': 'Сервис публикации не настроен для этого окружения. Документ остаётся приватным.',
  'documentPublication.loading': 'Проверяем публикации…',
  'documentPublication.unknown': 'Результат операции неизвестен',
  'documentPublication.unknownHint': 'Сервер мог завершить действие. Проверьте статус или повторите тот же запрос; подтверждённая публичная версия пока не установлена.',
  'documentPublication.checkStatus': 'Проверить статус',
  'documentPublication.retryOperation': 'Повторить запрос',
  'documentPublication.refresh': 'Обновить статус',
  'documentPublication.copy': 'Копировать',
  'documentPublication.copied': 'Ссылка скопирована',
  'documentPublication.open': 'Открыть в браузере',
  'documentPublication.share': 'Поделиться',
  'documentPublication.linkHint':
      'Название и ник можно менять. Ссылка на этот документ сохранится.',
  'documentPublication.linkUnavailable':
      'У документа нет подтверждённой публичной ссылки.',
  'documentPublication.linkActionsUnavailable':
      'Открытие ссылок и системный Share недоступны в этом окружении.',
  'documentPublication.actionFailed':
      'Не удалось выполнить действие. Ссылка сохранена, попробуйте снова.',
  'documentPublication.unpublishTitle': 'Снять документ с публикации?',
  'documentPublication.unpublishHint':
      'Публичный доступ будет закрыт. Черновик и постоянный адрес сохранятся.',
  'documentPublication.deleteTitle': 'Удалить документ навсегда?',
  'documentPublication.deleteHint': 'Документ и публичный доступ будут удалены. Общая библиотека проектов и другие документы сохранятся.',
  'documentPublication.error.unavailable':
      'Сервис недоступен. Проверьте соединение и повторите проверку статуса.',
  'documentPublication.error.unauthenticated':
      'Сессия истекла. Войдите в аккаунт повторно.',
  'documentPublication.error.invalidData': 'Сервер отклонил данные документа. Проверьте обязательные поля в редакторе.',
  'documentPublication.error.conflict': 'Сохранённая версия или статус изменились. Обновите данные и проверьте публикацию заново.',
  'documentPublication.error.deleted': 'Этот документ уже удалён на сервере.',
  'documentPublication.error.accountDeleting':
      'Аккаунт удаляется; новые публикации закрыты.',
  'documentPublication.error.configurationRequired':
      'В этом окружении сервис публикации или публичный адрес не настроен.',
  'documentPublication.error.reauthenticationRequired':
      'Перед удалением подтвердите вход в аккаунт повторно.',
  'documentPublication.error.unknown':
      'Ответ сервера не подтверждён. Проверьте статус операции.',
  'documentPublication.error.storage': 'Не удалось прочитать или сохранить журнал операции. Повторите проверку; новый запрос пока не отправлен.',
  'projectPresentation.title': 'Представление проекта',
  'projectPresentation.hint': 'Название, описание и вклад меняются только в этом документе. Библиотека и другие документы сохранят прежние значения.',
  'projectPresentation.library': 'Проект из общей библиотеки',
  'projectPresentation.custom': 'Свой текст в этом документе',
  'projectPresentation.name': 'Название',
  'projectPresentation.description': 'Описание',
  'projectPresentation.contribution': 'Мой вклад',
  'projectPresentation.inherit': 'Использовать значение библиотеки',
  'projectPresentation.apply': 'Применить',
  'projectPresentation.invalid':
      'Проверьте длину полей; название не должно быть пустым.',
  'projectPresentation.removeTitle': 'Убрать проект из документа?',
  'projectPresentation.removeHint':
      'Сам проект останется в общей библиотеке и других документах.',
  'documentContacts.visible': 'Показывать в этом документе',
  'documentContacts.allowed': 'Публикация разрешена в общей базе',
  'documentContacts.private':
      'Публикация закрыта в общей базе; контакт останется приватным.',
  'documentContacts.localOnly': 'Контакт сохранён только в документе. Добавьте его в общую базу и разрешите публикацию, чтобы он стал публичным.',
  'documentContacts.location': 'Разрешить публикацию города и страны',
  'documentContacts.locationHint': 'Также требуется разрешение в общей базе. Координаты и адрес не публикуются.',
  'documentContacts.permissionGranted': 'Разрешено',
  'documentContacts.permissionDenied': 'Закрыто',
};

const englishDocumentPublicationStrings = <String, String>{
  'documentPublication.title': 'Publication',
  'documentPublication.publish': 'Publish',
  'documentPublication.republish': 'Update publication',
  'documentPublication.unpublish': 'Unpublish',
  'documentPublication.delete': 'Delete document',
  'documentPublication.draft': 'Draft',
  'documentPublication.draftHint':
      'Only you can access this document until you publish it.',
  'documentPublication.published': 'Published',
  'documentPublication.publishedHint': 'The server confirmed the public version. Draft edits do not update it automatically.',
  'documentPublication.unpublished': 'Unpublished',
  'documentPublication.unpublishedHint':
      'Public access is closed. Publishing again will retain the same address.',
  'documentPublication.deleted': 'Document deleted',
  'documentPublication.deletedHint':
      'Public access is closed; this ID can no longer be published.',
  'documentPublication.localSaved': 'Saved on device',
  'documentPublication.localSavedHint':
      'The local write completed; the publication has not changed.',
  'documentPublication.synced': 'Synced',
  'documentPublication.syncedHint':
      'The server acknowledged the exact current saved version.',
  'documentPublication.pendingSync': 'Waiting for sync',
  'documentPublication.pendingSyncHint': 'Publishing requires server acknowledgement of the current version. Retry sync when connected.',
  'documentPublication.retrySync': 'Retry sync',
  'documentPublication.saveFirst': 'Save your changes first',
  'documentPublication.saveFirstHint': 'Return to the editor and save the document. Publishing only uses saved data.',
  'documentPublication.summary': 'Accessible through the link',
  'documentPublication.summaryHint': 'Name, description, selected sections and projects. Contacts must be allowed in the shared profile and visible in this document.',
  'documentPublication.consent': 'Publishing makes the selected information accessible to anyone with the link.',
  'documentPublication.guest':
      'Sign in to publish. Guest documents stay on your device.',
  'documentPublication.unconfigured': 'Publication is not configured in this environment. The document remains private.',
  'documentPublication.loading': 'Checking publications…',
  'documentPublication.unknown': 'Operation result unknown',
  'documentPublication.unknownHint': 'The server may have completed this action. Check its status or retry the same request; the public state is not confirmed yet.',
  'documentPublication.checkStatus': 'Check status',
  'documentPublication.retryOperation': 'Retry request',
  'documentPublication.refresh': 'Refresh status',
  'documentPublication.copy': 'Copy',
  'documentPublication.copied': 'Link copied',
  'documentPublication.open': 'Open in browser',
  'documentPublication.share': 'Share',
  'documentPublication.linkHint': 'You can change the title or username. This document link stays the same.',
  'documentPublication.linkUnavailable':
      'This document has no confirmed public link.',
  'documentPublication.linkActionsUnavailable':
      'Opening links and system sharing are unavailable in this environment.',
  'documentPublication.actionFailed':
      'The action failed. Your link is retained; try again.',
  'documentPublication.unpublishTitle': 'Unpublish this document?',
  'documentPublication.unpublishHint':
      'Public access will close. The draft and permanent address will remain.',
  'documentPublication.deleteTitle': 'Permanently delete this document?',
  'documentPublication.deleteHint': 'The document and public access will be removed. The project library and other documents will remain.',
  'documentPublication.error.unavailable':
      'Service unavailable. Check your connection and retry the status check.',
  'documentPublication.error.unauthenticated':
      'Your session expired. Sign in again.',
  'documentPublication.error.invalidData': 'The server rejected the document. Check the required fields in the editor.',
  'documentPublication.error.conflict': 'The saved version or status changed. Refresh your data and review publication again.',
  'documentPublication.error.deleted':
      'This document was already deleted on the server.',
  'documentPublication.error.accountDeleting':
      'Your account is being deleted; new publications are blocked.',
  'documentPublication.error.configurationRequired': 'Publication or the public address is not configured in this environment.',
  'documentPublication.error.reauthenticationRequired':
      'Confirm your sign-in again before deletion.',
  'documentPublication.error.unknown':
      'The server response is unconfirmed. Check the operation status.',
  'documentPublication.error.storage': 'The operation journal could not be read or saved. Check again; no new request has been sent.',
  'projectPresentation.title': 'Project presentation',
  'projectPresentation.hint': 'Title, description and contribution only change in this document. The library and other documents keep their values.',
  'projectPresentation.library': 'Project from the shared library',
  'projectPresentation.custom': 'Custom text in this document',
  'projectPresentation.name': 'Title',
  'projectPresentation.description': 'Description',
  'projectPresentation.contribution': 'My contribution',
  'projectPresentation.inherit': 'Use the library value',
  'projectPresentation.apply': 'Apply',
  'projectPresentation.invalid':
      'Check field lengths; the title must not be empty.',
  'projectPresentation.removeTitle': 'Remove project from document?',
  'projectPresentation.removeHint':
      'The project remains in the library and other documents.',
  'documentContacts.visible': 'Show in this document',
  'documentContacts.allowed': 'Publication allowed in shared profile',
  'documentContacts.private': 'Publication is disabled in the shared profile; this contact stays private.',
  'documentContacts.localOnly': 'This contact exists only in the document. Add it to the shared profile and allow publication to make it public.',
  'documentContacts.location': 'Allow city and country publication',
  'documentContacts.locationHint': 'This also requires permission in the shared profile. Coordinates and addresses are not published.',
  'documentContacts.permissionGranted': 'Allowed',
  'documentContacts.permissionDenied': 'Disabled',
};
