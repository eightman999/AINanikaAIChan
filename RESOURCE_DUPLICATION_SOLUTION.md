# リソースファイル重複エラーの解決方法

## 問題の概要
- ghost/config.json と shiori/config.json
- ghost/descript.txt と shell/descript.txt
- Xcodeが同じ場所にファイルをコピーしようとして重複エラーが発生

## 解決方法（Geminiと相談済み）

### ステップ1: Xcodeプロジェクトからリソースフォルダの参照を削除

1. **Xcodeで `AINanikaAIChan.xcodeproj` を開く**
2. **左側のプロジェクトナビゲータで、プロジェクトファイル（`AINanikaAIChan`）を選択**
3. **中央のエディタで、TARGETS → `AINanikaAIChan` を選択**
4. **上部のタブから「Build Phases」を選択**
5. **「Copy Bundle Resources」のセクションを開く**
6. **リストの中の `AINanikaAIChan` フォルダ、または `ghost`, `shell`, `shiori` に関連するファイル群を選択**
7. **左下の「-」（マイナス）ボタンを押し、リストから削除**

### ステップ2: カスタムビルドスクリプトの追加

1. **「Build Phases」タブで、左上の「+」（プラス）ボタンをクリック**
2. **「New Run Script Phase」を選択**
3. **新しい「Run Script」セクションを「Copy Bundle Resources」フェーズの直前に移動**
4. **セクションを開き、以下のスクリプトをコピー＆ペースト:**

```bash
# Appバンドル内のリソースのコピー先ディレクトリ
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"

# プロジェクト内のリソースのソースディレクトリ
SOURCE_DIR="${PROJECT_DIR}/AINanikaAIChan/Resources/AINanikaAIChan"

# rsyncを使用して、ディレクトリ構造を維持したまま各フォルダをコピーする
# rsyncは変更があったファイルのみをコピーするため効率的です
#
# 注意: ソースパスの末尾のスラッシュが重要です。これにより、フォルダの中身がコピーされます。

# ghost フォルダをコピー
if [ -d "${SOURCE_DIR}/ghost" ]; then
  echo "Copying ghost directory..."
  rsync -av --delete "${SOURCE_DIR}/ghost/" "${DEST_DIR}/ghost/"
else
  echo "Warning: ${SOURCE_DIR}/ghost not found."
fi

# shell フォルダをコピー
if [ -d "${SOURCE_DIR}/shell" ]; then
  echo "Copying shell directory..."
  rsync -av --delete "${SOURCE_DIR}/shell/" "${DEST_DIR}/shell/"
else
  echo "Warning: ${SOURCE_DIR}/shell not found."
fi

# shiori フォルダをコピー
if [ -d "${SOURCE_DIR}/shiori" ]; then
  echo "Copying shiori directory..."
  rsync -av --delete "${SOURCE_DIR}/shiori/" "${DEST_DIR}/shiori/"
  # SHIORIファイルに実行権限を付与
  chmod +x "${DEST_DIR}/shiori/MacUkagaka.SHIORI"
else
  echo "Warning: ${SOURCE_DIR}/shiori not found."
fi
```

## 効果
- ✅ config.json と descript.txt の重複エラーが解消
- ✅ ghost/, shell/, shiori/ のディレクトリ構造がビルド後も維持
- ✅ 手動作業は数クリックに限定
- ✅ ビルドプロセスは自動化

## 次のステップ
1. 上記の手動作業を実行
2. コード側のリソースパス修正
3. CLIビルドテストで確認

## 注意事項
- スクリプトのSOURCE_DIRパスが正しいか確認
- rsyncコマンドの末尾スラッシュは重要
- SHIORIファイルの実行権限も同時に付与