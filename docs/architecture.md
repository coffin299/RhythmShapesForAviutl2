# アーキテクチャ

RhythmShapes は、1つのカスタムオブジェクトが画面いっぱいの画像を描く。個別オブジェクトは増やさない。

`RhythmShapes.obj2` は設定の定義と、AviUtl2 の `obj` を呼ぶ入口だけを持つ。計算は `rs_*.lua` に分かれていて、`obj` を知らない。テストはこれらのモジュールを直接呼ぶ。

- `rs_host.lua` が音声取得、BPM取得、1フレームの頂点生成、tempbuffer への描画をつなぐ。
- `rs_audio.lua` が PCM の正規化と帯域エネルギーを計算する。
- `rs_beat.lua` が現在の音声窓から打音と、参考値としての BPM 推定を返す。
- `rs_grid.lua` がシーン時刻と BPM リストから拍位置を返す。
- `rs_motion.lua` が拍・音量・打音を 0 以上の駆動量に変える。
- `rs_layout.lua` が固定シードで配置を決める。
- `rs_figure.lua` がフラット図形の構図を返す。背景だけ色トラックを使い、ほかの部品は白である。
- `rs_shape.lua` が図形の三角形頂点を作る。
- `rs_preset.lua` がプリセットの反応先を決め、トラックバーの値で上書きする。

描画は同梱 `script.obj2` の多角形と同じ順にする。先に `obj.load("figure","四角形")` し、`drawtarget` を tempbuffer にして `obj.drawpoly` し、`obj.load("tempbuffer")` でオブジェクト画像に戻す。頂点色は乗算済みアルファで、図形画像は使わない。

図形の座標はバッファ中心が原点である。オブジェクトを画面中央に置くと、プロジェクトの画面に揃う。
