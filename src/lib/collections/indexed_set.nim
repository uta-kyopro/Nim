include ../header

# 計算量: IndexSet は追加・削除・検索・添字アクセスが O(1)。
# IndexedSet はハッシュ表により平均 O(1)。全走査・clear は O(n)。
when not declared IndexedSetModule:
    const IndexedSetModule = true

    type IndexSet = object
        data: seq[int]
        positions: seq[int]

    proc initIndexSet(size: int): IndexSet =
        when defined(debug):
            assert size >= 0, "IndexSet size must be nonnegative"
        result.positions = newSeqWith(size, -1)

    proc len(self: IndexSet): int {.inline.} =
        self.data.len

    proc contains(self: IndexSet, value: int): bool {.inline.} =
        when defined(debug):
            assert value in 0..<self.positions.len,
                "IndexSet value is out of range"
        self.positions[value] >= 0

    proc find(self: IndexSet, value: int): int {.inline.} =
        when defined(debug):
            assert value in 0..<self.positions.len,
                "IndexSet value is out of range"
        self.positions[value]

    proc incl(self: var IndexSet, value: int) {.inline.} =
        if value in self:
            return
        self.positions[value] = self.data.len
        self.data.add(value)

    proc excl(self: var IndexSet, value: int) {.inline.} =
        if value notin self:
            return
        let index = self.positions[value]
        let last = self.data[^1]
        self.data[index] = last
        self.positions[last] = index
        self.data.setLen(self.data.len-1)
        self.positions[value] = -1

    proc `[]`(self: IndexSet, index: Natural): int {.inline.} =
        when defined(debug):
            assert index < self.data.len, "IndexSet index is out of range"
        self.data[index]

    proc clear(self: var IndexSet) =
        for value in self.data:
            self.positions[value] = -1
        self.data.setLen(0)

    iterator items(self: IndexSet): int =
        for value in self.data:
            yield value

    type IndexedSet[T] = object
        data: seq[T]
        positions: Table[T, int]

    proc initIndexedSet[T](capacity: Natural = 0): IndexedSet[T] =
        result.data = newSeqOfCap[T](capacity)
        result.positions = initTable[T, int](capacity)

    proc initIndexedSet[T](values: openArray[T]): IndexedSet[T] =
        result = initIndexedSet[T](values.len)
        for value in values:
            result.incl(value)

    proc len[T](self: IndexedSet[T]): int {.inline.} =
        self.data.len

    proc contains[T](self: IndexedSet[T], value: T): bool {.inline.} =
        value in self.positions

    proc find[T](self: IndexedSet[T], value: T): int {.inline.} =
        self.positions.getOrDefault(value, -1)

    proc incl[T](self: var IndexedSet[T], value: T) {.inline.} =
        if value in self.positions:
            return
        self.positions[value] = self.data.len
        self.data.add(value)

    proc excl[T](self: var IndexedSet[T], value: T) {.inline.} =
        let index = self.find(value)
        if index < 0:
            return
        let last = self.data[^1]
        self.data[index] = last
        self.positions[last] = index
        self.data.setLen(self.data.len-1)
        self.positions.del(value)

    proc `[]`[T](self: IndexedSet[T], index: Natural): lent T {.inline.} =
        when defined(debug):
            assert index < self.data.len, "IndexedSet index is out of range"
        self.data[index]

    proc clear[T](self: var IndexedSet[T]) =
        self.data.setLen(0)
        self.positions.clear()

    proc reset[T](self: var IndexedSet[T]) =
        self.data = default(seq[T])
        self.positions = default(Table[T, int])

    iterator items[T](self: IndexedSet[T]): lent T =
        for value in self.data:
            yield value
