include ../src/lib/itertools/product
include ../src/lib/itertools/combinations
include ../src/lib/itertools/combinations_with_replacement
include ../src/lib/itertools/permutations
include ../src/lib/dp/cumsum2d
include ../src/lib/collections/array_deque
include ../src/lib/collections/bitset
include ../src/lib/collections/bitpacking
include ../src/lib/collections/flat_seq_2d
include ../src/lib/collections/interval_heap
include ../src/lib/collections/implicit_treap
include ../src/lib/collections/unrolled_linked_list
include ../src/lib/math/miller_rabin
include ../src/lib/math/simd_rand

import std/unittest

static:
  doAssert not compiles(initArrayDeque[int](3))
  doAssert not compiles((block:
    var a = initBitSet(64)
    let b = initBitSet(65)
    a |= b
  ))

suite "itertools":
  test "product enumerates and handles empty domains":
    check toSeq(product(2, 2)) == @[@[0, 0], @[1, 0], @[0, 1], @[1, 1]]
    check toSeq(product(0, 2)).len == 0
    let emptyProduct = toSeq(product(3, 0))
    check emptyProduct.len == 1 and emptyProduct[0].len == 0
    check toSeq(product(3, -1)).len == 0

  test "combinations handles normal and boundary cases":
    check toSeq(combinations(4, 2)) ==
      @[@[0, 1], @[0, 2], @[0, 3], @[1, 2], @[1, 3], @[2, 3]]
    let emptyCombination = toSeq(combinations(4, 0))
    check emptyCombination.len == 1 and emptyCombination[0].len == 0
    check toSeq(combinations(2, 3)).len == 0
    check toSeq(combinations(-1, 0)).len == 0

  test "combinations with replacement handles boundaries":
    check toSeq(combinations_with_replacement(3, 2)) ==
      @[@[0, 0], @[0, 1], @[0, 2], @[1, 1], @[1, 2], @[2, 2]]
    let emptyCombination = toSeq(combinations_with_replacement(0, 0))
    check emptyCombination.len == 1 and emptyCombination[0].len == 0
    check toSeq(combinations_with_replacement(0, 2)).len == 0

  test "permutations are unique and complete":
    let values = toSeq(permutations(4, 2))
    check values.len == 12
    check values.toHashSet.len == 12
    let emptyPermutation = toSeq(permutations(3, 0))
    check emptyPermutation.len == 1 and emptyPermutation[0].len == 0
    check toSeq(permutations(2, 3)).len == 0

