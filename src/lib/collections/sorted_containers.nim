
include ../header

# √分割されたソート済みコンテナ。
# 計算量（B = blockSize）: 検索は O(log(n / B) + log B)、追加・削除は O(log(n / B) + B)。
# 順位アクセスは O(n / B)、全走査・clear は O(n)。SqrtDict のキー検索は平均 O(1)。
when not declared SortedContainersModule:
    const SortedContainersModule = true

    const DefaultSqrtBlockSize = 256

    type
        SqrtSortedBlocks[T] = object
            blocks: seq[seq[T]]
            length: int
            blockSize: int

        SqrtSet[T] = object
            values: SqrtSortedBlocks[T]

        SqrtMultiSet[T] = object
            values: SqrtSortedBlocks[T]

        SqrtDict[K, V] = object
            keysData: SqrtSortedBlocks[K]
            values: Table[K, V]

    proc initSqrtSortedBlocks[T](blockSize: Positive): SqrtSortedBlocks[T] =
        result.blockSize = blockSize

    proc lowerBoundLocal[T](data: openArray[T], value: T): int {.inline.} =
        var left = 0
        var right = data.len
        while left < right:
            let middle = (left + right) shr 1
            if data[middle] < value: left = middle + 1
            else: right = middle
        left

    proc upperBoundLocal[T](data: openArray[T], value: T): int {.inline.} =
        var left = 0
        var right = data.len
        while left < right:
            let middle = (left + right) shr 1
            if value < data[middle]: right = middle
            else: left = middle + 1
        left

    proc locateValue[T](self: SqrtSortedBlocks[T], value: T): int {.inline.} =
        var left = 0
        var right = self.blocks.len
        while left < right:
            let middle = (left + right) shr 1
            if self.blocks[middle][^1] < value: left = middle + 1
            else: right = middle
        if left == self.blocks.len: self.blocks.len - 1 else: left

    proc splitLarge[T](self: var SqrtSortedBlocks[T], blockIndex: int) =
        if self.blocks[blockIndex].len > self.blockSize * 2:
            let middle = self.blocks[blockIndex].len shr 1
            let right = self.blocks[blockIndex][middle..^1]
            self.blocks[blockIndex].setLen(middle)
            self.blocks.insert(right, blockIndex + 1)

    proc mergeSmall[T](self: var SqrtSortedBlocks[T], blockIndex: int) =
        if blockIndex < 0 or blockIndex >= self.blocks.len or
            self.blocks[blockIndex].len >= self.blockSize div 2:
            return
        if blockIndex + 1 < self.blocks.len and self.blocks[blockIndex].len +
            self.blocks[blockIndex+1].len <= self.blockSize * 2:
            self.blocks[blockIndex].add(self.blocks[blockIndex+1])
            self.blocks.delete(blockIndex + 1)
        elif blockIndex > 0 and self.blocks[blockIndex-1].len +
            self.blocks[blockIndex].len <= self.blockSize * 2:
            self.blocks[blockIndex-1].add(self.blocks[blockIndex])
            self.blocks.delete(blockIndex)

    proc addValue[T](self: var SqrtSortedBlocks[T], value: sink T,
        allowDuplicate: bool): bool =
        if self.length == 0:
            self.blocks = @[@[value]]
            self.length = 1
            return true
        let blockIndex = self.locateValue(value)
        let offset = if allowDuplicate:
            self.blocks[blockIndex].upperBoundLocal(value)
        else:
            self.blocks[blockIndex].lowerBoundLocal(value)
        if not allowDuplicate and offset < self.blocks[blockIndex].len and
            not (value < self.blocks[blockIndex][offset]) and
            not (self.blocks[blockIndex][offset] < value):
            return false
        self.blocks[blockIndex].insert(value, offset)
        self.length.inc
        self.splitLarge(blockIndex)
        true

    proc removeValue[T](self: var SqrtSortedBlocks[T], value: T): bool =
        if self.length == 0: return false
        let blockIndex = self.locateValue(value)
        let offset = self.blocks[blockIndex].lowerBoundLocal(value)
        if offset == self.blocks[blockIndex].len or value < self.blocks[blockIndex][offset] or
            self.blocks[blockIndex][offset] < value:
            return false
        self.blocks[blockIndex].delete(offset)
        self.length.dec
        if self.blocks[blockIndex].len == 0:
            self.blocks.delete(blockIndex)
        else:
            self.mergeSmall(blockIndex)
        true

    proc containsValue[T](self: SqrtSortedBlocks[T], value: T): bool =
        if self.length == 0: return false
        let blockIndex = self.locateValue(value)
        let offset = self.blocks[blockIndex].lowerBoundLocal(value)
        offset < self.blocks[blockIndex].len and
            not (value < self.blocks[blockIndex][offset]) and
            not (self.blocks[blockIndex][offset] < value)

    proc lowerBoundValue[T](self: SqrtSortedBlocks[T], value: T): int =
        if self.length == 0: return 0
        let blockIndex = self.locateValue(value)
        for i in 0..<blockIndex: result += self.blocks[i].len
        result += self.blocks[blockIndex].lowerBoundLocal(value)

    proc upperBoundValue[T](self: SqrtSortedBlocks[T], value: T): int =
        if self.length == 0: return 0
        var blockIndex = self.locateValue(value)
        for i in 0..<blockIndex: result += self.blocks[i].len
        result += self.blocks[blockIndex].upperBoundLocal(value)
        # 同値がblock境界をまたいだ場合も数える。
        while blockIndex + 1 < self.blocks.len and
            not (value < self.blocks[blockIndex+1][0]) and
            not (self.blocks[blockIndex+1][0] < value):
            blockIndex.inc
            result += self.blocks[blockIndex].upperBoundLocal(value)

    proc atValue[T](self: SqrtSortedBlocks[T], index: int): lent T =
        when defined(debug):
            assert index in 0..<self.length, "sorted container index is out of range"
        var offset = index
        for values in self.blocks:
            if offset < values.len: return values[offset]
            offset -= values.len
        raiseAssert "unreachable sorted container index"

    iterator blockItems[T](self: SqrtSortedBlocks[T]): lent T =
        for values in self.blocks:
            for value in values:
                yield value

    proc initSqrtSet[T](blockSize: Positive = DefaultSqrtBlockSize): SqrtSet[T] =
        result.values = initSqrtSortedBlocks[T](blockSize)
    proc len[T](self: SqrtSet[T]): int {.inline.} = self.values.length
    proc incl[T](self: var SqrtSet[T], value: sink T): bool {.discardable.} =
        self.values.addValue(value, false)
    proc excl[T](self: var SqrtSet[T], value: T): bool {.discardable.} =
        self.values.removeValue(value)
    proc contains[T](self: SqrtSet[T], value: T): bool = self.values.containsValue(value)
    proc lowerBound[T](self: SqrtSet[T], value: T): int = self.values.lowerBoundValue(value)
    proc upperBound[T](self: SqrtSet[T], value: T): int = self.values.upperBoundValue(value)
    proc `[]`[T](self: SqrtSet[T], index: Natural): lent T = self.values.atValue(index)
    proc clear[T](self: var SqrtSet[T]) =
        self.values.blocks.setLen(0); self.values.length = 0
    iterator items[T](self: SqrtSet[T]): lent T =
        for value in self.values.blockItems: yield value

    proc initSqrtMultiSet[T](blockSize: Positive = DefaultSqrtBlockSize): SqrtMultiSet[T] =
        result.values = initSqrtSortedBlocks[T](blockSize)
    proc len[T](self: SqrtMultiSet[T]): int {.inline.} = self.values.length
    proc add[T](self: var SqrtMultiSet[T], value: sink T) =
        discard self.values.addValue(value, true)
    proc remove[T](self: var SqrtMultiSet[T], value: T): bool {.discardable.} =
        self.values.removeValue(value)
    proc removeAll[T](self: var SqrtMultiSet[T], value: T): int =
        while self.values.removeValue(value): result.inc
    proc contains[T](self: SqrtMultiSet[T], value: T): bool = self.values.containsValue(value)
    proc lowerBound[T](self: SqrtMultiSet[T], value: T): int = self.values.lowerBoundValue(value)
    proc upperBound[T](self: SqrtMultiSet[T], value: T): int = self.values.upperBoundValue(value)
    proc count[T](self: SqrtMultiSet[T], value: T): int = self.upperBound(value) - self.lowerBound(value)
    proc `[]`[T](self: SqrtMultiSet[T], index: Natural): lent T = self.values.atValue(index)
    proc clear[T](self: var SqrtMultiSet[T]) =
        self.values.blocks.setLen(0); self.values.length = 0
    iterator items[T](self: SqrtMultiSet[T]): lent T =
        for value in self.values.blockItems: yield value

    proc initSqrtDict[K, V](blockSize: Positive = DefaultSqrtBlockSize): SqrtDict[K, V] =
        result.keysData = initSqrtSortedBlocks[K](blockSize)
        result.values = initTable[K, V]()
    proc len[K, V](self: SqrtDict[K, V]): int {.inline.} = self.keysData.length
    proc hasKey[K, V](self: SqrtDict[K, V], key: K): bool = self.values.hasKey(key)
    proc `[]`[K, V](self: SqrtDict[K, V], key: K): lent V = self.values[key]
    proc `[]`[K, V](self: var SqrtDict[K, V], key: K): var V = self.values[key]
    proc `[]=`[K, V](self: var SqrtDict[K, V], key: K, value: sink V) =
        if not self.values.hasKey(key): discard self.keysData.addValue(key, false)
        self.values[key] = value
    proc del[K, V](self: var SqrtDict[K, V], key: K): bool {.discardable.} =
        if not self.values.hasKey(key): return false
        self.values.del(key)
        discard self.keysData.removeValue(key)
        true
    proc getOrDefault[K, V](self: SqrtDict[K, V], key: K, default: V): V =
        if self.values.hasKey(key): self.values[key] else: default
    proc lowerBound[K, V](self: SqrtDict[K, V], key: K): int = self.keysData.lowerBoundValue(key)
    proc upperBound[K, V](self: SqrtDict[K, V], key: K): int = self.keysData.upperBoundValue(key)
    proc keyAt[K, V](self: SqrtDict[K, V], index: Natural): lent K = self.keysData.atValue(index)
    proc clear[K, V](self: var SqrtDict[K, V]) =
        self.keysData.blocks.setLen(0); self.keysData.length = 0; self.values.clear()
    iterator keys[K, V](self: SqrtDict[K, V]): lent K =
        for key in self.keysData.blockItems: yield key
    iterator pairs[K, V](self: SqrtDict[K, V]): (K, V) =
        for key in self.keysData.blockItems: yield (key, self.values[key])
