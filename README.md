# mini-gamebox

親子で遊ぶ Godot 製ミニゲーム集。初期実装は、ゲームセレクトと15×15の2人用五目並べです。

## 起動

Godot **4.6.1 stable** で `game/project.godot` を開いて実行します。
黒が先手で、交点をタップして交互に置きます。縦・横・斜めに5個以上並べば勝ち。禁じ手はありません。
勝った列を緑色で表示し、勝利後も「ひとつ もどる」で直前の手を取り消して続行できます。
「もういちど」で初期化、「ゲームを えらぶ」で選択画面へ戻ります。対局の保存は行いません。
タップ・マウスに対応し、盤面をフォーカスすると矢印キーと Enter / Space でも操作できます。

## Web ビルド

必要なもの: Godot 4.6.1 と同バージョンの Export Templates、Node.js 22以降、pnpm 10。ローカル配信には Python 3 を使います。
Export Templates は Godot のエディターからインストールしてください。

```sh
pnpm test
pnpm build:web
pnpm check:web-size
pnpm serve:web
```

`http://localhost:8788` を開きます。`index.html` の直接オープンでは動作しません。
スマートフォンからは同じLAN上のPCのIPアドレスとポート8788を開いてください。
GodotがPATHにない場合は `GODOT_BIN=/path/to/godot pnpm build:web` のように指定できます。
依存パッケージのインストールは不要です。pnpmを使わず `bash scripts/build-web.sh` でもビルドできます。

出力先は `dist/web/`。参考プロジェクト `test-deploy-godot-web` と同様に、Compatibilityレンダラー、スレッド無効で出力し、Wasmを20 MiB単位に分割します。
ブラウザで順番どおり復元し、gzip非対応時は非圧縮ファイルに切り替えます。
[Cloudflare Pagesの1ファイル25 MiB制限](https://developers.cloudflare.com/pages/platform/limits/)をビルド時に検査します。

## GitHub Actions / Cloudflare Pages

参考リポジトリと同じく、GitHub ActionsからCloudflare PagesへDirect Uploadします。

- `.github/workflows/build-web.yml`: `main`へのpush（PRのマージを含む）または手動実行でWebビルドとサイズ検査を行い、成功後にPagesの`main`へ公開します。`README.md`・`docs/**`のみの変更では起動しません。
- 手動で`main`以外のブランチを選んだ場合はビルド・サイズ検査のみを実行し、公開しません。
- `.github/workflows/test.yml`: **Actions → Run Tests → Run workflow** で五目並べとWasmローダーをテストします。参考と同じくテストは自動デプロイに含めず、push・PRでは起動しません。
- PRイベントではどちらのワークフローも起動しません。

ビルド環境は `barichello/godot-ci:4.6.1`、Node.js 24、pnpm 10.28.1。Wranglerは参考と同じ4.26.0を使用します。

### 初回設定

CloudflareにDirect Upload用のPagesプロジェクトを作成し、GitHubリポジトリの **Settings → Secrets and variables → Actions** に次を登録します。

| 種別 | 名前 | 値 |
| --- | --- | --- |
| Secret | `CLOUDFLARE_API_TOKEN` | 対象アカウントのCloudflare Pages編集権限を持つAPIトークン |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | CloudflareのアカウントID |
| Variable | `CLOUDFLARE_PAGES_PROJECT` | Pagesプロジェクト名（例: `mini-gamebox`） |

プロジェクトの本番ブランチは`main`にします。設定後、`main`にpushするか **Actions → Build Web → Run workflow** で`main`を指定すると公開されます。
ワークフローをGitHubで実行するには、この設定ファイルを含むコードのpushが必要です。
Cloudflareへの実デプロイは未検証です。初回の実行結果はGitHub Actionsで確認してください。

### 手動で公開する場合

ローカルでビルドした `dist/web` を [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) でアップロードすることもできます。

```sh
pnpm build:web
pnpm check:web-size
pnpm dlx wrangler@4.26.0 login
pnpm dlx wrangler@4.26.0 pages project create mini-gamebox --production-branch main
pnpm dlx wrangler@4.26.0 pages deploy dist/web --project-name mini-gamebox --branch main
```

プロジェクト作成は初回のみ。既存のPagesプロジェクトを使う場合は名前を置き換えます。
`dist/web` の分割ファイル、gzipファイル、ローダーを含めた全ファイルを公開してください。

## 構成と追加方法

- `game/scenes/game_select/`: ゲーム選択
- `game/scenes/games/gomoku/`: 盤面描画、画面、独立した対局ロジック
- `game/scripts/game_catalog.gd`: ゲーム一覧。新しいゲームSceneのパスと表示名を追加
- `game/ui/`: 共通テーマ・UI部品
- `game/tests/`: 勝敗、Undo、引き分け、リセットのテスト
- `scripts/`: Webビルド・分割ローダー・サイズ検証

ゲームを追加する場合は `scenes/games/<name>/` にSceneを作り、カタログへ登録します。
日本語フォントは Noto Sans JP（SIL Open Font License）を同梱しています。ライセンスは `game/assets/fonts/OFL.txt`。
