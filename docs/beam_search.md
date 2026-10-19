# Beam Search

[編集用テンプレート](../src/lib/search/beam_search.nim) / [探索エンジン](../src/lib/search/beam_search_core.nim) / [最小例](../src/examples/beam_search/basic.nim) / [AHC073例](../src/examples/beam_search/ahc073.nim)

[バケット化の例](../src/examples/beam_search/grouped.nim)

Stateを候補ごとにコピーする通常のビームサーチ。
現在層と次層のNode配列を持ち、Stateの差分更新・巻き戻しは使わない。
`BeamSearchNode[State, Score, Key, Action]`に`state`・`score`・`key`・`action`・`parentId`を格納する。
過去のStateは保存せず、採用された各層のActionと親履歴IDだけを別配列へ保存する。
以下のセグ木は通常選抜（`groupLimit = 0`）で使う。グループ別選抜は後述のバケットを使う。
セグ木には最悪候補のNodeインデックスだけを持ち、評価値は`nodes[index].score`から読む。
幅に達するまでは候補配列だけを更新し、幅に達した時点でセグ木をO(W)で一括構築する。
満杯なら最悪候補を置き換え、Nodeの評価値変更後に根まで最悪インデックスを更新する。
各層でセグ木の配列を再利用し、次に幅へ達した時点で構築し直す。
ハッシュ表は採用中のキーとNodeインデックスを対応付ける。
Skip Beamの最悪値による選抜方針を流用している。
`BeamStatus`はこのモジュール内に直接定義し、`skip_beam_core`には依存しない。
共通の`header.nim`をincludeする。headerから読み込むNim ACLなども利用環境に必要。
両方のcoreをimportするときは、必要に応じて`beam_search_core.BeamStatus`などで型を区別する。

## 利用方法

テンプレートの`State`・`Action`・`evaluate`・`isFinished`・`expand`を書き換える。
`getHash`は既定で`State.hash`を返す。初期Hashを設定し、遷移時に差分更新する。
必要なら`getHash`も書き換えられる。
直接coreをimportし、型ごとに`defineBeamSearch`で関数を定義してもよい。

```nim
include ../src/lib/header # 配置に合わせる
import ../src/lib/search/beam_search_core # 配置に合わせる

type
    State = object
        value: int
    Frontier = BeamSearchFrontier[State, int, int, int]

proc evaluate(s: State): int = abs(10-s.value)
proc getHash(s: State): int = s.value
proc isFinished(s: State): bool = s.value == 10
proc expand(s: var State, frontier: var Frontier) =
    for action in [1,2]:
        if s.value+action > 10: continue
        var next = s
        next.value += action
        next.pushCandidate(frontier, action)

defineBeamSearch(beamSearch, State, int, int, int)
let answer = beamSearch(State(), beamWidth = 100, maxTurns = 10)
echo answer.score
echo answer.actions
```

`expand`の1回の遷移が1層。渡したActionを`answer.actions`で探索順に受け取る。
`parentId`はcoreが展開中の親に合わせて自動設定する。ユーザーが管理する必要はない。
IDは履歴配列を指し、再利用されるNode配列のスロットを指さない。
AHC073のような逆順探索ではAction列も逆順探索の順序なので、必要な順序へ変換する。
Stateは値として独立にコピーできる型にする。可変な領域を`ref` / `ptr`で共有しない。
大きな固定入力は探索外に置き、Stateには変化する情報だけを入れる。

## APIと選抜規則

`beamSearch(initial, beamWidth, maxTurns = 2000, minimize = true, groupLimit = 0, groupCount = 0)`。
先頭の引数と評価方向はSkip Beamと同じ。時間計測は行わない。
`runBeamSearch[State, Score, Key, Action]`も同じ引数を受け取る。
第4型引数を省略した既存APIも使える。この場合は履歴を保存せず、`actions`は空になる。
幅は正、ターン数は非負とする。引数検証は`-d:debug`時のみ。

- `next.pushCandidate(frontier, action, group = -1)`：評価と完了判定を行い、採用の余地があるときだけHashを計算して登録。
- `frontier.canImprove(score, finished = false, group = -1)`：副作用のない事前足切り。trueでも重複キーで不採用になり得る。
- `frontier.push(next, score, key, action = action, finished = false, group = -1)`：計算済みの値で登録。遷移後の値を渡す。
- `frontier.push(node, finished = false, group = -1)`：Nodeを直接登録。通常選抜のpushは採用可否、バケット化では保留できたかをboolで返す。

通常選抜では各層で未完了候補を最大`beamWidth`件保持する。同じキーは最良のみ。
未完了候補の最良値は終了時だけ走査し、選んだStateを結果へコピーする。
満杯時は最悪値と同点でも不採用。同じキーの同点も先の候補を保持する。
キーの一致を同一状態として扱うため、将来の遷移に影響する情報をキーに含める。
Scoreは`<`で比較でき、Keyは標準`Table`で使える型を指定する。

