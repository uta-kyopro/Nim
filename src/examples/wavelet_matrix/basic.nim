# 更新なしの配列に対する区間順位・個数検索。
import ../../lib/range_query/wavelet_matrix

let a = @[1, 5, 2, 4, 3, 2]
let wm = initStaticWaveletMatrix(a)
let l = 1
let r = 6                      # 対象: [5, 2, 4, 3, 2]

echo wm.kth_smallest(l..<r, 0)  # 2（最小）
echo wm.kth_largest(l..<r, 0)   # 5（最大）
echo wm.kth_smallest(l..<r, 2)  # 3（小さい方から3番目）
echo wm.kth_smallest(l..<r, (r-l-1) div 2) # 3（中央値）

echo wm.range_freq(l..<r, 3)    # 2（3未満）
echo wm.range_freq(l..<r, 2, 4) # 3（2以上4未満）
echo wm.rank(2, r) - wm.rank(2, l) # 2（2と等しい）

echo wm.prev_value(l..<r, 4)    # some(3)（4未満の最大）
echo wm.next_value(l..<r, 4)    # some(4)（4以上の最小）
echo wm.prev_value(l..<r, 2)    # none(int)（該当なし）
echo wm.next_value(l..<r, 6)    # none(int)（該当なし）

doAssert wm.kth_smallest(l..<r, 2) == 3
doAssert wm.range_freq(l..<r, 2, 4) == 3
doAssert wm.rank(2, r) - wm.rank(2, l) == 2
doAssert wm.range_freq(2..<2, 3) == 0 # 空区間の個数は0
# kth_* は空区間では呼べない。元の値の取得は a[i] を使う。
doAssert wm.access(1) == 5
