#!/bin/bash
#  © eightman 2005-2025
#  Furin-lab All Rights Reserved.
#  AINanika SHIORIモジュールのビルド+ゴーストへの配置スクリプト
#
#  使い方:
#    scripts/build_plugin.sh              # 現在のアーキテクチャのみ
#    scripts/build_plugin.sh --universal  # Universal 2 (arm64+x86_64) ※配布用
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GHOST_MASTER="$PACKAGE_DIR/products/ghost/ghost/master"
BUNDLE_NAME="AINanika.bundle"

UNIVERSAL=false
if [[ "${1:-}" == "--universal" ]]; then
    UNIVERSAL=true
fi

cd "$PACKAGE_DIR"

echo "==> swift build (release)"
swift build -c release

ARM_LIB=".build/arm64-apple-macosx/release/libAINanikaShioriModule.dylib"

if $UNIVERSAL; then
    echo "==> Building x86_64 slice"
    swift build -c release --arch x86_64
    X64_LIB=".build/x86_64-apple-macosx/release/libAINanikaShioriModule.dylib"
    echo "==> Creating Universal 2 binary (lipo)"
    FAT_LIB=".build/release-universal/libAINanikaShioriModule.dylib"
    mkdir -p "$(dirname "$FAT_LIB")"
    lipo -create -output "$FAT_LIB" "$ARM_LIB" "$X64_LIB"
    SHIORI_LIB="$FAT_LIB"
else
    SHIORI_LIB="$ARM_LIB"
fi

echo "==> Assembling $BUNDLE_NAME"
BUNDLE_DIR="$GHOST_MASTER/$BUNDLE_NAME"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"

# Info.plist (CFBundleExecutable必須)
cat > "$BUNDLE_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AINanika</string>
    <key>CFBundleIdentifier</key>
    <string>jp.ourin.ainanika.shiori</string>
    <key>CFBundleName</key>
    <string>AINanikaSHIORI</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$SHIORI_LIB" "$BUNDLE_DIR/Contents/MacOS/AINanika"

echo "==> Verifying architectures"
lipo -info "$BUNDLE_DIR/Contents/MacOS/AINanika"

echo "==> Plugin assembled at: $BUNDLE_DIR"
echo ""
echo "Next steps:"
echo "  1. cp ai_config.json.example -> ai_config.json してAPIキー設定"
echo "  2. scripts/package_nar.sh でnar化、またはghostディレクトリをOurinへ直接インストール"
