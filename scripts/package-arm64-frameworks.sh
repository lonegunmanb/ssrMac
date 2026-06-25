#!/bin/bash

set -euo pipefail

OUTPUT_DIR="${1:-}"

log() {
  printf '[package-frameworks] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

usage() {
  printf 'Usage: %s <built-products-dir>\n' "$(basename "$0")"
}

brew_prefix() {
  local formula="$1"
  brew --prefix "$formula" 2>/dev/null || fail "Homebrew formula not found: $formula"
}

write_info_plist() {
  local framework_name="$1"
  local plist_path="$2"

  /usr/libexec/PlistBuddy -c 'Clear dict' "$plist_path" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string en' "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $framework_name" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string org.ssrmac.$framework_name" "$plist_path"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$plist_path"
  /usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string FMWK' "$plist_path"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 1.0' "$plist_path"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' "$plist_path"
}

prepare_framework_layout() {
  local framework_name="$1"
  local framework_dir="$OUTPUT_DIR/$framework_name.framework"
  local version_dir="$framework_dir/Versions/A"

  rm -rf "$framework_dir"
  mkdir -p "$version_dir/Headers" "$version_dir/Resources"
  ln -sfn A "$framework_dir/Versions/Current"
  ln -sfn Versions/Current/Headers "$framework_dir/Headers"
  ln -sfn Versions/Current/Resources "$framework_dir/Resources"
  ln -sfn "Versions/Current/$framework_name" "$framework_dir/$framework_name"
  write_info_plist "$framework_name" "$version_dir/Resources/Info.plist"
}

copy_headers() {
  local headers_dir="$1"
  local destination="$2"

  [[ -d "$headers_dir" ]] || fail "Header directory not found: $headers_dir"
  cp -R "$headers_dir"/. "$destination/"
}

verify_arm64() {
  local binary_path="$1"
  local archs

  archs="$(lipo -archs "$binary_path")"
  log "$(basename "$binary_path") architectures: $archs"
  [[ " $archs " == *' arm64 '* ]] || fail "Missing arm64 slice in $binary_path"
}

create_static_framework() {
  local framework_name="$1"
  local headers_dir="$2"
  local output_binary="$OUTPUT_DIR/$framework_name.framework/Versions/A/$framework_name"
  shift 2

  prepare_framework_layout "$framework_name"
  copy_headers "$headers_dir" "$OUTPUT_DIR/$framework_name.framework/Versions/A/Headers"

  if [[ "$#" -eq 1 ]]; then
    cp "$1" "$output_binary"
  else
    libtool -static -o "$output_binary" "$@"
  fi

  verify_arm64 "$output_binary"
}

if [[ -z "$OUTPUT_DIR" ]]; then
  usage
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
log "Output directory: $OUTPUT_DIR"

LIBUV_PREFIX="$(brew_prefix libuv)"
LIBSODIUM_PREFIX="$(brew_prefix libsodium)"
MBEDTLS_PREFIX="$(brew_prefix mbedtls)"
OPENSSL_PREFIX="$(brew_prefix openssl@3)"

create_static_framework "libuv" "$LIBUV_PREFIX/include" "$LIBUV_PREFIX/lib/libuv.a"
create_static_framework "libsodium" "$LIBSODIUM_PREFIX/include" "$LIBSODIUM_PREFIX/lib/libsodium.a"
create_static_framework "mbedtls" "$MBEDTLS_PREFIX/include" \
  "$MBEDTLS_PREFIX/lib/libmbedtls.a" \
  "$MBEDTLS_PREFIX/lib/libmbedx509.a" \
  "$MBEDTLS_PREFIX/lib/libmbedcrypto.a"
create_static_framework "libcrypto" "$OPENSSL_PREFIX/include" "$OPENSSL_PREFIX/lib/libcrypto.a"

log "Packaged arm64 frameworks successfully"