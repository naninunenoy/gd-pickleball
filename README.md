# gd-pickleball

Godot 4.7 / GDScript の WebAssembly を GitHub Pages で動かすための土台です。ピックルボール本体はまだ入れていません。

## 技術的に可能か

可能です。Godot はゲームの GDScript をブラウザ用に「コンパイルし直す」のではなく、あらかじめビルド済みのエンジン WASM と、ゲームデータを入れた `.pck` をセットで書き出します。Cursor の Linux VM でも、ヘッドレスの Godot エディタと Web 用エクスポートテンプレートがあれば同じ出力が作れます。

GitHub Pages 向けには **スレッドなし** の Web エクスポートを使います。Godot 4.3 以降の既定値で、`SharedArrayBuffer` 用の COOP/COEP ヘッダが不要なため、カスタム HTTP ヘッダを送れない GitHub Pages でも動きます。HTTPS は Pages 側が提供します。

制約:

- Web は Compatibility レンダラ / WebGL 2.0 のみ
- Godot 4 の C# は Web 非対応。このリポジトリは GDScript 専用
- スレッドなしビルドはマルチスレッドより遅い。後で必要なら itch.io 等へスレッドありを出す

公開 URL（Pages を有効化したあと）:

https://naninunenoy.github.io/gd-pickleball/

## 必要なもの

- Godot **4.7.2** Linux x86_64 エディタ
- 同じバージョンの Web エクスポートテンプレート（`web_nothreads_release.zip`）

この VM / GitHub Actions では次で入れます。

```bash
./scripts/install_godot.sh
./scripts/export_web.sh
```

出力は `build/web/`（`index.html`, `index.wasm`, `index.js`, `index.pck`）です。WASM 本体は Git に含めず、CI が毎ビルド生成します。

ローカル確認:

```bash
python3 -m http.server 8080 --directory build/web
```

`file://` で HTML を直接開いても動きません。

## GitHub Pages

`main` への push で `.github/workflows/web.yml` が WASM を書き出し、GitHub Pages にデプロイします。PR では同じエクスポートを検証して artifact に上げますが、Pages へは出しません。

リポジトリで一度だけ、Pages のソースを **GitHub Actions** にしてください。

1. GitHub → Settings → Pages
2. Build and deployment → Source: **GitHub Actions**

マージ後に workflow が成功すれば上記 URL でスモークテスト（跳ねるアイコン）が見られます。
