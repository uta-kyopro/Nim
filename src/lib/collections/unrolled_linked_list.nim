
include ../header

# √分割された可変長列（Unrolled Linked List）。
# ブロック間リンクには整数添字を使い、GC管理の参照ノードを使わない。
when not declared UnrolledLinkedListModule:
    const UnrolledLinkedListModule = true

    type
        UnrolledBlock[T] = object
            data: seq[T]
            prev, next: int

        UnrolledLinkedList[T] = object
            blocks: seq[UnrolledBlock[T]]
            freeList: seq[int]
            head, tail: int
            length: int
            blockSize: int

    proc initUnrolledLinkedList[T](blockSize: Positive = 256,
            capacity: Natural = 0): UnrolledLinkedList[T] =
        result.head = -1
        result.tail = -1
        result.blockSize = blockSize
        let blockCapacity = (capacity + blockSize - 1) div blockSize
        result.blocks = newSeqOfCap[UnrolledBlock[T]](blockCapacity)
        result.freeList = newSeqOfCap[int](blockCapacity)

    proc len[T](self: UnrolledLinkedList[T]): int {.inline.} = self.length

    proc newBlock[T](self: var UnrolledLinkedList[T], data: sink seq[T] = @[]): int =
        if self.freeList.len > 0:
            result = self.freeList.pop()
            self.blocks[result] = UnrolledBlock[T](
                data: data, prev: -1, next: -1)
        else:
            result = self.blocks.len
            self.blocks.add(UnrolledBlock[T](
                data: data, prev: -1, next: -1))

    proc releaseBlock[T](self: var UnrolledLinkedList[T], node: int) =
        self.blocks[node].data.setLen(0)
        self.blocks[node].prev = -1
        self.blocks[node].next = -1
        self.freeList.add(node)

    proc linkAfter[T](self: var UnrolledLinkedList[T], left, inserted: int) =
        if left < 0:
            let oldHead = self.head
            self.blocks[inserted].prev = -1
            self.blocks[inserted].next = oldHead
            if oldHead >= 0: self.blocks[oldHead].prev = inserted
            else: self.tail = inserted
            self.head = inserted
        else:
            let right = self.blocks[left].next
            self.blocks[inserted].prev = left
            self.blocks[inserted].next = right
            self.blocks[left].next = inserted
            if right >= 0: self.blocks[right].prev = inserted
            else: self.tail = inserted

    proc unlink[T](self: var UnrolledLinkedList[T], node: int) =
        let prev = self.blocks[node].prev
        let next = self.blocks[node].next
        if prev >= 0: self.blocks[prev].next = next
        else: self.head = next
        if next >= 0: self.blocks[next].prev = prev
        else: self.tail = prev
        self.releaseBlock(node)

    proc locate[T](self: UnrolledLinkedList[T], pos: int): (int, int) =
        # 端から近い方向に走査する。
        if pos < self.length div 2:
            var node = self.head
            var offset = pos
            while offset >= self.blocks[node].data.len:
                offset -= self.blocks[node].data.len
                node = self.blocks[node].next
            result = (node, offset)
        else:
            var node = self.tail
            var offset = self.length - pos
            while offset > self.blocks[node].data.len:
                offset -= self.blocks[node].data.len
                node = self.blocks[node].prev
            result = (node, self.blocks[node].data.len - offset)

    proc splitBlock[T](self: var UnrolledLinkedList[T], node, offset: int): int =
        # nodeのoffset以降を新しい右ブロックとして返す。
        if offset == 0: return node
        if offset == self.blocks[node].data.len:
            return self.blocks[node].next
        var rightData = self.blocks[node].data[offset..^1]
        self.blocks[node].data.setLen(offset)
        result = self.newBlock(move(rightData))
        self.linkAfter(node, result)

    proc splitAt[T](self: var UnrolledLinkedList[T], pos: int): int =
        # posが指す要素をブロック先頭にし、そのブロックを返す。
        if pos == self.length: return -1
        let (node, offset) = self.locate(pos)
        result = self.splitBlock(node, offset)

    proc splitLargeBlock[T](self: var UnrolledLinkedList[T], node: int) =
        if self.blocks[node].data.len > self.blockSize * 2:
            discard self.splitBlock(node, self.blocks[node].data.len div 2)

    proc mergeSmallBlock[T](self: var UnrolledLinkedList[T], node: int) =
        if node < 0 or self.blocks[node].data.len >= self.blockSize div 2:
            return
        let next = self.blocks[node].next
        if next >= 0 and self.blocks[node].data.len +
                self.blocks[next].data.len <= self.blockSize * 2:
            self.blocks[node].data.add(self.blocks[next].data)
            self.unlink(next)
            return
        let prev = self.blocks[node].prev
        if prev >= 0 and self.blocks[prev].data.len +
                self.blocks[node].data.len <= self.blockSize * 2:
            self.blocks[prev].data.add(self.blocks[node].data)
            self.unlink(node)

    proc insert[T](self: var UnrolledLinkedList[T], pos: Natural, value: sink T) =
        when defined(debug):
            assert pos <= self.length,
                "UnrolledLinkedList insertion position is out of range"
        if self.length == 0:
            let node = self.newBlock(newSeqOfCap[T](self.blockSize * 2))
            self.head = node
            self.tail = node
            self.blocks[node].data.add(value)
        elif pos == self.length:
            self.blocks[self.tail].data.add(value)
            self.splitLargeBlock(self.tail)
        else:
            let (node, offset) = self.locate(pos)
            self.blocks[node].data.insert(value, offset)
            self.splitLargeBlock(node)
        self.length.inc

    proc addFirst[T](self: var UnrolledLinkedList[T], value: sink T) {.inline.} =
        self.insert(0, value)

    proc addLast[T](self: var UnrolledLinkedList[T], value: sink T) {.inline.} =
        self.insert(self.length, value)

    proc delete[T](self: var UnrolledLinkedList[T], pos: Natural): T {.discardable.} =
        when defined(debug):
            assert pos < self.length,
                "UnrolledLinkedList deletion position is out of range"
        let (node, offset) = self.locate(pos)
        result = move(self.blocks[node].data[offset])
        self.blocks[node].data.delete(offset)
        self.length.dec
        if self.blocks[node].data.len == 0:
            self.unlink(node)
        else:
            self.mergeSmallBlock(node)

    proc `[]`[T](self: UnrolledLinkedList[T], pos: Natural): lent T =
        when defined(debug):
            assert pos < self.length,
                "UnrolledLinkedList index is out of range"
        let (node, offset) = self.locate(pos)
        self.blocks[node].data[offset]

    proc `[]=`[T](self: var UnrolledLinkedList[T], pos: Natural, value: sink T) =
        when defined(debug):
            assert pos < self.length,
                "UnrolledLinkedList index is out of range"
        let (node, offset) = self.locate(pos)
        self.blocks[node].data[offset] = value

    proc reverseData[T](data: var seq[T]) =
        var left = 0
        var right = data.len - 1
        while left < right:
            swap(data[left], data[right])
            left.inc
            right.dec

    proc normalizeBlocks[T](self: var UnrolledLinkedList[T]) =
        # splitAtで生じた小ブロックが反転のたびに蓄積するのを防ぐ。
        var node = self.head
        while node >= 0:
            let next = self.blocks[node].next
            if next >= 0 and self.blocks[node].data.len +
                    self.blocks[next].data.len <= self.blockSize:
                self.blocks[node].data.add(self.blocks[next].data)
                self.unlink(next)
            else:
                node = next

    proc reverse[T](self: var UnrolledLinkedList[T], first, last: Natural) =
        # 半開区間[first, last)を反転する。
        when defined(debug):
            assert first <= last and last <= self.length,
                "UnrolledLinkedList reverse range is out of range"
        if first == last: return
        let after = self.splitAt(last)
        let firstBlock = self.splitAt(first)
        let before = self.blocks[firstBlock].prev
        let lastBlock = if after >= 0: self.blocks[after].prev else: self.tail

        var node = firstBlock
        while node != after:
            let next = self.blocks[node].next
            self.blocks[node].data.reverseData()
            swap(self.blocks[node].prev, self.blocks[node].next)
            node = next

        if before >= 0: self.blocks[before].next = lastBlock
        else: self.head = lastBlock
        self.blocks[lastBlock].prev = before
        self.blocks[firstBlock].next = after
        if after >= 0: self.blocks[after].prev = firstBlock
        else: self.tail = firstBlock
        self.normalizeBlocks()

    proc clear[T](self: var UnrolledLinkedList[T]) =
        self.blocks.setLen(0)
        self.freeList.setLen(0)
        self.head = -1
        self.tail = -1
        self.length = 0

    iterator items[T](self: UnrolledLinkedList[T]): lent T =
        var node = self.head
        while node >= 0:
            for value in self.blocks[node].data:
                yield value
            node = self.blocks[node].next
