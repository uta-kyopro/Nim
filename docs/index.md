# チートシート

- [Segment Tree](segtree.md)：1点更新・区間集約
- [Lazy Segment Tree](lazysegtree.md)：区間更新・区間集約（頻出6パターン）
- [Wavelet Matrix](wavelet_matrix.md)：静的配列の区間順位・個数・前後検索（自作・座標圧縮対応）
- [Range Query](range_query.md)：AOJ DSL_2_A〜Iの全操作と使い分け
- [Skip Beam Search](skip_beam.md)：regacyへ退避した差分更新ビームサーチ
- [Tour Beam Search](tour_beam.md)：経路配列を巡回する1ターン遷移専用の差分更新ビームサーチ（AHC073例）
- [Skip Tour Beam Search](skip_tour_beam.md)：ツアー配列で待機経路を保持する世代スキップ対応ビームサーチ（AHC021例）
- [Beam Search](beam_search.md)：regacyへ退避した通常のビームサーチ（AHC073例）
- [Simulated Annealing](simulated_annealing.md)：焼きなましの編集用テンプレートと順列ソートの例
- [外部ライブラリ](external_libraries.md)：bigints・bignum・regex・SATの使用例、再現した不具合と回避方法
- [128bit整数](int128.md)：C++のInt128・UInt128、入出力・型変換・debug時の検査
- [ビット盤面BFS](bitboard_bfs.md)：uint64・UInt128で行う4近傍・複数始点BFS

今後のビームサーチ改善対象はTour Beam Search・Skip Tour Beam Searchとする。
