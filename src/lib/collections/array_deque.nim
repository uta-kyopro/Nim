
include ../header

# 固定長両端キュー（格納可能な要素数は N - 1）
when not declared ArrayDequeModule:
    const ArrayDequeModule = true
    # Nは2冪。通常ビルドでは空からの取得と容量超過は未定義動作。
    type ArrayDeque[N: static[int], T] = object
        data: array[N, T]
        head, tail, mask: int
    proc initArrayDeque[T](N: static[int]): ArrayDeque[N, T] = 
        static:
            doAssert N >= 2 and (N and (N - 1)) == 0,
                "ArrayDeque size N must be a power of two and at least 2"
        result.mask = N-1
    proc len[N, T](self: ArrayDeque[N, T]): int =
        (self.tail-self.head+N) and self.mask
    proc clear(self: var ArrayDeque) =
        self.head = self.tail
    proc `[]`[N, T](self: ArrayDeque[N, T], i: Natural): lent T =
        self.data[(self.head+i) and self.mask]
    proc `[]=`[N, T](self:var ArrayDeque[N, T], i: Natural, v: T) =
        self.data[(self.head+i) and self.mask] = v
    proc addFirst[N, T](self:var ArrayDeque[N, T], v: T) =
        when defined(debug):
            assert self.len < N - 1, "ArrayDeque capacity exceeded"
        self.head = (self.head+self.mask) and self.mask
        self.data[self.head] = v
    proc addLast[N, T](self:var ArrayDeque[N, T], v: T) =
        when defined(debug):
            assert self.len < N - 1, "ArrayDeque capacity exceeded"
        self.data[self.tail] = v
        self.tail = (self.tail+1) and self.mask
    proc popFirst[N, T](self:var ArrayDeque[N, T]): T {.discardable.}=
        when defined(debug):
            assert self.len > 0, "cannot pop from an empty ArrayDeque"
        result = self.data[self.head]
        self.head = (self.head+1) and self.mask
    proc popLast[N, T](self:var ArrayDeque[N, T]): T {.discardable.}=
        when defined(debug):
            assert self.len > 0, "cannot pop from an empty ArrayDeque"
        self.tail = (self.tail+self.mask) and self.mask
        result = self.data[self.tail]
    proc peakFirst[N, T](self: var ArrayDeque[N, T]): var T =
        when defined(debug):
            assert self.len > 0, "cannot peek into an empty ArrayDeque"
        result = self.data[self.head]
    proc peakLast[N, T](self: var ArrayDeque[N, T]): var T =
        when defined(debug):
            assert self.len > 0, "cannot peek into an empty ArrayDeque"
        result = self.data[(self.tail+self.mask) and self.mask]
    iterator items[N, T](self: ArrayDeque[N, T]): lent T =
        for i in 0..<self.len:
            yield self.data[(self.head+i) and self.mask]
