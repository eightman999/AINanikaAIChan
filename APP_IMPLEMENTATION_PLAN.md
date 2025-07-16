# AINanikaAIChan .app統合実装計画書

## 1. プロジェクト概要

### 1.1 現在の構成
- **Swift版MacUkagaka**: UI担当（透明ウィンドウ、キャラクター表示、ユーザーインタラクション）
- **.NET版SHIORI**: ロジック担当（AI処理、SHIORI プロトコル、ビジネスロジック）
- **ghost/ディレクトリ**: ゴーストデータ（C#スクリプト、設定ファイル）
- **shell/ディレクトリ**: キャラクター画像リソース

### 1.2 統合目標
現在の手動2プロセス起動を、ダブルクリックで起動できる単一の.appファイルに統合する。

## 2. 技術アーキテクチャ

### 2.1 現在の技術スタック
```
[Swift UI (AppKit)] ←→ [.NET SHIORI (C#)] ←→ [AIサービス (API)]
        ↓                      ↓
   [shell/画像]         [ghost/スクリプト]
```

### 2.2 統合後のアーキテクチャ
```
AINanikaAIChan.app/
├── Contents/
│   ├── MacOS/
│   │   └── AINanikaAIChan          # Swift実行ファイル
│   ├── Resources/
│   │   ├── ghost/                  # ゴーストデータ
│   │   ├── shell/                  # キャラクター画像
│   │   └── shiori/                 # .NET SHIORI実行ファイル群
│   └── Info.plist
```

## 3. 実装フェーズ

### Phase 1: Xcodeプロジェクトセットアップ
**推定期間**: 2-3日

#### 3.1 Xcodeプロジェクトの作成
1. **Swift Package → Xcode移行**
   - `MacUkagaka/Package.swift`をXcodeで直接開く
   - プロジェクト設定の確認と調整

2. **Bundle設定**
   - Bundle Identifier: `com.yourcompany.ainanikaaichan`
   - アプリケーション名: `AINanikaAIChan`
   - バージョン情報の設定

3. **Info.plist設定**
   - LSUIElement: `true` (メニューバーに表示しない)
   - NSHighResolutionCapable: `true`
   - 必要な権限の設定

#### 3.2 リソースの統合
1. **フォルダ構造の統合**
   ```bash
   # 実行コマンド例
   cd MacUkagaka.SHIORI
   dotnet publish -c Release -r osx-arm64 --self-contained true -p:PublishSingleFile=true
   ```

2. **Xcodeへのリソース追加**
   - `ghost/` → "Create folder references"で追加
   - `shell/` → "Create folder references"で追加
   - `shiori/` → publishされた.NET実行ファイル群を追加

### Phase 2: リソース管理システム実装
**推定期間**: 3-4日

#### 3.3 ResourceManagerクラスの実装
```swift
class ResourceManager {
    static let shared = ResourceManager()
    
    lazy var resourcesURL: URL? = {
        return Bundle.main.resourceURL
    }()
    
    lazy var shioriExecutableURL: URL? = {
        return resourcesURL?.appendingPathComponent("shiori/MacUkagaka.SHIORI")
    }()
    
    lazy var ghostDirectoryURL: URL? = {
        return resourcesURL?.appendingPathComponent("ghost/master")
    }()
    
    lazy var shellDirectoryURL: URL? = {
        return resourcesURL?.appendingPathComponent("shell/master")
    }()
}
```

#### 3.4 設定ファイルの管理
- `config.json`の読み込み処理
- APIキーの暗号化保存
- 設定UIの実装

### Phase 3: プロセス管理システム実装
**推定期間**: 5-6日

#### 3.5 SHIORIProcessManagerクラスの実装
```swift
class SHIORIProcessManager {
    private var shioriProcess: Process?
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    
    func start() {
        // .NET SHIORIプロセスの起動
        // 標準入出力の設定
        // 非同期通信の設定
    }
    
    func sendRequest(_ request: String) {
        // SHIORIリクエストの送信
    }
    
    func stop() {
        // プロセスの正常終了
    }
}
```

