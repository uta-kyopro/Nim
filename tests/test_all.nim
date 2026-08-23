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
include ../src/lib/collections/object_pool
include ../src/lib/collections/persistent_stack
include ../src/lib/collections/sorted_containers
include ../src/lib/collections/stack
include ../src/lib/collections/trie
include ../src/lib/tree/kd_tree
include ../src/lib/flow/min_cost_flow_heap
include ../src/lib/flow/min_cost_flow_dense
include ../src/lib/flow/min_cost_flow_bellman_ford
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
    expect AssertionDefect:
      q.shiftForward()
    q.addLast(1)
    q.addLast(2)
    q.addLast(3)
    expect AssertionDefect:
      q.addLast(4)

  test "array deque shifts forward":
    var q = initArrayDeque[int](8)
    q.addLast(1)
    q.addLast(2)
    q.addLast(3)
    q.shiftForward()
    check toSeq(q.items) == @[2, 3, 1]

  test "array deque shifts forward after wraparound":
    var q = initArrayDeque[int](8)
    for i in 0..<6: q.addLast(i)
    for i in 0..<4: discard q.popFirst()
    for i in 6..<10: q.addLast(i)
    q.shiftForward()
    check toSeq(q.items) == @[5, 6, 7, 8, 9, 4]

  test "fixed stack supports seq-like operations":
    var stack = initStack[8, int]()
    stack.add(1)
    stack.push(2)
    stack[^1] = 3
    var value = 4
    stack.swap_add(value)
    check value == 0
    check stack.len == 3
    check stack[0] == 1
    check stack[^1] == 4
    check toSeq(stack.items) == @[1, 3, 4]
    check stack.pop() == 4
    stack.clear()
    check stack.len == 0

  test "persistent stack preserves branched versions":
    let empty = initPersistentStack[int]()
    let base = empty.push(1)
    let left = base.push(2)
    let right = base.emplace(3)
    check empty.isEmpty
    check base.top == 1
    check left.top == 2
    check right.top == 3
    check left.get(1) == 1
    check left.getAll() == @[2, 1]
    check right.getAll() == @[3, 1]
    check left.pop().getAll() == @[1]

  test "persistent stack checks invalid access in debug builds":
    let empty = initPersistentStack[int]()
    expect AssertionDefect:
      discard empty.top
    expect AssertionDefect:
      discard empty.pop()
    expect AssertionDefect:
      discard empty.get(0)

  test "trie searches prefixes and lexicographic endpoints":
    var trie = initTrie()
    trie.insert("ab")
    trie.insert("a")
    trie.insert("abc")
    trie.insert("B")
    check trie.search("a")
    check trie.search("abc")
    check not trie.search("ac")
    check trie.startsWith("ab")
    check not trie.startsWith("ba")
    check trie.getMinString() == "B"
    check trie.getMaxString() == "abc"
    check trie.totalCount == 4
    check trie.nodeCount == 4

  test "trie optionally rejects duplicate words":
    var trie = initTrie()
    check trie.insert("word", duplicate = false)
    check not trie.insert("word", duplicate = false)
    check trie.totalCount == 1
    trie.insert("word")
    check trie.totalCount == 2

  test "trie checks endpoints when empty in debug builds":
    let trie = initTrie()
    expect AssertionDefect:
      discard trie.getMinString()
    expect AssertionDefect:
      discard trie.getMaxString()

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

  test "object pool reuses released indices":
    type PoolValue = object
      id: int
      payload: string
    var pool = initObjectPool[PoolValue](8)
    pool.reserve(32)
    check pool.size == 0
    let a = pool.push(PoolValue(id: 1, payload: "a"))
    let b = pool.push(PoolValue(id: 2, payload: "b"))
    let c = pool.push(PoolValue(id: 3, payload: "c"))
    check (a, b, c) == (0, 1, 2)
    pool.pop(b)
    check pool.len == 2
    check pool.available == 1
    let reused = pool.push(PoolValue(id: 4, payload: "reused"))
    check reused == b
    check pool[reused].payload == "reused"
    pool[reused].id = 40
    check pool[reused].id == 40
    check pool.size == 3
    expect AssertionDefect:
      pool.pop(7)
    pool.pop(reused)
    expect AssertionDefect:
      pool.pop(reused)

  test "sorted set matches an ordered unique sequence":
    var rng = initRand(1001)
    var sortedSet = initSortedSet[int](8)
    var reference: seq[int]
    for _ in 0..<5000:
      let value = rng.rand(-100..100)
      if rng.rand(1) == 0:
        let expected = value notin reference
        check sortedSet.incl(value) == expected
        if expected: reference.add(value); reference.sort()
      else:
        let index = reference.find(value)
        check sortedSet.excl(value) == (index >= 0)
        if index >= 0: reference.delete(index)
      check toSeq(sortedSet.items) == reference
      check sortedSet.lowerBound(value) == reference.lowerBoundLocal(value)
      check sortedSet.upperBound(value) == reference.upperBoundLocal(value)

  test "sorted multiset matches a sorted sequence":
    var rng = initRand(1002)
    var multi = initSortedMultiSet[int](8)
    var reference: seq[int]
    for _ in 0..<5000:
      let value = rng.rand(-30..30)
      if rng.rand(2) > 0:
        multi.add(value)
        reference.add(value); reference.sort()
      else:
        let index = reference.find(value)
        check multi.remove(value) == (index >= 0)
        if index >= 0: reference.delete(index)
      check toSeq(multi.items) == reference
      check multi.count(value) == reference.count(value)
      if reference.len > 0:
        let index = rng.rand(0..<reference.len)
        check multi[index] == reference[index]

  test "sorted dict preserves key order":
    var rng = initRand(1003)
    var dict = initSortedDict[int, int](8)
    var reference = initTable[int, int]()
    for _ in 0..<3000:
      let key = rng.rand(-100..100)
      if rng.rand(2) > 0:
        let value = rng.rand(-1000..1000)
        dict[key] = value
        reference[key] = value
      else:
        check dict.del(key) == reference.hasKey(key)
        reference.del(key)
      let expectedKeys = reference.keys.toSeq.sorted()
      check toSeq(dict.keys) == expectedKeys
      check toSeq(dict.pairs) == expectedKeys.mapIt((it, reference[it]))

