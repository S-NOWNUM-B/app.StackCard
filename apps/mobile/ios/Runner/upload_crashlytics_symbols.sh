#!/bin/sh
set -eu

# Flutter SPM может хранить SourcePackages в BUILD_DIR; обычный Xcode — в DerivedData.
stackcard_crashlytics_upload="${BUILD_DIR}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
if [ ! -x "$stackcard_crashlytics_upload" ]; then
  stackcard_crashlytics_upload="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
fi
if [ ! -x "$stackcard_crashlytics_upload" ]; then
  echo "error: Crashlytics SPM script is missing; resolve Firebase packages in Xcode" >&2
  exit 1
fi
# Весь bundle включает Runner.debug.dylib; foreground сохраняет ошибку upload в build result.
"$stackcard_crashlytics_upload" \
  -gsp "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist" \
  -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
