
include ../header

# 配列上の位置をキーとして扱うImplicit Treap。
# ノードを連続したseqに保持し、GC管理の参照ノードを使わない。
# 計算量（期待値）: 挿入・削除・添字アクセス・区間反転は O(log n)、全走査・clear は O(n)。
when not declared ImplicitTreapModule:
    const ImplicitTreapModule = true

    type
        ImplicitTreapNode[T] = object
            value: T
            left, right: int
            size: int
            priority: uint32
            reversed: bool

        ImplicitTreap[T] = object
            nodes: seq[ImplicitTreapNode[T]]
            freeList: seq[int]
            root: int
            rngState: uint64

    proc initImplicitTreap[T](capacity: Natural = 0,
            seed: uint64 = 0x9E3779B97F4A7C15'u64): ImplicitTreap[T] =
        result.root = -1
        result.rngState = if seed == 0: 0x9E3779B97F4A7C15'u64 else: seed
        result.nodes = newSeqOfCap[ImplicitTreapNode[T]](capacity)
        result.freeList = newSeqOfCap[int](capacity)

    proc len[T](self: ImplicitTreap[T]): int {.inline.} =
        if self.root < 0: 0 else: self.nodes[self.root].size

    proc nodeSize[T](self: ImplicitTreap[T], node: int): int {.inline.} =
        if node < 0: 0 else: self.nodes[node].size

    proc nextPriority[T](self: var ImplicitTreap[T]): uint32 {.inline.} =
        # xorshift64*: priority生成にのみ使用する軽量PRNG。
        var x = self.rngState
        x = x xor (x shr 12)
        x = x xor (x shl 25)
        x = x xor (x shr 27)
        self.rngState = x
        result = cast[uint32]((x * 0x2545F4914F6CDD1D'u64) shr 32)

    proc newNode[T](self: var ImplicitTreap[T], value: sink T): int =
        if self.freeList.len > 0:
            result = self.freeList.pop()
            self.nodes[result] = ImplicitTreapNode[T](
                value: value, left: -1, right: -1, size: 1,
                priority: self.nextPriority())
        else:
            result = self.nodes.len
            self.nodes.add(ImplicitTreapNode[T](
                value: value, left: -1, right: -1, size: 1,
                priority: self.nextPriority()))

    proc update[T](self: var ImplicitTreap[T], node: int) {.inline.} =
        self.nodes[node].size = 1 + self.nodeSize(self.nodes[node].left) +
            self.nodeSize(self.nodes[node].right)

    proc toggleReverse[T](self: var ImplicitTreap[T], node: int) {.inline.} =
        if node >= 0:
            self.nodes[node].reversed = not self.nodes[node].reversed

    proc push[T](self: var ImplicitTreap[T], node: int) {.inline.} =
        if node >= 0 and self.nodes[node].reversed:
            swap(self.nodes[node].left, self.nodes[node].right)
            self.toggleReverse(self.nodes[node].left)
            self.toggleReverse(self.nodes[node].right)
            self.nodes[node].reversed = false

    proc merge[T](self: var ImplicitTreap[T], left, right: int): int =
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

    proc split[T](self: var ImplicitTreap[T], root, count: int): (int, int) =
        # 先頭count要素と残りに分割する。
        if root < 0: return (-1, -1)
        self.push(root)
        let leftSize = self.nodeSize(self.nodes[root].left)
        if count <= leftSize:
            let (left, middle) = self.split(self.nodes[root].left, count)
            self.nodes[root].left = middle
            self.update(root)
            result = (left, root)
        else:
            let (middle, right) = self.split(
                self.nodes[root].right, count - leftSize - 1)
            self.nodes[root].right = middle
            self.update(root)
            result = (root, right)

    proc insert[T](self: var ImplicitTreap[T], pos: Natural, value: sink T) =
        when defined(debug):
            assert pos <= self.len, "ImplicitTreap insertion position is out of range"
        let (left, right) = self.split(self.root, pos)
        let node = self.newNode(value)
        self.root = self.merge(self.merge(left, node), right)

    proc addFirst[T](self: var ImplicitTreap[T], value: sink T) {.inline.} =
        self.insert(0, value)

    proc addLast[T](self: var ImplicitTreap[T], value: sink T) {.inline.} =
        self.insert(self.len, value)

    proc delete[T](self: var ImplicitTreap[T], pos: Natural): T {.discardable.} =
        when defined(debug):
            assert pos < self.len, "ImplicitTreap deletion position is out of range"
        let (left, rest) = self.split(self.root, pos)
        let (removed, right) = self.split(rest, 1)
        self.push(removed)
        result = move(self.nodes[removed].value)
        self.nodes[removed].left = -1
        self.nodes[removed].right = -1
        self.nodes[removed].size = 0
        self.freeList.add(removed)
        self.root = self.merge(left, right)

    proc `[]`[T](self: var ImplicitTreap[T], pos: Natural): T =
        when defined(debug):
            assert pos < self.len, "ImplicitTreap index is out of range"
        var node = self.root
        var index = int(pos)
        while true:
            self.push(node)
            let leftSize = self.nodeSize(self.nodes[node].left)
            if index < leftSize:
                node = self.nodes[node].left
            elif index == leftSize:
                return self.nodes[node].value
            else:
                index -= leftSize + 1
                node = self.nodes[node].right

    proc `[]=`[T](self: var ImplicitTreap[T], pos: Natural, value: sink T) =
        when defined(debug):
            assert pos < self.len, "ImplicitTreap index is out of range"
        var node = self.root
        var index = int(pos)
        while true:
            self.push(node)
            let leftSize = self.nodeSize(self.nodes[node].left)
            if index < leftSize:
                node = self.nodes[node].left
            elif index == leftSize:
                self.nodes[node].value = value
                return
            else:
                index -= leftSize + 1
                node = self.nodes[node].right

    proc reverse[T](self: var ImplicitTreap[T], first, last: Natural) =
        # 半開区間[first, last)を反転する。
        when defined(debug):
            assert first <= last and last <= self.len,
                "ImplicitTreap reverse range is out of range"
        if first == last: return
        let (left, rest) = self.split(self.root, first)
        let (middle, right) = self.split(rest, last - first)
        self.toggleReverse(middle)
        self.root = self.merge(self.merge(left, middle), right)

    proc clear[T](self: var ImplicitTreap[T]) =
        self.nodes.setLen(0)
        self.freeList.setLen(0)
        self.root = -1

    iterator items[T](self: var ImplicitTreap[T]): T =
        # 再帰を使わないin-order走査。
        var stack = newSeqOfCap[int](64)
        var node = self.root
        while node >= 0 or stack.len > 0:
            while node >= 0:
                self.push(node)
                stack.add(node)
                node = self.nodes[node].left
            node = stack.pop()
            yield self.nodes[node].value
            node = self.nodes[node].right
