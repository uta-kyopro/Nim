# Skip Beam Search

今後の改善対象は[tourBeam](tour_beam.md)・[skipTourBeam](skip_tour_beam.md)。本実装は`src/lib/search/regacy/`へ退避した。

[編集用テンプレート](../src/lib/search/regacy/skip_beam.nim) / [探索エンジン](../src/lib/search/regacy/skip_beam_core.nim) / [使用例](../src/examples/skip_beam/basic.nim)

実問題の例: [AHC021 A](../src/examples/skip_beam/ahc021.nim)（[問題文](https://atcoder.jp/contests/ahc021/tasks/ahc021_a)）。元コードの整数Action・固定長履歴・近似ハッシュ・評価・1手/2手遷移を使用。貪欲補完は行わず、2000手上限では部分解を出す。

[AHC041 A](../src/examples/skip_beam/ahc041.nim)（[問題文](https://atcoder.jp/contests/ahc041/tasks/ahc041_a)）は固定ターン・得点最大化の例。DFS順に頂点を追加し、根にするか追加済みの隣接頂点を親にするかを探索する。幅128〜16・時間目安1.7秒。未処理頂点は根として出力する。親を追加順で制限するため最適性は保証しない。

[AHC026 A](../src/examples/skip_beam/ahc026.nim)（[問題文](https://atcoder.jp/contests/ahc026/tasks/ahc026_a)）はPython版の「事前整理→掃き出し→露出した昇順の塊を集約」を1遷移にする例。列×乱数シード4通りを探索し、同じ列も再選択する。整列済みの列は集約元から外すが、一時退避には使える。評価は消費体力＋整列済み下部以外の箱数×4。初期幅128・最小幅4、1.4秒を目安に幅を自動調整するが、時間では打ち切らない（`Ahc026BeamWidth` / `Ahc026MinBeamWidth` / `Ahc026TimeLimitMs` を `-d:` で変更可能）。完了解は実コストで保存し、探索終了時に未完了なら必要な箱の上を退避して完走する。乱数系列はPythonとは異なり、整列判定はキャッシュせず再計算、事前整理は1遷移N移動まで。

```sh
nim cpp -d:release --mm:arc -o:build/ahc021 src/examples/skip_beam/ahc021.nim
./build/ahc021 < in.txt > out.txt
nim cpp -d:release --mm:arc -o:build/ahc041 src/examples/skip_beam/ahc041.nim
./build/ahc041 < in.txt > out.txt
nim cpp -d:release --mm:arc -o:build/ahc026 src/examples/skip_beam/ahc026.nim
./build/ahc026 < in.txt > out.txt
```

標準出力は提出形式、標準エラー出力は実際の得点。AHC021の `solve` は元コード同様、初期幅3000・最小幅1000・時間目安1.95秒。時間だけでは打ち切らないため2秒を超える場合がある。提出時はcoreのimportを展開し、実行環境に合わせて幅を調整する。

内部は事前確保付きObjectPool、ビット集合付き線形探索HashMap（整数キーは再ハッシュなし）、再利用する候補配列・セグ木。経路復元は終了時のみ。汎用化に必要な初期完了・探索枯渇・未来の親ノード保護は残している。
セグ木はindexだけを保持し、幅到達時に一括構築する。余った葉は末尾候補のindexで埋め、
比較時の無効値判定と、構築前の配列全消去を省く。末尾候補だけの部分木は常に同じindexを保持するため、
末尾候補の改善・置換も、実際の葉から根へ更新すればよい。

状態を適用・巻き戻しして巡回する差分更新ビームサーチ。編集用テンプレートと探索エンジンは `src/lib/search/regacy/` に配置している。

`src/lib/search/regacy/skip_beam.nim` の「問題ごとに編集」だけを書き換える。未実装の関数は例外を出す。
`evaluate`は既定で`State.score`、`getHash`は`State.hash`を返す。初期値を設定し、
`moveForward`で評価値・Hashを差分更新、`moveBackward`で元の値へ戻す。
必要なら`evaluate`や`getHash`を計算式へ書き換えられる。
探索エンジンの引数・内部整合性チェックは `-d:debug` のときだけ行う。通常ビルドでは有効な引数・遷移を渡す必要がある。
coreは共通の`header.nim`をincludeする。headerから読み込むNim ACLなども利用環境に必要。
問題ごとにコピーして使う場合は、先頭の `skip_beam_core` のimport先を配置に合わせる。

## 呼び出し

```nim
include ../src/lib/header # 実際の配置に合わせる
import ../src/lib/search/regacy/skip_beam # 実際の配置に合わせる

# テンプレートの型・関数を書き換え、初期Stateを用意する。
let answer = skipBeam(initial, beamWidth = 1000)
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
| `groupLimit` | `0` | 0は従来の全体幅選抜。正なら各グループの保持上限 |
| `groupCount` | `0` | グループ数。IDは `0..<groupCount` |
| `stopOnTimeLimit` | `true` | `false`なら時間は幅調整にのみ使用（元コードの動作） |

可変幅は累積幅・経過時間率・残りターンから推定し、減らす方向にだけ調整する。元コード同様、登録済み候補の幅は維持し、selector再利用時から新しい幅を適用する。時間による打ち切りはターン終了時に確認するため、厳密な時刻ではない。
固定幅では幅調整用の累積幅を集計せず、時間制限0では開始時刻も取得しない。

```nim
let answer = skipBeam(initial, beamWidth = 3000,
    minBeamWidth = 1000, timeLimitSec = 1.95, stopOnTimeLimit = false)
```

## テンプレート内で書き換えるもの

```nim
type State = object                    # 盤面・巻き戻し履歴など
    score: CostType
    hash: HashType
    isFinished: bool
# Action・CostType・HashTypeも問題に合わせる。
# evaluate/getHashは既定のフィールド参照。isFinishedは遷移時に更新する。
proc moveForward(s: var State, a: Action)
proc moveBackward(s: var State, a: Action)
proc expand(s: var State, frontier: var Frontier)
```

`expand` で合法な行動を列挙して次を呼ぶ。適用・評価・巻き戻し・登録をまとめた補助関数。

```nim
self.pushCandidate(frontier, action, step = 1)
```

親番号はcoreが展開時に設定するため、通常は指定不要。この省略形は`expand`内で使う。
固定ターン問題で主に実装する関数は、適用・巻き戻し・候補列挙の3つになる。
従来の`expand(state, parent, frontier)`と`pushCandidate(frontier, parent, action, ...)`も利用できる。
両形式の`expand`がある場合は親番号を省略する形式を優先する。
整数Actionでも曖昧にならないよう、省略形の`step`・`group`は名前付きで指定する。

この補助関数はcoreを直接importする場合も利用できる。事前足切りを通過した候補は、
内部で同じ足切りを繰り返さず登録する。評価・Hash取得・巻き戻し中に同じfrontierへ登録しない。
直接`frontier.push`する場合は従来どおり足切りを行う。

- 自分で差分評価する場合は `frontier.push(action, score, key, parent, finished, step)` を直接呼べる。評価・キー・完了判定は**遷移後**の値。`parent` は受け取った値を渡す。
- `moveBackward` は対応する `moveForward` を完全に戻す。`expand` も呼び出し前の状態に戻して終了する。
- 各層の最良候補は比較中にindexだけを保持し、選び終わってから候補を1回コピーする。
- `step` は正のターン消費量。2以上なら途中の層を飛ばす。上限を超える候補は採用しない。
- 未完了候補は同じ到達ターン・同じキーで最良だけを保持。ハッシュをキーにする場合、衝突は同一状態扱い。
- 同じキーの後発候補が改善した場合はAction・評価値・親ノード番号をまとめて差し替える。同点・悪化は先の候補を残す。
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

## グループ別選抜と遅延Hash計算

追加引数は既存引数の末尾にあり、従来の呼び出し・選抜動作は変わらない。
`runSkipBeam`、`defineSkipBeam`で定義した関数、テンプレートの`skipBeam`が対応する。
`groupLimit > 0`なら、各到達ターンでグループID順に処理し、各グループの上位K件を残す。
全体の`beamWidth`による打ち切りはなく、最大`groupCount * groupLimit`件を保持する。
グループ内は評価値で安定ソートし、同点は登録順。同じキーはグループをまたいで重複除去する。
複数グループに同じキーを登録した場合は、小さいグループIDの採用候補が優先されるため、
同一状態には同じグループIDを割り当てることを推奨する。重複はK件の枠を消費しない。
完了候補は従来どおり選抜枠と独立し、最初の登録を保持する。

グループ方式は固定上限で使用し、`minBeamWidth = 0`にする。併用はdebugでエラー。
全候補を一旦保存するため、登録M件・グループ数Gに対し追加メモリO(M + G)、選抜時間は
O(G + M + Σ M_g log M_g)（Hash集合の操作は平均O(1)）。全体幅方式の候補登録O(log W)とは異なる。
将来ターンのバケットに候補があれば、途中の層が空でも探索を継続し、親ノードも保持する。

```nim
# expand内。scoreとfinishedを先に計算し、採用の余地がある場合だけkeyを計算する。
if step <= frontier.remainingTurns():
    let score = previewScore(action)       # 利用側で実装
    let finished = previewFinished(action) # 利用側で実装
    let group = destinationGroup(action)   # 利用側で実装
    if frontier.canImprove(score, step = step, finished = finished, group = group):
        let key = previewHash(action)     # 利用側で実装
        frontier.push(action, score, key, parent, finished, step, group)

# 呼び出し側。グループを位置などに割り当てる。
let answer = skipBeam(initial, beamWidth = 1000, groupLimit = 10, groupCount = 256)
echo answer.selectedCandidates
```

`remainingTurns()`は現在の展開位置から残るターン数。`step`がこれを超える候補は登録できない。
`canImprove`は副作用のない事前判定で、falseなら同条件の`push`は不採用。
trueは採用保証ではなく、同じキーの既存候補などで不採用になり得る。
標準方式では到達ターンの選抜閾値を使い、満杯なら同点も不採用。
グループ方式の未完了候補には保守的にtrueを返す。完了候補は閾値で足切りしないため、
必ず正しい`finished`を渡す。`pushCandidate`もこの順序で評価・Hash計算・巻き戻しを行う。

`selectedCandidates: int64`は処理済み各到達ターンの選抜後の未完了候補数に、
その層の完了候補数（0または1）を足した累計。初期完了・ゼロターンでは0。
候補生成数、DFS展開数、返した行動数とは異なり、完了時の層の未完了候補も含む。
時間切れでも処理済み層までの累計を返す。

Nim 2.2.4のdebug/releaseで、従来APIとの互換性、グループ別選抜、
重複除去、事前足切り、選抜件数、複数ターン遷移、経路復元を検証した。
グループ別選抜はランダムDAG 100個×保持上限3通り×評価方向2通りの600条件で、
状態をコピーする参照実装とスコア・到達ターン・選抜件数を比較している。

事前足切り済みの登録経路は、従来の登録とグループ・同点・完了・複数ターン遷移を
組み合わせて結果を照合した。足切り時にHashを取得しないことと、State・Hashの復元も検証した。
AHC041の小規模20入力では全列挙との一致、AHC026の22入力では手順再生と得点を確認した。

固定幅4096・200ターン・12分岐の合成探索を、順序を入れ替えて9回ずつ測定した中央値（ms）：

| 変更 | Action 8B | Action 136B |
|---|---:|---:|
| 変更前 | 385.82 | 631.35 |
| 最良候補をindexで比較 | 385.47 | 618.09 |
| 足切りの重複削減 | 386.79 | 615.18 |
| 固定幅時の集計省略など | 387.47 | 660.68 |
| 全変更 | 380.90 | 604.78 |

各版の行動列・評価値・選抜件数は一致。単独変更の時間比率の95%信頼区間はすべて1を含み、
個別の速度改善は確認できていない。全変更の中央値は約1.3〜4.2%短縮したが、
ばらつきがあり、この合成測定は実問題での高速化を保証するものではない。

同じHashの改善更新に対応する位置配列付きヒープも試作したが、差分更新型では採用していない。
評価値をヒープ内に保持する版でも、幅4096・200ターン・12分岐の合成探索を9回ずつ測定した中央値は、
Action 8Bで簡略化前のセグ木373.90msに対しヒープ409.87ms、Action 136Bでは526.71msに対し544.98msだった。
評価値・行動列・選抜件数は一致した。現在はインデックスだけを持つセグ木を維持している。
同じHashの後発改善、同点・悪化の棄却、追い出されたキーの再登録、親からの行動復元は別途検証した。

無効値判定と構築前の全消去を省く簡略化を、同じ合成探索で実行順を入れ替えて9回ずつ測定した中央値は、
幅4096・Action 8Bで378.00→368.50ms、Action 136Bで534.22→512.35msだった。
幅64も含む4条件で約2.5〜4.1%短縮し、評価値・行動列・選抜件数は一致した。
非2冪幅で末尾候補を改善・置換する場合と、最小化・最大化の両方も検証している。

## Stateの完了フラグ

編集用テンプレートは`State.isFinished: bool`を持つ。完了判定用の関数は不要。
初期Stateにも正しい値を設定し、固定ターン探索ならfalseのままにする。
通常beamは`expand`で遷移先の`next.isFinished`を設定してから登録する。
差分更新型の`pushCandidate`は仮適用後の値を読むため、`moveForward`で更新し、
`moveBackward`で以前の値を復元する。展開前のStateのフラグを使い回さない。

```nim
# moveForward内：遷移先の完了状態を保持する
self.isFinished = goalCondition
# moveBackward内では、変更前のisFinishedも復元する
```

`expand`内で評価値・キー・完了判定をまとめて計算する場合は、既存の`push`へ
`finished = goalCondition`を直接渡してもよい（通常beamでは遷移後Stateも渡す）。
初期状態の完了判定にはState側のフラグが必要。
`State`には実在する`isFinished: bool`フィールドが必須。
旧`proc/template isFinished(state): bool`形式は受け付けない。
フラグが将来の動作を区別する情報なら、同一キーで異なる状態を混ぜないようにする。

## 葉の評価値・Hash

採用候補の生値を保持し、`expand`直前に`frontier.currentScore`・
`frontier.currentHash`へ渡す。初期値は`evaluate(initial)`・`getHash(initial)`。
`getHash`は直接`push`する実装でも必要となる。

巡回だけを軽くする場合は`moveBoardForward`・`moveBoardBackward`で盤面・
巻き戻し履歴・`isFinished`だけを更新し、`loadLeaf(state, leafScore, leafKey)`で
評価値・Hashを復元する。この3つはセットで実装する。
盤面フックを省略した場合は従来の`moveForward`・`moveBackward`を使う。
`pushCandidate`の一時評価と最終Action列の再生には通常の遷移を使う。
評価値がStateの保持値と異なる場合は`loadLeaf`で逆変換する。
生値だけから復元できない成分は盤面フックでも更新する。

巡回中の評価用フィールドは古い値なので、盤面フックから参照しない。
`expand`は候補を作るたびに盤面・評価値・Hashを元へ戻す。
