# gd-pickleball

見下ろし 2D のピックルボール・ダブルスです。今の版はサーブからラリーを繰り返し、先に 11 点です。

- 操作とルール（人間向け）: [`docs/rules.md`](docs/rules.md)
- 実装メモ（AI / 開発者向け）: [`docs/implementation.md`](docs/implementation.md)

WASD は選手移動ではなく打ち先、東西南北は球種です。移動は自動で、近い方が打ちます。

## 動かし方

Godot **4.7.2** で `scenes/main.tscn` を実行します。ヘッドレス確認:

```bash
./scripts/install_godot.sh
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --quit-after 720 -- --auto-rally
```

## Web 公開

Godot 4.7 / GDScript を GitHub Pages 向け WASM で出します。ゲームの GDScript をブラウザ用にコンパイルし直すのではなく、ビルド済みのエンジン WASM と `.pck` をセットで書き出します。

GitHub Pages 向けには **スレッドなし** の Web エクスポートを使います。Godot 4.3 以降の既定値で、`SharedArrayBuffer` 用の COOP/COEP ヘッダが不要なため、カスタム HTTP ヘッダを送れない GitHub Pages でも動きます。

制約:

- Web は Compatibility レンダラ / WebGL 2.0 のみ
- Godot 4 の C# は Web 非対応。このリポジトリは GDScript 専用
- スレッドなしビルドはマルチスレッドより遅い

公開 URL（Pages を有効化したあと）:

https://naninunenoy.github.io/gd-pickleball/

```bash
./scripts/install_godot.sh
./scripts/export_web.sh
python3 -m http.server 8080 --directory build/web
```

`file://` で HTML を直接開いても動きません。`main` への push で `.github/workflows/web.yml` が Pages に出します。リポジトリで一度だけ、Pages のソースを **GitHub Actions** にしてください。
