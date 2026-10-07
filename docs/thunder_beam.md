# Thunder Beam Search

[編集用テンプレート](../src/lib/search/thunder_beam.nim) / [探索エンジン](../src/lib/search/thunder_beam_core.nim) / [使用例](../src/examples/thunder_beam/basic.nim)

実問題の例: [AHC021 A](../src/examples/thunder_beam/ahc021.nim)（[問題文](https://atcoder.jp/contests/ahc021/tasks/ahc021_a)）。元コードの整数Action・固定長履歴・近似ハッシュ・評価・1手/2手遷移を使用。貪欲補完は行わず、2000手上限では部分解を出す。

[AHC041 A](../src/examples/thunder_beam/ahc041.nim)（[問題文](https://atcoder.jp/contests/ahc041/tasks/ahc041_a)）は固定ターン・得点最大化の例。DFS順に頂点を追加し、根にするか追加済みの隣接頂点を親にするかを探索する。幅128〜16・時間目安1.7秒。未処理頂点は根として出力する。親を追加順で制限するため最適性は保証しない。

[AHC026 A](../src/examples/thunder_beam/ahc026.nim)（[問題文](https://atcoder.jp/contests/ahc026/tasks/ahc026_a)）はPython版の「事前整理→掃き出し→露出した昇順の塊を集約」を1遷移にする例。列×乱数シード4通りを探索し、同じ列も再選択する。整列済みの列は集約元から外すが、一時退避には使える。評価は消費体力＋整列済み下部以外の箱数×4。初期幅128・最小幅4、1.4秒を目安に幅を自動調整するが、時間では打ち切らない（`Ahc026BeamWidth` / `Ahc026MinBeamWidth` / `Ahc026TimeLimitMs` を `-d:` で変更可能）。完了解は実コストで保存し、探索終了時に未完了なら必要な箱の上を退避して完走する。乱数系列はPythonとは異なり、整列判定はキャッシュせず再計算、事前整理は1遷移N移動まで。

```sh
nim cpp -d:release --mm:arc -o:build/ahc021 src/examples/thunder_beam/ahc021.nim
./build/ahc021 < in.txt > out.txt
nim cpp -d:release --mm:arc -o:build/ahc041 src/examples/thunder_beam/ahc041.nim
./build/ahc041 < in.txt > out.txt
nim cpp -d:release --mm:arc -o:build/ahc026 src/examples/thunder_beam/ahc026.nim
./build/ahc026 < in.txt > out.txt
```

標準出力は提出形式、標準エラー出力は実際の得点。AHC021の `solve` は元コード同様、初期幅3000・最小幅1000・時間目安1.95秒。時間だけでは打ち切らないため2秒を超える場合がある。提出時はcoreのimportを展開し、実行環境に合わせて幅を調整する。

内部は事前確保付きObjectPool、ビット集合付き線形探索HashMap（整数キーは再ハッシュなし）、再利用する候補配列・セグ木。経路復元は終了時のみ。汎用化に必要な初期完了・探索枯渇・未来の親ノード保護は残している。

状態を適用・巻き戻しして巡回する差分更新ビームサーチ。ルートの `thunder_beam.nim` は元コードとして残している。

`src/lib/search/thunder_beam.nim` の「問題ごとに編集」だけを書き換える。未実装の関数は例外を出す。
問題ごとにコピーして使う場合は、先頭の `thunder_beam_core` のimport先を配置に合わせる。

## 呼び出し

```nim
import ../src/lib/search/thunder_beam # 実際の配置に合わせる

# テンプレートの型・関数を書き換え、初期Stateを用意する。
let answer = beamSearch(initial, beamWidth = 1000)
echo answer.score
echo answer.actions
```

| 引数 | 既定値 | 意味 |
| --- | --- | --- |
| `maxTurns` | `2000` | 探索するターン数の上限 |
| `minimize` | `true` | `false`ならスコア最大化 |
| `timeLimitSec` | `0.0` | 0は無制限。呼び出し開始からの秒数 |
| `minBeamWidth` | `0` | 0は固定幅。正なら時間に応じてこの幅まで縮小（時間制限必須） |
| `widthUpdateInterval` | `256` | 幅を見直すターン間隔 |
| `stopOnTimeLimit` | `true` | `false`なら時間は幅調整にのみ使用（元コードの動作） |

可変幅は累積幅・経過時間率・残りターンから推定し、減らす方向にだけ調整する。元コード同様、登録済み候補の幅は維持し、selector再利用時から新しい幅を適用する。時間による打ち切りはターン終了時に確認するため、厳密な時刻ではない。

```nim
let answer = beamSearch(initial, beamWidth = 3000,
    minBeamWidth = 1000, timeLimitSec = 1.95, stopOnTimeLimit = false)
```

## テンプレート内で書き換えるもの

```nim
type State = object                    # 盤面・巻き戻し履歴など
# Action・CostType・HashTypeも問題に合わせる。
proc evaluate(s: var State): CostType   # 小さいほど良いのが既定
proc getHash(s: State): HashType        # 重複排除用キー
proc isFinished(s: State): bool         # 終了判定
proc moveForward(s: var State, a: Action)
proc moveBackward(s: var State, a: Action)
proc expand(s: var State, parent: int,
    frontier: var Frontier)
```

`expand` で合法な行動を列挙して次を呼ぶ。適用・評価・巻き戻し・登録をまとめた補助関数。

```nim
self.pushCandidate(frontier, parent, action, step = 1)
```

- 自分で差分評価する場合は `frontier.push(action, score, key, parent, finished, step)` を直接呼べる。評価・キー・完了判定は**遷移後**の値。`parent` は受け取った値を渡す。
- `moveBackward` は対応する `moveForward` を完全に戻す。`expand` も呼び出し前の状態に戻して終了する。
- `step` は正のターン消費量。2以上なら途中の層を飛ばす。上限を超える候補は採用しない。
- 未完了候補は同じ到達ターン・同じキーで最良だけを保持。ハッシュをキーにする場合、衝突は同一状態扱い。
- `State` は値としてコピーできる型を使う。変更する領域を `ref` / `ptr` で初期状態と共有しない。

## 結果

`score` は候補に渡した評価値（初期状態なら `evaluate`）、`actions` は行動列、`turns` は `step` の合計。
競技固有の最終得点と評価値が異なる場合は、行動列を再生して最終得点を計算する。

| `status` | 意味 |
| --- | --- |
| `beamFinished` | 最初の完了ターンで、最初に登録された完了候補を返す（元コードと同じ） |
| `beamMaxTurns` | ターン上限に到達 |
| `beamExhausted` | 次の候補がなくなった |
| `beamTimeLimit` | 時間制限に到達 |

未完了なら最後に選抜できた層の最良候補を返す。まだ選抜していなければ初期状態と空の行動列。
固定ターン問題では `isFinished` と候補の `finished` を常に `false` にする。
