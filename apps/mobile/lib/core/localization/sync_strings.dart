const russianSyncStrings = <String, String>{
  'sync.localOnly': 'Только на этом устройстве',
  'sync.loading': 'Проверяем облачный черновик…',
  'sync.pending': 'Сохранено на устройстве · ожидает синхронизации',
  'sync.synced': 'Синхронизировано с аккаунтом',
  'sync.error': 'Не удалось синхронизировать',
  'sync.retry': 'Повторить синхронизацию',
  'sync.error.network': 'Нет соединения. Сохранённые правки отправятся после восстановления сети.',
  'sync.error.permissionDenied':
      'Нет доступа к облачному черновику. Проверь аккаунт и повтори попытку.',
  'sync.error.unauthenticated':
      'Для синхронизации нужно снова войти в аккаунт.',
  'sync.error.invalidData': 'Облачный черновик использует неподдерживаемые данные. Сохранённые данные на устройстве не удалены.',
  'sync.error.unavailable':
      'Облако сейчас недоступно. Сохранённые данные на устройстве не удалены.',
  'sync.error.oversized': 'Черновик слишком большой для облака. Сократи содержимое и сохрани снова.',
  'sync.remoteUpdate': 'Черновик обновлён на другом устройстве. Твои правки остались в редакторе. Сохранение твоей версии заменит облачный черновик целиком; открытие сохранённой версии отбросит текущие правки.',
  'sync.saveMine': 'Сохранить мою версию',
  'sync.builderSubtitle': 'Собери своё портфолио и проверь предпросмотр. Сохранённый черновик синхронизируется с аккаунтом; публикация выполняется отдельно.',
  'sync.notesScope': 'Запиши идеи, описание себя или планы проектов. Сохранённые заметки доступны без сети и синхронизируются только с твоим аккаунтом.',
};

const englishSyncStrings = <String, String>{
  'sync.localOnly': 'Only on this device',
  'sync.loading': 'Checking the cloud draft…',
  'sync.pending': 'Saved on device · pending synchronization',
  'sync.synced': 'Synchronized with your account',
  'sync.error': 'Unable to synchronize',
  'sync.retry': 'Retry synchronization',
  'sync.error.network':
      'No connection. Saved edits will be sent when the network returns.',
  'sync.error.permissionDenied':
      'Cloud draft access is denied. Check your account and try again.',
  'sync.error.unauthenticated': 'Sign in again to synchronize your draft.',
  'sync.error.invalidData': 'The cloud draft contains unsupported data. Saved data on this device has been preserved.',
  'sync.error.unavailable': 'Cloud storage is unavailable. Saved data on this device has been preserved.',
  'sync.error.oversized': 'The draft is too large for cloud storage. Shorten its content and save again.',
  'sync.remoteUpdate': 'The draft was updated on another device. Your edits remain in the editor. Saving your version will replace the entire cloud draft; opening the saved revision will discard your current edits.',
  'sync.saveMine': 'Save my version',
  'sync.builderSubtitle': 'Build your portfolio and check the preview. Saved drafts synchronize with your account; publishing is a separate action.',
  'sync.notesScope': 'Write ideas, your introduction or project plans. Saved notes are available offline and synchronize only with your account.',
};