完了候補は通常の選抜枠・評価値とは独立して、各層で最初の登録を保持する。
その層の全展開後に返す。固定ターン問題の最終層でも全候補を比較する場合は、
`isFinished`を常にfalseにして`maxTurns`で止める。

## バケットによるグループ別選抜

差分更新型と同じく、`groupLimit > 0`で有効になる。`groupCount`は正にし、
候補登録時に`0..<groupCount`の`group`を渡す。`groupLimit = 0`なら従来の通常選抜。
引数は既存APIの末尾に追加しており、Action履歴なしの3型引数APIでも使える。

```nim
# expand内。親履歴IDは通常選抜と同様に自動設定される。
next.pushCandidate(frontier, action, group = groupId)

# 呼び出し側。各グループ10件、全体では最大40件。
let answer = beamSearch(initial, beamWidth = 100,
    groupLimit = 10, groupCount = 4)
```

- グループIDの昇順に処理し、各グループ内の上位`groupLimit`件を残す。同点は登録順。
- 同じHashは全グループを通して重複除去し、重複した候補は保持枠を消費しない。
- 異なるグループに同じHashがある場合、小さいグループIDで選ばれた候補が優先される。
  同一状態は同じグループに割り当てることを推奨する。
- `beamWidth`による全体上限は使わず、最大`groupCount * groupLimit`件を保持する。
- 未完了候補を一旦バケットに保留し、層終了時に安定ソート・重複除去する。
  `canImprove`は未完了候補へ保守的にtrueを返し、Hashによる足切りは選抜時に行う。
- 完了候補はバケットの保持枠とは独立し、最初の登録を返す。Action復元も通常選抜と同じ。

全候補M件・グループ数Gに対し、一時領域O(M + G)、選抜時間は
O(G + M + Σ M_g log M_g)。各候補にStateを保持するため、大きなStateや候補数ではメモリ使用量に注意する。
バケット化を無効にした追加前後のAHC073比較では、幅64（10入力×3回）は100.27→100.33ms、
幅2816（3入力×3回）は1628.26→1647.24msで、約0.1%・1.2%の時間増だった。出力は全件一致した。

## 結果と計算量

`BeamSearchResult`の`state`・`score`・`key`は返した候補の値、`turns`は処理した層数。
未完了時は最後に選抜できた層の最良を返す。まだ選抜していなければ初期状態。
`status`は`beamFinished`・`beamMaxTurns`・`beamExhausted`。
`selectedCandidates: int64`は各層の選抜後の未完了数と完了候補数（最大1）の累計。
初期完了・ゼロターンでは0。
`actions`は返したStateに至るAction列。初期完了・ゼロターン・初回の候補枯渇では空。
途中の候補枯渇では最後に選抜できた層までの列を返し、完了時には最後のActionも含む。
履歴への追加は各層の選抜確定後のみ行う。途中で棄却・置換された候補は保存しない。
最終層は返却する候補だけを親履歴から復元し、選抜済みの全候補を追記する処理を省く。

通常選抜では幅Wに対し、選抜の更新はO(log W)、キー検索は平均O(1)。
Stateのコピーコストは別途かかる。保持領域は2層分のO(W × Stateサイズ)と、
ハッシュ表・セグ木のO(W)。Action履歴ありではさらにO(W × ターン数 × 履歴要素サイズ)を使う。
Action復元はO(返却するターン数)。履歴なしAPIでは過去世代の保存も復元も行わない。
可変幅・複数ターン遷移が必要なら[Skip Beam](skip_beam.md)を使う。
1ターン遷移をStateの差分更新で処理する[Tour Beam](tour_beam.md)も用意している。
AHC073例の経路計算・評価・入出力は`ahc073_problem.nim`にまとめ、両方式で共有する。

## AHC073の使用例

