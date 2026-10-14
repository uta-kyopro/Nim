# 外部Nimライブラリの使用例

例は [src/examples/external/](../src/examples/external/) に配置している。各ファイルは共通headerをincludeせず、必要な外部パッケージだけをimportする。

## 対象とインストール

| パッケージ | 検証した版 | 用途 | 使用例 |
|---|---|---|---|
| `bigints` | 1.1.0 | Pure Nimの多倍長整数 `BigInt` | [整数・累乗・GCD・mod累乗・整数変換](../src/examples/external/bigints_basic.nim) |
| `bignum` | 1.0.6 | GMPを使う多倍長整数 `Int`・有理数 `Rat` | [整数・分数・参照とclone](../src/examples/external/bignum_basic.nim) |
| `regex` | 0.26.3 | Pure Nimの正規表現 | [一致判定・数値の抽出](../src/examples/external/regex_basic.nim) |
| `sat` | 0.1.0 | 一般のSATソルバー | [充足可能・充足不能・解の確認](../src/examples/external/sat_basic.nim) |

`bigint`はここでは型名`BigInt`を指す。インストール・importする名前は複数形の **`bigints`**。`std/jsbigints`はJavaScript向けの別モジュール。

```sh
nimble install bigints@1.1.0 bignum@1.0.6 gmp@0.2.7 regex@0.26.3 sat@0.1.0
nim cpp -r -d:release --outdir:build/examples src/examples/external/bigints_basic.nim
nim cpp -r -d:release --outdir:build/examples src/examples/external/bignum_basic.nim
nim cpp -r -d:release --outdir:build/examples src/examples/external/regex_basic.nim
nim cpp -r -d:release --outdir:build/examples src/examples/external/sat_basic.nim
```

これらは検証対象を再現するための版指定であり、最新版であるという意味ではない。外部ライブラリは本リポジトリには同梱しない。

`bignum`にはGMPの実行ライブラリも必要。検証環境の`gmp 0.2.7`はWindowsで **`libgmp.dll`** を要求したが、インストール済みのDLLは`libgmp-10.dll`だった。適合するGMP DLLを実行ファイルと同じフォルダに`libgmp.dll`という名前で置いて検証した。これはDLL名の不一致であり、計算バグとは区別する。

この環境では旧`pkgs/gmp-0.2.5`が自動選択され、Nim 2.2.4で`invalid indentation`となった。新しい版が入っていても、重複インストールにより古い版が選択される場合がある。下の検証スクリプトは、指定した各版を`--path`で明示する。手動でも`--path:<bignumのフォルダ> --path:<gmpのフォルダ>`を追加すればよい。

## 多倍長整数の使い分け

巨大な十進数は`initBigInt("...")`または`newInt("...")`で作る。先に通常の`int`で演算してから変換すると、その時点で桁あふれしてしまう。

| 式 | Nimの`int` / `bignum.Int` | `bigints.BigInt` |
|---|---|---|
| `-7 div 3` | -2（ゼロ方向） | -3（床方向） |
| `-7 mod 3` | -1 | 2 |

この負数の丸めの違いは仕様。`bigints`でゼロ方向の除算が必要なら、絶対値同士を除算して商の符号を戻し、余りを`a - q*b`で求める。[BigInts公式API](https://nim-lang.github.io/bigints/)

`bigints.toInt[T]`は`Option[T]`を返すので、`isSome`を確認してから`get`する。`bignum.toInt`は`fitsInt`を確認してから呼ぶ。

`bignum.Int`・`Rat`は参照型。代入で同じ数を共有し、`*=`や`set`などで共有先も変わる。独立した値が必要なら`clone()`を使う。大量の計算におけるメモリ解放動作・速度は今回の検証範囲外。

## 再現した不具合

### bigints 1.1.0：一部の大整数除算

Nim 2.2.4 / Windows amd64で以下を実行すると、debug・releaseとも`q1 <= uint32.high`の`AssertionDefect`になった。

```nim
import bigints
let a = initBigInt("6277101735386680763835789123314955362437298222279840143829")
let b = initBigInt("1461501637330902918203684832716283019655932313743")
echo a div b # 期待値: 4294967295
```

[上流Issue #123](https://github.com/nim-lang/bigints/issues/123)と同じ入力。上流Issue自体は修正PR #151により閉じられているが、**今回インストールされている1.1.0では再現した**。上流修正版・別バージョンの動作は未検証。ランダム検証の成功だけで、この版の大整数除算全般を安全とは判断できない。

この入力については`bignum`を使い、文字列から構築した場合に正しい商・余りを確認できた。assertを無効化することは修正にならない。

### bignum 1.0.6：Windowsで大きなintから構築

同じ環境で`newInt(4294967296)`、`newInt(1099511627776)`、負の2^40、`int64`の最小・最大値からの構築がSIGSEGVになった。debug・releaseで再現。小さい値からの構築は成功した。

```nim
import bignum
# Windowsの検証環境でクラッシュした経路:
# echo newInt(4294967296)
echo newInt("4294967296") # こちらは正常
```

ローカルソースではWindowsのLLP64用分岐が、`mpz_init`直後にlimbの格納領域へ直接書き込んでいる。不具合の原因と考えられるが、外部ライブラリは修正していない。大きい通常整数から作るときは **`newInt($value)`** とし、演算の大きい`int`引数も`Int`へ文字列経由で変換する。Linux/macOSでこの不具合が起こるかは未検証。

## 検証と再実行

Nim 2.2.4 / Windows amd64、debug・releaseの両方で次を実行した。

- 4使用例：各モードすべて成功。
- Pythonの任意精度整数との比較：各ライブラリ・各モード120組。加減乗除・余り・GCDすべて成功。負数の丸めはライブラリごとに期待値を変更。
- Issue #123の入力：bigintsは両モード失敗、bignumは両モード成功。
- 通常整数8値からの構築：bigintsは8/8成功、bignumは3/8成功。

上記は検証した範囲の記録であり、未検証APIに不具合がないことは保証しない。再現用のスクリプトは残し、検証JSONはGit管理しない。通常の実行ではJSONを生成しない。

```sh
python tests/check_external_libraries.py
```

WindowsでDLL名の調整が必要なら、上のコマンドへ`--gmp-dll <適合するGMP DLLの絶対パス>`を追加する。スクリプトはそのDLLを一時的にコピーし、既存パッケージやDLLを変更しない。生成物は`build/external_examples/run-*`に作り、終了時に削除する。不具合を検出した場合の終了コードは1。

手元の診断用JSONが必要な場合だけ`--report build/external_examples_report.json`を追加する。JSONにはエラーログ由来のユーザー名・絶対パスが含まれ得るため、Git管理外の`build/`に保存する。旧出力先の`docs/external_libraries_validation.json`も`.gitignore`で除外している。

SATソルバーの探索上限超過は`SatOverflowError`になり、充足不能とは別に扱う。`regex`は`std/re`とはAPIが異なり、例の`group(0)`は最初の括弧による捕捉を指す。

上流: [bigints](https://github.com/nim-lang/bigints)、[bignum](https://github.com/chaemon/bignum)、[regex](https://github.com/nitely/nim-regex)、[sat](https://github.com/nim-lang/sat)。