#### 3.6 プロセス間通信の実装
1. **標準入出力ベースの通信**
   - Swift側: `Process`の`standardInput`/`standardOutput`
   - .NET側: `Console.ReadLine()`/`Console.Write()`

2. **非同期データ処理**
   - `FileHandle.readabilityHandler`を使用
   - SHIORIレスポンスの解析とUIへの反映

#### 3.7 エラーハンドリング
- プロセス起動失敗時の処理
- 通信エラー時の復旧処理
- アプリケーション終了時のクリーンアップ

### Phase 4: UI統合とテスト
**推定期間**: 4-5日

#### 3.8 既存UIコンポーネントの統合
1. **CharacterWindowControllerの改修**
   - リソースパスの動的解決
   - バンドル内画像の読み込み

2. **SHIORIClientの改修**
   - プロセス管理システムとの統合
   - 通信プロトコルの最適化

#### 3.9 統合テスト
- 単一プロセスでの動作確認
- リソースアクセスの検証
- エラーケースのテスト

### Phase 5: 配布準備
**推定期間**: 3-4日

#### 3.10 コード署名の設定
1. **Apple Developer IDの取得**
   - 開発者アカウントの登録
   - 証明書の取得とインストール

2. **Xcodeでの署名設定**
   - `Signing & Capabilities`の設定
   - 自動署名の有効化

3. **バンドルした.NET実行ファイルの署名**
   ```bash
   # Build Phasesでの実行スクリプト
   codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            --options runtime \
            "${BUILT_PRODUCTS_DIR}/${EXECUTABLES_FOLDER_PATH}/shiori/MacUkagaka.SHIORI"
   ```

#### 3.11 Notarization対応
1. **アプリケーションのアーカイブ**
   - Xcodeでの`Product > Archive`
   - `Developer ID`での配布設定

2. **Notarizationの実行**
   - Appleへのアップロード
   - 審査完了後のダウンロード

#### 3.12 DMGファイルの作成
```bash
# DMG作成スクリプト
hdiutil create -volname "AINanikaAIChan" \
               -srcfolder "/path/to/AINanikaAIChan.app" \
               -ov -format UDZO AINanikaAIChan_v1.0.dmg
```

## 4. 技術的課題と解決策

### 4.1 主要課題

#### 4.1.1 プロセス起動タイミング
**課題**: Swift UIが.NET SHIORIプロセスの起動完了を待つ仕組み

**解決策**:
```swift
func waitForSHIORIReady() {
    let timeout = 10.0 // 10秒のタイムアウト
    let startTime = Date()
    
    while Date().timeIntervalSince(startTime) < timeout {
        if sendHealthCheck() {
            break
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}
```

#### 4.1.2 リソースパス解決
**課題**: 開発時と配布時でのパス差異

**解決策**:
```swift
func resolveResourcePath(_ relativePath: String) -> URL? {
    #if DEBUG
    // 開発時: プロジェクトルートから相対パス
    let projectRoot = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return projectRoot.appendingPathComponent(relativePath)
    #else
    // 配布時: バンドル内から解決
    return Bundle.main.resourceURL?.appendingPathComponent(relativePath)
    #endif
}
```

#### 4.1.3 .NET依存関係の管理
**課題**: ユーザー環境での.NET実行

**解決策**:
- 自己完結型配布（Self-contained deployment）の採用
- NativeAOT（.NET 7+）の検討
- 実行ファイルサイズの最適化

### 4.2 パフォーマンス最適化

#### 4.2.1 起動時間の短縮
1. **遅延初期化**: 必要になるまでリソースを読み込まない
2. **キャッシュ戦略**: 頻繁にアクセスするリソースのメモリキャッシュ
3. **バックグラウンド処理**: UI以外の処理を非同期化

#### 4.2.2 メモリ使用量の最適化
1. **画像の効率的な管理**: 表示中のサーフェスのみをメモリに保持
2. **プロセス間通信のバッファリング**: 適切なバッファサイズの設定

