# Nim競技プログラミングライブラリ

## ライセンス

作者が権利を持つコード・ドキュメントには **CC0 1.0 Universal** を適用します。商用・非商用を問わず、利用・改変・再配布できます。ライセンス本文は [LICENSE](LICENSE)、公式説明は [Creative Commons CC0](https://creativecommons.org/publicdomain/zero/1.0/) を参照してください。

依存する外部ライブラリや第三者が権利を持つ部分には、このCC0は適用されません。それぞれのライセンス・利用条件に従ってください。

## フォルダ構成

ローカル専用の `tests/`・生成物の `build/`・管理用ディレクトリは省略しています。

```text
.
└── src/
    ├── examples/                                 # ライブラリの使用例・実問題サンプル
    └── lib/
        ├── header.nim                              # 共通import、入出力、演算子、メモ化などの基本機能
        ├── collections/
        │   ├── array_deque.nim                    # 固定容量・2冪サイズの両端キュー
        │   ├── bitpacking.nim                     # 整数内の固定幅ビットフィールドの取得・更新
        │   ├── bitset.nim                         # uint64配列によるコンパイル時固定長StaticBitSet
        │   ├── flat_seq_2d.nim                    # 二次元データを連続領域に保持する可変長配列
        │   ├── implicit_treap.nim                 # 添字操作と区間反転に対応する暗黙Treap
        │   ├── lazy_implicit_treap.nim            # 区間集約・遅延作用・反転に対応する暗黙Treap
        │   ├── indexed_set.nim                    # O(1)の追加・削除・添字アクセスを持つ集合
        │   ├── interval_heap.nim                  # 最小値と最大値を取得・削除できる両端優先度付きキュー
        │   ├── object_pool.nim                    # 削除済みindexを再利用する整数index型オブジェクトプール
        │   ├── persistent_stack.nim               # 過去バージョンを共有して保持する永続Stack
        │   ├── sorted_containers.nim              # √分割によるSqrtSet・SqrtMultiSet・SqrtDict
        │   ├── stack.nim                          # arrayを内部領域に使う固定容量Stack
        │   ├── trie.nim                           # 文字列の完全一致・prefix検索に対応するTableTrie
        │   └── unrolled_linked_list.nim           # 小さな連続ブロック列で保持する可変長リスト
        ├── dp/
        │   └── cumsum2d.nim                       # 長方形領域和を求める二次元累積和
        ├── flow/
        │   ├── min_cost_flow_common.nim           # 最小費用流3実装で共有する型と残余グラフ操作
        │   ├── min_cost_flow_heap.nim             # Heap Primal-Dualによる疎グラフ向け最小費用流
        │   ├── min_cost_flow_dense.nim            # 全頂点走査Primal-Dualによる密グラフ向け最小費用流
        │   └── min_cost_flow_bellman_ford.nim     # 負辺に対応するBellman–Ford型最小費用流
        ├── itertools/
        │   ├── combinations.nim                   # 重複なし組合せの列挙
        │   ├── combinations_with_replacement.nim  # 重複組合せの列挙
        │   ├── permutations.nim                   # 順列・部分順列の列挙
        │   └── product.nim                        # 直積の列挙
        ├── math/
        │   ├── int128.nim                         # C++の符号付き・符号なし128bit整数、入出力・型変換
        │   ├── miller_rabin.nim                   # 64-bit整数向けMiller–Rabin素数判定
        │   └── simd_rand.nim                      # AVX2で8個ずつ生成するSIMD乱数生成器
        ├── range_query/
        │   └── wavelet_matrix.nim                 # 静的な区間順位・個数・前後検索、座標圧縮対応
        ├── tree/
        │   └── kd_tree.nim                        # 最近傍・k近傍・半径・直方体検索を行うKD-tree
        ├── search/
        │   ├── beam_search.nim                    # Stateをコピーする通常のビームサーチのテンプレート
        │   ├── beam_search_core.nim               # 2層のNode配列・Hash重複排除・セグ木選抜
        │   ├── simulated_annealing.nim            # 時間制限・温度更新・巻き戻しを備えた焼きなましのテンプレート
        │   ├── skip_beam.nim                      # 問題ごとの型・評価・遷移・展開を編集するテンプレート
        │   └── skip_beam_core.nim                 # 差分更新・複数ターン遷移対応の探索エンジン
        └── utils/
            └── timer.nim                          # 単調時計による経過時間・期限判定Timer
```
