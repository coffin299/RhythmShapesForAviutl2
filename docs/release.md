# リリース手順

バージョンの定義は `script/RhythmShapes/version.lua` の1か所だけである。リリース前に、次の3つを同じ番号にする。

- `version.lua` の `"MAJOR.MINOR.PATCH"`
- `RhythmShapes.obj2` の `--information:RhythmShapes vMAJOR.MINOR.PATCH`
- `CHANGELOG.md` の `## [MAJOR.MINOR.PATCH]`

`lua5.1 tools/check_version.lua` がこの一致を検査する。

正式リリースは `vMAJOR.MINOR.PATCH` のタグに対して公開する。手順は次のとおり。

GitHub の Actions から **Release** を選び、**Run workflow** を開く。ブランチは `main` のまま、バージョン欄へ `1.0.0` のように入力して実行する。`version.lua` と一致し、テストが通ったとき、タグが無ければ `v1.0.0` を追加してから ZIP を公開する。タグが既にあり Release が無いときは、そのタグの内容を公開する。同じ ZIP が既についている Release は作り直さない。`main` 以外の手動実行は失敗する。

タグだけ先に付ける場合は **Create release tag** を使う。そちらのタグ push でも **Release** が動く。

ローカルからタグを打つ場合は次のとおり。

```
git tag v1.0.0
git push origin v1.0.0
```

タグは `vMAJOR.MINOR.PATCH` だけを受け付ける。`v1.0` や `v1.0.0-beta` は失敗し、GitHub Release は作られない。Release が ZIP 無しで残っている場合も失敗し、上書きしない。Pull Request や、通常のブランチ更新だけではタグも Release も作られない。

ワークフローはテストとZIP検証の後で、いったん下書きの Release を作る。ZIPが添付されていることを確認してから下書きを外す。確認に失敗した場合は、その下書きを削除する。

ZIPの名前は `RhythmShapesForAviutl2-vX.Y.Z.zip` である。中身は `RhythmShapes` フォルダ、README、INSTALL、CHANGELOG、LICENSE だけである。テスト、開発ツール、GitHub Actions の設定は含めない。

権限は `contents: write` だけを付ける。外部アクションは、公式の `actions/checkout` をコミット `11bd71901bbe5b1630ceea73d27597364c9af683`（v4.2.2）で固定して使う。
