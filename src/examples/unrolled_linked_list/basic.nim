include ../../lib/collections/unrolled_linked_list

# 挿入・削除・添字アクセスはO(N/B+B)、区間反転・全走査はO(N)。
# B=blockSize（通常は既定値256）。例ではブロック分割も起きるよう4に設定。
# capacityは事前確保の目安で、要素数の上限ではない。
var xs = initUnrolledLinkedList[int](blockSize = 4, capacity = 16)
for x in [10, 20, 30, 40, 50, 60, 70, 80, 90]:
    xs.addLast(x)

# 添字は0始まり。insert(pos, x)はposの直前へ挿入（pos=lenなら末尾）。
xs.addFirst(0)
xs.insert(2, 15)
echo toSeq(xs.items)     # @[0, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90]
echo xs.len             # 11
echo xs[3]              # 20
xs[3] = 25

# deleteは位置を指定し、削除した値を返す。後続の添字は詰まる。
let removed = xs.delete(2)
echo removed            # 15
doAssert toSeq(xs.items) == @[0, 10, 25, 30, 40, 50, 60, 70, 80, 90]

# reverse(l, r)は半開区間[l, r)の反転。rを含まない。
xs.reverse(1, 5)
echo toSeq(xs.items)     # @[0, 40, 30, 25, 10, 50, 60, 70, 80, 90]
doAssert xs[1] == 40
doAssert xs[4] == 10
xs.reverse(0, xs.len)    # 全体を反転
xs.reverse(2, 2)         # 空区間は何もしない
doAssert toSeq(xs.items) == @[90, 80, 70, 60, 50, 10, 25, 30, 40, 0]

# ArrayDequeと同じ両端操作。空でないことを確認してから使う。
if xs.len > 0:
    echo xs.peakFirst()       # 90（削除しない）
    echo xs.popFirst()        # 90（削除する）
if xs.len > 0:
    echo xs.peakLast()        # 0
    echo xs.popLast()         # 0
doAssert toSeq(xs.items) == @[80, 70, 60, 50, 10, 25, 30, 40]

xs.peakFirst() = 81         # 両端は直接書き換えられる
xs.peakLast() = 41
xs.shiftForward()          # 先頭を末尾へ移す
doAssert toSeq(xs.items) == @[70, 60, 50, 10, 25, 30, 41, 81]

xs.clear()
doAssert xs.len == 0
xs.addLast(7)            # clear後も再利用可能
doAssert xs[0] == 7