suite "collections":
  test "array deque supports both ends and wraparound":
    var q = initArrayDeque[int](8)
    q.addLast(2)
    q.addFirst(1)
    q.addLast(3)
    check q.len == 3
    check toSeq(q.items) == @[1, 2, 3]
    check q.peakFirst == 1
    check q.peakLast == 3
    check q.popFirst == 1
    check q.popLast == 3
    q.clear()
    for i in 0..<6: q.addLast(i)
    for i in 0..<4: check q.popFirst == i
    for i in 6..<10: q.addLast(i)
    check toSeq(q.items) == @[4, 5, 6, 7, 8, 9]

  test "array deque checks overflow and underflow in debug builds":
    var q = initArrayDeque[int](4)
    check q.data.len - 1 == 3
    expect AssertionDefect:
      discard q.popFirst()
    q.addLast(1)
    q.addLast(2)
    q.addLast(3)
    expect AssertionDefect:
      q.addLast(4)

  test "bitset masks unused bits and crosses old size limit":
    var zero = initBitSet(2001)
    zero[0] = 1
    zero[64] = 1
    zero[2000] = 1
    check zero[0] and zero[64] and zero[2000]
    check zero.popCount == 3
    var ones = initBitSet1(65)
    check ones.popCount == 65
    ones[64] = 0
    check ones.popCount == 64
    var other = initBitSet(65)
    other[64] = 1
    ones |= other
    check ones.popCount == 65

  test "bit packing reads, overwrites and masks fields":
    var x = 0'u64
    x[0, 5] = 31
    x[1, 5] = 17
    check x[0, 5] == 31
    check x[1, 5] == 17
    x[0, 5] = 40
    check x[0, 5] == 8
    check x[1, 5] == 17

  test "flat 2d sequence indexes rows and columns":
    var a = initFlatSeq2D[int](2, 3)
    for i in 0..<2:
      for j in 0..<3:
        a[i, j] = i * 10 + j
    check toSeq(a.getRow(1)) == @[10, 11, 12]
    check toSeq(a.getCol(2)) == @[2, 12]
    check a.len == 6

  test "flat 2d sequence rejects invalid shapes in debug builds":
    expect AssertionDefect:
      discard initFlatSeq2D[int](@[], 0)
    expect AssertionDefect:
      discard initFlatSeq2D[int](@[1, 2, 3], 2)

  test "interval heap matches a sorted reference":
    var rng = initRand(20260711)
    var heap = initIntervalHeap[int]()
    var reference: seq[int]
    for _ in 0..<3000:
      let action = rng.rand(4)
      if reference.len == 0 or action == 0:
        let value = rng.rand(-1000..1000)
        heap.push(value)
        reference.add(value)
        reference.sort()
      elif action == 1:
        check heap.pop_min == reference[0]
        reference.delete(0)
      elif action == 2:
        check heap.pop_max == reference[^1]
        reference.setLen(reference.len - 1)
      elif action == 3:
        let value = rng.rand(-1000..1000)
        check heap.replace_min(value) == reference[0]
        reference.delete(0)
        reference.add(value)
        reference.sort()
      else:
        let value = rng.rand(-1000..1000)
        check heap.replace_max(value) == reference[^1]
        reference.setLen(reference.len - 1)
        reference.add(value)
        reference.sort()
      check heap.empty == (reference.len == 0)
      if reference.len > 0:
        check heap.get_min == reference[0]
        check heap.get_max == reference[^1]

  test "interval heap replacements return the removed endpoint":
    var heap = initIntervalHeap(@[1, 3, 5, 7, 9])
    check heap.get_min == 1
    check heap.get_max == 9
    check heap.replace_min(4) == 1
    check heap.get_min == 3
    check heap.get_max == 9
    check heap.replace_max(6) == 9
    check heap.get_min == 3
    check heap.get_max == 7
    var values: seq[int]
    while not heap.empty:
      values.add(heap.pop_min())
    check values == @[3, 4, 5, 6, 7]

  test "implicit treap supports sequence operations":
    var treap = initImplicitTreap[int](16, 123)
    for value in 0..<6:
      treap.addLast(value)
    treap.addFirst(-1)
    treap.insert(3, 99)
    check toSeq(treap.items) == @[-1, 0, 1, 99, 2, 3, 4, 5]
    check treap.delete(3) == 99
    treap.reverse(1, 6)
    check toSeq(treap.items) == @[-1, 4, 3, 2, 1, 0, 5]
    check treap[2] == 3
    treap[2] = 30
    check toSeq(treap.items) == @[-1, 4, 30, 2, 1, 0, 5]

  test "implicit treap matches seq under random operations":
    var rng = initRand(314159)
    var treap = initImplicitTreap[int](256, 271828)
    var reference: seq[int]
    for _ in 0..<5000:
      let action = if reference.len == 0: 0 else: rng.rand(3)
      case action
      of 0:
        let pos = rng.rand(0..reference.len)
        let value = rng.rand(-1000..1000)
        treap.insert(pos, value)
        reference.insert(value, pos)
      of 1:
        let pos = rng.rand(0..<reference.len)
        check treap.delete(pos) == reference[pos]
        reference.delete(pos)
      of 2:
        let pos = rng.rand(0..<reference.len)
        let value = rng.rand(-1000..1000)
        treap[pos] = value
        reference[pos] = value
      else:
        let first = rng.rand(0..reference.len)
        let last = rng.rand(first..reference.len)
        treap.reverse(first, last)
        if first < last:
          reverse(reference, first, last - 1)
      check treap.len == reference.len
      check toSeq(treap.items) == reference

  test "unrolled linked list supports sequence operations":
    var list = initUnrolledLinkedList[int](blockSize = 4, capacity = 16)
    for value in 0..<10:
      list.addLast(value)
    list.addFirst(-1)
    list.insert(4, 99)
    check list.delete(4) == 99
    list.reverse(2, 9)
    check toSeq(list.items) == @[-1, 0, 7, 6, 5, 4, 3, 2, 1, 8, 9]
    check list[3] == 6
    list[3] = 60
    check list[3] == 60

  test "unrolled linked list matches seq under random operations":
    var rng = initRand(1618033)
    var list = initUnrolledLinkedList[int](blockSize = 8, capacity = 256)
    var reference: seq[int]
    for _ in 0..<5000:
      let action = if reference.len == 0: 0 else: rng.rand(3)
      case action
      of 0:
        let pos = rng.rand(0..reference.len)
        let value = rng.rand(-1000..1000)
        list.insert(pos, value)
        reference.insert(value, pos)
      of 1:
        let pos = rng.rand(0..<reference.len)
        check list.delete(pos) == reference[pos]
        reference.delete(pos)
      of 2:
        let pos = rng.rand(0..<reference.len)
        let value = rng.rand(-1000..1000)
        list[pos] = value
        reference[pos] = value
      else:
        let first = rng.rand(0..reference.len)
        let last = rng.rand(first..reference.len)
        list.reverse(first, last)
        if first < last:
          reverse(reference, first, last - 1)
      check list.len == reference.len
      check toSeq(list.items) == reference

suite "dp and math":
  test "2d cumulative sum answers half-open rectangles":
    var data = @[
      @[0, 0, 0, 0],
      @[0, 1, 2, 3],
      @[0, 4, 5, 6],
      @[0, 7, 8, 9]
    ]
    data.cumsum()
    check data.getRangeSum((0, 0), (3, 3)) == 45
    check data.getRangeSum((1, 1), (3, 3)) == 28
    check data.getRangeSum((3, 3), (1, 1)) == 28

  test "Miller-Rabin recognizes representative values":
    for p in [2, 3, 5, 37, 97, 1_000_000_007, 2_305_843_009_213_693_951]:
      check p.isPrime
    for n in [-1, 0, 1, 4, 9, 49, 341, 561, 1_000_000_005]:
      check not n.isPrime

  test "SIMD random generator is deterministic and bounded":
    var a = initSimdRng(123)
    var b = initSimdRng(123)
    for _ in 0..<1000:
      let x = a.rand(10)
      check x == b.rand(10)
      check x in 0..10
    check a.rand(0) == 0

suite "header helpers":
  test "memoized supports arguments and cache reset":
    var calls = 0
    proc twice(x: int): int {.memoized.} =
      calls.inc
      x * 2
    check twice(7) == 14
    check twice(7) == 14
    check calls == 1
    resetCacheTwice()
    check twice(7) == 14
    check calls == 2
