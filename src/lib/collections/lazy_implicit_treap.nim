# 可変長列の区間集約・遅延作用・反転。各操作は期待 O(log n)。
# mapping(f, x, count) は count 要素の集約値 x に f を適用する。
# composition(f, g) は g のあと f。作用は反転と可換であること。
{.push checks:off.}
when defined(debug):
    {.push checks:on, assertions:on.}

type
    LazyImplicitTreapNode[S, F] = object
        value, forward, backward: S
        left, right, size: int
        priority: uint32
        reversed, hasLazy: bool
        lazy: F

    LazyImplicitTreap*[S, F] = object
        nodes: seq[LazyImplicitTreapNode[S, F]]
        freeList: seq[int]
        root: int
        rngState: uint64
        op: proc(a, b: S): S {.closure.}
        identity: S
        mapping: proc(f: F, x: S, count: int): S {.closure.}
        composition: proc(f, g: F): F {.closure.}

proc initLazyImplicitTreap*[S, F](
    op: proc(a, b: S): S {.closure.}, e: S,
    mapping: proc(f: F, x: S, count: int): S {.closure.},
    composition: proc(f, g: F): F {.closure.},
    capacity: Natural = 0,
    seed: uint64 = 0x9E3779B97F4A7C15'u64): LazyImplicitTreap[S, F] =
    result.root = -1
    result.rngState = if seed == 0: 0x9E3779B97F4A7C15'u64 else: seed
    result.nodes = newSeqOfCap[LazyImplicitTreapNode[S, F]](capacity)
    result.op = op
    result.identity = e
    result.mapping = mapping
    result.composition = composition

proc nodeSize[S, F](self: LazyImplicitTreap[S, F], node: int): int =
    if node < 0: 0 else: self.nodes[node].size

proc len*[S, F](self: LazyImplicitTreap[S, F]): int =
    self.nodeSize(self.root)

proc aggregate[S, F](self: LazyImplicitTreap[S, F], node: int,
    backward = false): S =
    if node < 0: self.identity
    elif backward: self.nodes[node].backward
    else: self.nodes[node].forward

proc allProd*[S, F](self: LazyImplicitTreap[S, F]): S =
    self.aggregate(self.root)

proc nextPriority[S, F](self: var LazyImplicitTreap[S, F]): uint32 =
    var x = self.rngState
    x = x xor (x shr 12)
    x = x xor (x shl 25)
    x = x xor (x shr 27)
    self.rngState = x
    cast[uint32]((x * 0x2545F4914F6CDD1D'u64) shr 32)

proc newNode[S, F](self: var LazyImplicitTreap[S, F], value: S): int =
    let node = LazyImplicitTreapNode[S, F](value: value,
        forward: value, backward: value, left: -1, right: -1,
        size: 1, priority: self.nextPriority())
    if self.freeList.len > 0:
        result = self.freeList.pop()
        self.nodes[result] = node
    else:
        result = self.nodes.len
        self.nodes.add(node)

proc update[S, F](self: var LazyImplicitTreap[S, F], node: int) =
    let l = self.nodes[node].left
    let r = self.nodes[node].right
    self.nodes[node].size = 1 + self.nodeSize(l) + self.nodeSize(r)
    self.nodes[node].forward = self.op(
        self.op(self.aggregate(l), self.nodes[node].value), self.aggregate(r))
    self.nodes[node].backward = self.op(
        self.op(self.aggregate(r, true), self.nodes[node].value),
        self.aggregate(l, true))

proc applyNode[S, F](self: var LazyImplicitTreap[S, F], node: int, f: F) =
    if node < 0: return
    self.nodes[node].value = self.mapping(f, self.nodes[node].value, 1)
    let count = self.nodes[node].size
    self.nodes[node].forward = self.mapping(f, self.nodes[node].forward, count)
    self.nodes[node].backward = self.mapping(f, self.nodes[node].backward, count)
    self.nodes[node].lazy = if self.nodes[node].hasLazy:
        self.composition(f, self.nodes[node].lazy)
    else: f
    self.nodes[node].hasLazy = true

proc toggleReverse[S, F](self: var LazyImplicitTreap[S, F], node: int) =
    if node < 0: return
    swap(self.nodes[node].left, self.nodes[node].right)
    swap(self.nodes[node].forward, self.nodes[node].backward)
    self.nodes[node].reversed = not self.nodes[node].reversed

proc push[S, F](self: var LazyImplicitTreap[S, F], node: int) =
    if self.nodes[node].hasLazy:
        let f = self.nodes[node].lazy
        self.applyNode(self.nodes[node].left, f)
        self.applyNode(self.nodes[node].right, f)
        self.nodes[node].hasLazy = false
    if self.nodes[node].reversed:
        self.toggleReverse(self.nodes[node].left)
        self.toggleReverse(self.nodes[node].right)
        self.nodes[node].reversed = false

proc merge[S, F](self: var LazyImplicitTreap[S, F], left, right: int): int =
    if left < 0: return right
    if right < 0: return left
    if self.nodes[left].priority >= self.nodes[right].priority:
        self.push(left)
        self.nodes[left].right = self.merge(self.nodes[left].right, right)
        self.update(left)
        result = left
    else:
        self.push(right)
        self.nodes[right].left = self.merge(left, self.nodes[right].left)
        self.update(right)
        result = right

proc split[S, F](self: var LazyImplicitTreap[S, F], root, count: int): (int, int) =
    if root < 0: return (-1, -1)
    self.push(root)
    let leftSize = self.nodeSize(self.nodes[root].left)
    if count <= leftSize:
        let (left, middle) = self.split(self.nodes[root].left, count)
        self.nodes[root].left = middle
        self.update(root)
        result = (left, root)
    else:
        let (middle, right) = self.split(self.nodes[root].right,
            count - leftSize - 1)
        self.nodes[root].right = middle
        self.update(root)
        result = (root, right)

proc checkRange[S, F](self: LazyImplicitTreap[S, F], first, last: int) =
    when defined(debug):
        assert 0 <= first and first <= last and last <= self.len,
            "LazyImplicitTreap range is out of bounds"

proc insert*[S, F](self: var LazyImplicitTreap[S, F], pos: int, value: S) =
    when defined(debug):
        assert 0 <= pos and pos <= self.len
    let (left, right) = self.split(self.root, pos)
    let node = self.newNode(value)
    self.root = self.merge(self.merge(left, node), right)

proc add*[S, F](self: var LazyImplicitTreap[S, F], value: S) =
    self.insert(self.len, value)

proc `[]`*[S, F](self: var LazyImplicitTreap[S, F], pos: int): S =
    when defined(debug):
        assert 0 <= pos and pos < self.len
    var node = self.root
    var index = pos
    while true:
        self.push(node)
        let ls = self.nodeSize(self.nodes[node].left)
        if index < ls:
            node = self.nodes[node].left
        elif index == ls:
            return self.nodes[node].value
        else:
            index -= ls + 1
            node = self.nodes[node].right

proc `[]=`*[S, F](self: var LazyImplicitTreap[S, F], pos: int, value: S) =
    when defined(debug):
        assert 0 <= pos and pos < self.len
    let (left, rest) = self.split(self.root, pos)
    let (node, right) = self.split(rest, 1)
    self.nodes[node].value = value
    self.update(node)
    self.root = self.merge(self.merge(left, node), right)

proc delete*[S, F](self: var LazyImplicitTreap[S, F], pos: int): S {.discardable.} =
    when defined(debug):
        assert 0 <= pos and pos < self.len
    let (left, rest) = self.split(self.root, pos)
    let (node, right) = self.split(rest, 1)
    result = self.nodes[node].value
    self.nodes[node] = default(LazyImplicitTreapNode[S, F])
    self.freeList.add(node)
    self.root = self.merge(left, right)

proc prod*[S, F](self: var LazyImplicitTreap[S, F], first, last: int): S =
    self.checkRange(first, last)
    if first == last: return self.identity
    let (left, rest) = self.split(self.root, first)
    let (middle, right) = self.split(rest, last - first)
    result = self.aggregate(middle)
    self.root = self.merge(self.merge(left, middle), right)

proc apply*[S, F](self: var LazyImplicitTreap[S, F], first, last: int, f: F) =
    self.checkRange(first, last)
    if first == last: return
    let (left, rest) = self.split(self.root, first)
    let (middle, right) = self.split(rest, last - first)
    self.applyNode(middle, f)
    self.root = self.merge(self.merge(left, middle), right)

proc apply*[S, F](self: var LazyImplicitTreap[S, F], pos: int, f: F) =
    self.apply(pos, pos + 1, f)

proc reverse*[S, F](self: var LazyImplicitTreap[S, F], first, last: int) =
    self.checkRange(first, last)
    if first == last: return
    let (left, rest) = self.split(self.root, first)
    let (middle, right) = self.split(rest, last - first)
    self.toggleReverse(middle)
    self.root = self.merge(self.merge(left, middle), right)

proc rotate*[S, F](self: var LazyImplicitTreap[S, F], first, last, k: int) =
    self.checkRange(first, last)
    let count = last - first
    if count <= 1: return
    let shift = ((k mod count) + count) mod count
    if shift == 0: return
    let (left, rest) = self.split(self.root, first)
    let (middle, right) = self.split(rest, count)
    let (head, tail) = self.split(middle, shift)
    self.root = self.merge(self.merge(left, self.merge(tail, head)), right)

iterator items*[S, F](self: var LazyImplicitTreap[S, F]): S =
    var stack: seq[int]
    var node = self.root
    while node >= 0 or stack.len > 0:
        while node >= 0:
            self.push(node)
            stack.add(node)
            node = self.nodes[node].left
        node = stack.pop()
        yield self.nodes[node].value
        node = self.nodes[node].right

proc toSeq*[S, F](self: var LazyImplicitTreap[S, F]): seq[S] =
    result = newSeqOfCap[S](self.len)
    for x in self.items: result.add(x)

proc clear*[S, F](self: var LazyImplicitTreap[S, F]) =
    self.nodes.setLen(0)
    self.freeList.setLen(0)
    self.root = -1

when defined(debug):
    {.pop.}
{.pop.}