[公式問題文](https://atcoder.jp/contests/ahc073/tasks/ahc073_a)に対応するサンプル。
既存AHC073ソルバの逆順区間遷移と予測評価を流用する。
最後の目的地から出発点へ向けて、1層ずつ前の区間を決める。
各区間で転移0〜3回の40通りを列挙する。同じ魔法陣の再使用も含む。

逆順の転移は「元の出発点へ移動し、元の魔法陣を復元する」操作として扱う。
逆転移の前後座標をsource・destとすると、復元する魔法陣はその中点。
sourceとdestの各座標の偶奇を揃え、全座標を盤内に保つ。
終点側の魔法陣は未確定から始め、初めて使うときに位置を選ぶ。
逆順探索が出発点まで到達したときの配置が、出力する初期配置になる。

Stateには魔法陣3個・累積操作数・処理した区間数だけを保持する。
各区間の転移順IDは`uint8`のActionとしてNodeに渡し、結果の`actions`から再生する。
同じ層の現在位置は共通なので、キーは未確定を含む魔法陣の多重集合を45bitに詰める。
評価値は`200 × 累積操作数 − 先の最大12区間の推定削減量`。
同じ配置では予測項も同じため、累積操作数が小さい候補が残る。
予測用の表は各層で1回だけ更新し、State間で共有する。

探索後に転移順を再生し、歩行方向と操作順を反転して提出形式へ変換する。
既存版の焼きなまし・偶奇DPによる後処理は含めない。
操作上限を超えた場合は歩行のみの経路を出す。

```sh
nim cpp -d:release -o:build/beam073 src/examples/beam_search/ahc073.nim
./build/beam073 < in.txt > out.txt
```

既定幅は64。`-d:Ahc073BeamWidth=128`で変更できる。
標準出力は提出形式、標準エラー出力は操作数と選抜件数。

## 検証

通常ビームの選抜には、indexだけを持ち、幅到達時に一括構築するセグ木を採用した。
AHC073で各入力3回の中央値を平均すると、幅64（10入力）は現行の評価値・index保持方式の101.38msから99.84ms、
幅2816（3入力）は1730.89msから1635.05msへ短縮した。同条件のヒープはそれぞれ100.23ms、1669.87ms。
全方式で出力は一致した。少数入力・検証環境での測定値であり、任意のStateサイズや問題での改善は保証しない。

Nim 2.2.4のdebug/releaseで、衝突するキーと同点を含む4万回の候補登録、
ランダムグラフ100個×幅3通り×評価方向2通りを参照実装と比較する。
Stateの独立性、完了候補、ゼロターン、探索枯渇も検証する。
Action履歴は分岐・重複・スロット再利用と、参照を含むActionの寿命を検証する。
AHC073の幅64の例は100入力を公式ローカルツールで再生し、
すべて合法・全目的地到達・操作上限内であることを確認した。
逆順遷移は小盤面の8,000通りでコスト・再使用の合法性・正順への変換を検証し、
魔法陣を重複使用しない順序のコストを全列挙の最短値と照合した。
同じ100入力・幅64で、前の順方向サンプルの平均スコア2,486.30に対し、
逆順版は7,833.05（100勝・0敗）。平均操作数5,200.35、releaseの最大実行時間は
検証環境で約0.15秒だった。debug/releaseの10入力でもスコアと操作数が一致した。
テストと診断結果はローカル専用として管理する。
バケット選抜は、同点・グループをまたぐ重複・完了候補・全体幅を超える保持数・ActionなしAPIを検証し、
ランダムDAG 100個×評価方向2通り×保持上限3通りの600条件で独立した参照実装と状態・評価値・行動列・選抜件数を照合する。

Action履歴をStateから分離したAHC073例では、Stateは176→24バイト、Nodeは192→56バイト。
同じ100入力を5回ずつ交互実行し、各入力の中央値を平均した探索時間は
103.78→103.96ms（約0.18%増、比率の95%信頼区間0.9997〜1.0037）で、明確な速度差は確認できなかった。
出力は全件一致し、公式検証も100/100通過、平均スコアは7,833.05で同じ。
別途2ms間隔で観測したプロセス全体のピークWorking Setの平均は69.46→69.84MiB。
Stateは小さくなるが、全層分のAction履歴を別途保存するため、全体のメモリ削減を保証するものではない。

幅2816でも変更前後の100入力を公式再生し、全出力一致・100/100通過、平均スコア7,920.61。
そのうち20入力を交互に3回ずつ測定した探索時間は1.8477→1.8489秒。
時間比率の95%信頼区間は0.9911〜1.0101で、明確な速度差は確認できなかった。
全140実行で、採用版の全体実行時間は平均1.887秒・最大2.148秒、2秒超過は11実行。
2秒以内を保証する幅ではない。別途10入力で測定したプロセス全体のピークWorking Setの
平均は71.64→93.36MiBで、履歴配列によるメモリ増加が大きくなる。

Actionだけを親のrefでつなぎ、選抜確定後だけ要素を生成する方式も別途比較した。
幅2816・20入力×3回の探索時間は、整数ID方式1.7636秒に対してref方式1.8616秒
（約5.55%増、時間比率の95%信頼区間1.0532〜1.0576）。
10入力でのピークWorking Set平均は93.36→71.16MiBへ減少した。
ref方式も公式再生100/100通過・全出力一致だったが、速度を優先し整数ID方式を維持した。
ref方式の試作・測定結果はローカルの検証用ディレクトリに保存する。
