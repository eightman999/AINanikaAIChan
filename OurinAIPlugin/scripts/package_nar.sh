#!/bin/bash
#  © eightman 2005-2025
#  Furin-lab All Rights Reserved.
#  AI何かちゃんゴーストのnarパッケージ作成スクリプト
#
#  使い方:
#    scripts/package_nar.sh                    # products/ghostからAI何かちゃん.narを作成
#    scripts/package_nar.sh --with-shell       # 既存shell/(PNG100枚)を同梱
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/.." && pwd)"
GHOST_SRC="$PACKAGE_DIR/products/ghost"
STAGING="$(mktemp -d /tmp/ainanika_nar.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT

WITH_SHELL=false
if [[ "${1:-}" == "--with-shell" ]]; then
    WITH_SHELL=true
fi

echo "==> Staging ghost files"
cp -R "$GHOST_SRC/install.txt" "$STAGING/"
mkdir -p "$STAGING/ghost/master"
cp -R "$GHOST_SRC/ghost/master/." "$STAGING/ghost/master/"

# ai_config.json.exampleは配布に含めるが、実config(APIキー入り)は絶対に含めない
rm -f "$STAGING/ghost/master/ai_config.json"
rm -f "$STAGING/ghost/master/data/state.json" 2>/dev/null || true
rm -f "$STAGING/ghost/master/data/transcript.jsonl" 2>/dev/null || true

if $WITH_SHELL; then
    echo "==> Including shell from repo (100+ surfaces)"
    mkdir -p "$STAGING/shell/master"
    cp -R "$REPO_ROOT/shell/." "$STAGING/shell/master/"
fi

NAR_NAME="ai_nanika_ai_chan.nar"
OUTPUT="$PACKAGE_DIR/products/$NAR_NAME"
mkdir -p "$PACKAGE_DIR/products"

echo "==> Creating nar (zip) at $OUTPUT"
(cd "$STAGING" && zip -q -r "$OUTPUT" .)

echo "==> Verifying archive contents"
unzip -l "$OUTPUT" | head -15
echo ""
echo "Done: $OUTPUT"
echo "Ourinへドラッグ&ドロップまたはインストール機能で導入できます。"
echo "インストール後、ghost/master/ai_config.json を作成してAPIキーを設定してください。"
