# 更新なしの配列に対する区間順位・個数検索。
import ../../lib/range_query/wavelet_matrix

let a = @[-1, 1000000000, -5, -1, 7]
let wm = initCompressedStaticWaveletMatrix(a)
let l = 0
let r = a.len

echo wm.kth_smallest(l..<r, 1)  # -1
echo wm.kth_largest(l..<r, 0)   # 1000000000
echo wm.range_freq(l..<r, -1, 8) # 3（-1, -1, 7）
echo wm.rank(-1, r) - wm.rank(-1, l) # 2
echo wm.rank(123, r)            # 0（存在しない値）

# x+1を使わずに「以下・より大きい・以上」の個数を求める。
let x = -1
let less = wm.range_freq(l..<r, x)
let equal = wm.rank(x, r) - wm.rank(x, l)
echo less + equal              # 3（x以下）
echo (r - l) - less - equal     # 2（xより大きい）
echo (r - l) - less             # 4（x以上）

# Optionなので実データの-1と「該当なし」を区別できる。
let previous = wm.prev_value(l..<r, 0)
if previous.isSome:
    echo previous.get           # -1（0未満の最大）
let following = wm.next_value(l..<r, 0)
if following.isSome:
    echo following.get          # 7（0以上の最小）
doAssert wm.prev_value(l..<r, -5).isNone
doAssert previous == some(-1)
doAssert wm[0] == -1

doAssert wm.kth_smallest(l..<r, 1) == -1
doAssert wm.range_freq(l..<r, -1, 8) == 3
doAssert wm.rank(-1, r) - wm.rank(-1, l) == 2
doAssert wm.range_freq(l..<r, int.high) == a.len