## 5. 代替案の検討

### 5.1 技術的代替案

#### 5.1.1 .NET NativeAOT
**メリット**:
- 起動時間の大幅な短縮
- 真の単一実行ファイル
- メモリ使用量の削減

**デメリット**:
- リフレクションの制限
- コンパイル時間の増加
- 一部ライブラリの非対応

**推奨**: SHIORIの実装がAOT互換であれば採用を検討

#### 5.1.2 Electron/Tauri
**メリット**:
- クロスプラットフォーム対応
- Web技術の活用

**デメリット**:
- パフォーマンス劣化
- バンドルサイズの増加
- macOSネイティブ感の喪失

**推奨**: 現在のSwift + .NET構成を維持

### 5.2 アーキテクチャの代替案

#### 5.2.1 TCP/IP通信
**現在**: 標準入出力
**代替案**: localhost TCP接続

**メリット**:
- より柔軟な通信
- デバッグの容易さ

**デメリット**:
- 実装の複雑化
- ポート衝突の可能性

**推奨**: 現在の標準入出力を維持

## 6. 実装スケジュール

### 6.1 全体スケジュール（推定20-25日）

| フェーズ | 期間 | 主要タスク |
|---------|------|-----------|
| Phase 1 | 2-3日 | Xcodeプロジェクトセットアップ |
| Phase 2 | 3-4日 | リソース管理システム実装 |
| Phase 3 | 5-6日 | プロセス管理システム実装 |
| Phase 4 | 4-5日 | UI統合とテスト |
| Phase 5 | 3-4日 | 配布準備 |
| バッファ | 3-3日 | 問題解決と最終調整 |

### 6.2 マイルストーン

1. **Week 1**: Xcodeプロジェクトの基本セットアップ完了
2. **Week 2**: リソース管理とプロセス管理の実装完了
3. **Week 3**: UI統合とテスト完了
4. **Week 4**: 配布準備と最終調整完了

## 7. 成功指標

### 7.1 機能要件
- [ ] ダブルクリックでアプリケーションが起動する
- [ ] キャラクターが正常に表示される
- [ ] AI機能が正常に動作する
- [ ] 設定変更が可能である
- [ ] アプリケーションが正常に終了する

### 7.2 品質要件
- [ ] 起動時間: 5秒以内
- [ ] メモリ使用量: 100MB以内
- [ ] CPU使用率: アイドル時5%以内
- [ ] 安定性: 24時間連続動作

### 7.3 配布要件
- [ ] コード署名済み
- [ ] Notarization完了
- [ ] DMGインストーラー作成
- [ ] ユーザーマニュアル作成

## 8. リスクと対策

### 8.1 技術的リスク

#### 8.1.1 プロセス間通信の不安定性
**リスク**: 通信エラーによる機能停止
**対策**: 
- 通信エラーの自動復旧機能
- ヘルスチェック機能の実装
- フォールバック処理の実装

#### 8.1.2 .NET配布の複雑さ
**リスク**: ユーザー環境での実行失敗
**対策**:
- 自己完結型配布の採用
- 実行環境の事前チェック
- エラーメッセージの改善

### 8.2 プロジェクトリスク

#### 8.2.1 スケジュール遅延
**リスク**: 技術的困難による開発遅延
**対策**:
- 各フェーズでの中間確認
- 問題発生時の早期エスカレーション
- 機能の優先順位付け

#### 8.2.2 互換性問題
**リスク**: macOSバージョンによる動作差異
**対策**:
- 複数のmacOSバージョンでのテスト
- 最小動作環境の明確化
- 互換性問題の早期発見

## 9. 結論

本実装計画は、現在の技術スタック（Swift + .NET）を活用し、段階的にアプリケーションを統合する実現可能なアプローチを提示している。各フェーズで適切な検証を行い、技術的リスクを最小限に抑えながら、高品質なmacOSアプリケーションの開発を目指す。

**次のステップ**: Phase 1のXcodeプロジェクトセットアップから開始し、各フェーズの完了後に進捗を評価しながら進める。