suite "tree":
  test "KD-tree finds nearest, k-nearest, radius and range":
    let points = @[
      [0, 0], [5, 0], [2, 2], [-1, 3], [8, 8], [2, 2]
    ]
    let tree = initKdTree(points)
    check tree.len == points.len
    check tree.nearest([2, 1]).index == 2
    check tree.kNearest([2, 1], 3).mapIt(it.index) == @[2, 5, 0]
    check tree.radiusSearch([0, 0], 3).mapIt(it.index) == @[0, 2, 5]
    check tree.rangeSearch([-1, 0], [2, 3]) == @[0, 2, 3, 5]

  test "KD-tree matches brute force on random points":
    var rng = initRand(424242)
    var points = newSeq[array[3, int]](300)
    for point in points.mitems:
      for axis in 0..<3:
        point[axis] = rng.rand(-100..100)
    let tree = initKdTree(points)
    for _ in 0..<500:
      var query: array[3, int]
      for axis in 0..<3:
        query[axis] = rng.rand(-120..120)
      var brute = (0..<points.len).toSeq().mapIt(
        (index: it, distanceSquared: squaredDistance(points[it], query)))
      brute.sort(proc(a, b: KdNeighbor): int =
        result = cmp(a.distanceSquared, b.distanceSquared)
        if result == 0: result = cmp(a.index, b.index))
      check tree.nearest(query) == brute[0]
      check tree.kNearest(query, 10) == brute[0..<10]
      let radius = rng.rand(0..50)
      check tree.radiusSearch(query, radius) ==
        brute.filterIt(it.distanceSquared <= float64(radius * radius))

suite "flow":
  test "min-cost-flow variants agree on a known graph":
    template build(graph: untyped) =
      graph.addEdge(0, 1, 2, 1)
      graph.addEdge(0, 2, 1, 4)
      graph.addEdge(1, 2, 1, -2)
      graph.addEdge(1, 3, 1, 3)
      graph.addEdge(2, 3, 2, 1)
    var heap = initMinCostFlowHeap(4)
    var dense = initMinCostFlowDense(4)
    var bellman = initMinCostFlowBellmanFord(4)
    build(heap); build(dense); build(bellman)
    check heap.flow(0, 3, 3) == (flow: 3'i64, cost: 9'i64)
    check dense.flow(0, 3, 3) == (flow: 3'i64, cost: 9'i64)
    check bellman.flow(0, 3, 3) == (flow: 3'i64, cost: 9'i64)
    check heap.edges.mapIt(it.flow) == @[2'i64, 1, 1, 1, 2]

  test "min-cost-flow implementations match on random DAGs":
    var rng = initRand(987654)
    for _ in 0..<300:
      let nodeCount = rng.rand(2..9)
      var heap = initMinCostFlowHeap(nodeCount)
      var dense = initMinCostFlowDense(nodeCount)
      var bellman = initMinCostFlowBellmanFord(nodeCount)
      for src in 0..<nodeCount:
        for dst in src+1..<nodeCount:
          if rng.rand(3) == 0:
            let capacity = int64(rng.rand(1..4))
            let cost = int64(rng.rand(-5..10))
            discard heap.addEdge(src, dst, capacity, cost)
            discard dense.addEdge(src, dst, capacity, cost)
            discard bellman.addEdge(src, dst, capacity, cost)
      let limit = int64(rng.rand(0..10))
      let expected = bellman.flow(0, nodeCount-1, limit)
      check heap.flow(0, nodeCount-1, limit) == expected
      check dense.flow(0, nodeCount-1, limit) == expected

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
