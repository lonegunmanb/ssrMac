#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/ssrMac.xcodeproj"
SCHEME="${SCHEME:-ssrMac}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCH="${ARCH:-arm64}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
PACKAGE_FRAMEWORKS_SCRIPT="$ROOT_DIR/scripts/package-arm64-frameworks.sh"

log() {
	printf '[build] %s\n' "$*"
}

log "Starting ssrMac build"
log "Project: $PROJECT_PATH"
log "Scheme: $SCHEME"
log "Configuration: $CONFIGURATION"
log "Architecture: $ARCH"
log "Derived data: $DERIVED_DATA_PATH"

if [[ -x "$PACKAGE_FRAMEWORKS_SCRIPT" ]]; then
	log "Packaging arm64 dependency frameworks"
	"$PACKAGE_FRAMEWORKS_SCRIPT" "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
else
	log "Dependency framework packaging script not found; skipping T8 packaging hook"
fi

log "Running xcodebuild"
xcodebuild \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-arch "$ARCH" \
	-derivedDataPath "$DERIVED_DATA_PATH" \
	"$@"

log "Build completed"
