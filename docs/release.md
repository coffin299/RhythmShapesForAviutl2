# リリース手順

バージョンの定義は `script/RhythmShapes/version.lua` の1か所だけである。リリース前に、次の3つを同じ番号にする。

- `version.lua` の `"MAJOR.MINOR.PATCH"`
- `RhythmShapes.obj2` の `--information:RhythmShapes vMAJOR.MINOR.PATCH`
- `CHANGELOG.md` の `## [MAJOR.MINOR.PATCH]`

`lua5.1 tools/check_version.lua` がこの一致を検査する。

正式リリースは、`main` にそのコミットがある状態で、注釈付きタグを push する。

```
git tag v1.0.0
git push origin v1.0.0
```

タグは `vMAJOR.MINOR.PATCH` だけを受け付ける。`v1.0` や `v1.0.0-beta` は Release ワークフローが失敗し、GitHub Release は作られない。同じタグの Release が既にある場合も失敗し、上書きしない。

ワークフローはテストとZIP検証の後で、いったん下書きの Release を作る。ZIPが添付されていることを確認してから下書きを外す。確認に失敗した場合は、その下書きを削除する。

ZIPの名前は `RhythmShapesForAviutl2-vX.Y.Z.zip` である。中身は `RhythmShapes` フォルダ、README、INSTALL、CHANGELOG、LICENSE だけである。テスト、開発ツール、GitHub Actions の設定は含めない。

権限は `contents: write` だけを付ける。外部アクションは、公式の `actions/checkout` をコミット `11bd71901bbe5b1630ceea73d27597364c9af683`（v4.2.2）で固定して使う。
