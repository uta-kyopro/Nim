
include ../header

# thunder_libraryのObjectPoolを参考にした、整数index型のオブジェクトプール。
# 削除したindexをLIFOで再利用し、要素本体は連続したseqに保持する。
# 計算量: 確保（償却）・解放・添字アクセスは O(1)、reserve・clear は O(n)。
when not declared ObjectPoolModule:
    const ObjectPoolModule = true

    type ObjectPool[T] = object
        data: seq[T]
        freeList: seq[int]
        activeCount: int
        when defined(debug):
            active: seq[bool]

    proc initObjectPool[T](capacity: Natural = 0): ObjectPool[T] =
        result.data = newSeqOfCap[T](capacity)
        result.freeList = newSeqOfCap[int](capacity)
        when defined(debug):
            result.active = newSeqOfCap[bool](capacity)

    proc reserve[T](self: var ObjectPool[T], capacity: Natural) =
        # Nimのseqには公開reserve APIがないため、一度長さを伸ばして戻す。
        if capacity > self.data.len:
            let oldLen = self.data.len
            self.data.setLen(capacity)
            self.data.setLen(oldLen)
            when defined(debug):
                self.active.setLen(capacity)
                self.active.setLen(oldLen)
        if capacity > self.freeList.len:
            let oldLen = self.freeList.len
            self.freeList.setLen(capacity)
            self.freeList.setLen(oldLen)

    proc push[T](self: var ObjectPool[T], value: sink T): int =
        if self.freeList.len == 0:
            result = self.data.len
            self.data.add(value)
            when defined(debug):
                self.active.add(true)
        else:
            result = self.freeList.pop()
            self.data[result] = value
            when defined(debug):
                assert not self.active[result]
                self.active[result] = true
        self.activeCount.inc

    proc pop[T](self: var ObjectPool[T], index: int) =
        when defined(debug):
            assert index in 0..<self.data.len,
                "ObjectPool index is out of range"
            assert self.active[index], "ObjectPool index is already free"
            self.active[index] = false
        self.freeList.add(index)
        self.activeCount.dec

    proc `[]`[T](self: ObjectPool[T], index: int): lent T =
        when defined(debug):
            assert index in 0..<self.data.len and self.active[index],
                "ObjectPool index is not active"
        self.data[index]

    proc `[]`[T](self: var ObjectPool[T], index: int): var T =
        when defined(debug):
            assert index in 0..<self.data.len and self.active[index],
                "ObjectPool index is not active"
        self.data[index]

    proc `[]=`[T](self: var ObjectPool[T], index: int, value: sink T) =
        when defined(debug):
            assert index in 0..<self.data.len and self.active[index],
                "ObjectPool index is not active"
        self.data[index] = value

    proc len[T](self: ObjectPool[T]): int {.inline.} = self.activeCount

    proc size[T](self: ObjectPool[T]): int {.inline.} =
        # 参照実装と同じく、過去に使用した最大index + 1。
        self.data.len

    proc available[T](self: ObjectPool[T]): int {.inline.} =
        self.freeList.len

    proc clear[T](self: var ObjectPool[T]) =
        self.data.setLen(0)
        self.freeList.setLen(0)
        self.activeCount = 0
        when defined(debug):
            self.active.setLen(0)
