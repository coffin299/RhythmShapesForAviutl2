# 開発とテスト

計算モジュールは Lua 5.1 の標準ライブラリだけを使う。AviUtl2 2.1.14 の `lua.dll` は Lua 5.1.4 にパッチを当てたもので、`luaJIT.dll` は LuaJIT 2.1 である。スクリプトの既定は LuaJIT で、ソースは 5.1 として書く。

リポジトリのルートで次を実行する。

```
lua5.1 tests/run.lua
lua5.1 tools/check_version.lua
python3 tools/package.py --check
```

Windows に `lua5.1` が無い場合は、AviUtl2 同梱の DLL でテストできる。

```
python tools/run_tests.py F:\Download\aviutl2_v2.1.14\lua.dll
```

`luac5.1 -p` で `script/` と `tools/` の Lua と obj2 を構文検査する。obj2 の先頭設定は Lua のコメントなので、構文検査の対象に含める。

実機確認用に、プレーンな本体の横へ `F:\Download\aviutl2_v2.1.14\data\Script` を作り、RhythmShapes と `ProbeAudio.obj2` を置いた。この `data` フォルダがあると、次回その本体を起動したとき設定の保存先が ProgramData からこちらへ移る。

2026-10-23 の時点では、別の AviUtl2 が未保存のプロジェクトを開いたまま起動していた。プレーンな `aviutl2.exe` は同時に立ち上がらず、`obj.getinfo("version")`、音声の値域、BPMリスト、`script_time`、プレビューと書き出しの一致は未測定である。`--require` は、その整数を読むまで付けない。測定するときは、他の AviUtl2 を終了してから `F:\Download\aviutl2_v2.1.14\aviutl2.exe` を起動し、ProbeAudio を追加してログの `RS_PROBE` 行を見る。

テストしていない動作を、確認済みとは書かない。
