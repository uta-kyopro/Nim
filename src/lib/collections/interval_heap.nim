
include ../header


# 両端取り出しできるHeapQueue
when not declared IntervalHeapModule:
    # 通常のHeapQueueと比べて2~3倍遅い
    type IntervalHeap[T] = object
        data: seq[T]

    proc initIntervalHeap[T](): IntervalHeap[T] = discard

    proc initIntervalHeap[T](data: seq[T]): IntervalHeap[T] =
        result.data = data
        result.make_heap()

    # リストからヒープ構築 O(N)
    proc make_heap[T](self:var IntervalHeap[T]) =
        var i = self.data.len
        while i > 0:
            dec(i)
            if (i and 1) != 0 and self.data[i - 1] < self.data[i]:
                swap(self.data[i - 1], self.data[i])
            self.up(self.down(i), i)

    # 新しい要素を追加し適切な位置に調整 O(logn)
    proc push[T](self:var IntervalHeap[T], x: T) =
        var k = self.data.len
        self.data.add(x)
        self.up(k)

    # 最小値を削除 O(logn) やや遅い
    proc pop_min[T](self:var IntervalHeap[T]): T {.discardable.}=
        result = self.get_min()
        if self.data.len < 3:
            self.data.del(self.data.len - 1)
            return
        swap(self.data[1], self.data[^1])
        self.data.del(self.data.len - 1)
        self.up(self.down(1))

    # 最大値を削除 O(logn) やや早い
    proc pop_max[T](self:var IntervalHeap[T]): T {.discardable.}=
        result = self.get_max()
        if self.data.len < 2:
            self.data.del(self.data.len - 1)
            return
        swap(self.data[0], self.data[^1])
        self.data.del(self.data.len - 1)
        self.up(self.down(0))

    # 最小値を取得 O(1)
    proc get_min[T](self: IntervalHeap[T]): T =
        if self.data.len < 2:
            return self.data[0]
        else:
            return self.data[1]

    # 最大値を取得 O(1)
    proc get_max[T](self: IntervalHeap[T]): T =
        return self.data[0]
    
    # 最小値を削除して x を挿入し，削除した値を返す O(log n)
    proc replace_min[T](self:var IntervalHeap[T], x: T): T {.discardable.}=
        if self.data.len == 0:
            self.push(x)
            return x

        if self.data.len < 2:
            result = self.data[0]
            self.data[0] = x
            return

        result = self.data[1]
        self.data[1] = x
        var k = 1
        if self.data[0] < self.data[1]:
            swap(self.data[0], self.data[1])
            k = 0
        self.up(self.down(k), k)

    # 最大値を削除して x を挿入し，削除した値を返す O(log n)
    proc replace_max[T](self:var IntervalHeap[T], x: T): T {.discardable.}=
        if self.data.len == 0:
            self.push(x)
            return x

        result = self[0]
        self.data[0] = x
        var k = 0
        if self.data.len >= 2 and self.data[0] < self.data[1]:
            swap(self.data[0], self.data[1])
            k = 1
        self.up(self.down(k), k)

    proc empty[T](self: IntervalHeap[T]): bool =
        return self.data.len == 0

    proc parent[T](self: IntervalHeap[T], k: int): int =
        return ((k shr 1) - 1) and not 1

    # ノード k0 から下方向にヒープの性質を維持するために調整 O(logn)
    proc down[T](self:var IntervalHeap[T], k0: int): int {.discardable.}=
        var n = self.data.len
        var k = k0
        if (k and 1) != 0:
            while 2*k + 1 < n:
                var c = 2*k + 3
                if n <= c or self.data[c - 2] < self.data[c]:
                    c -= 2
                if c < n and self.data[c] < self.data[k]:
                    swap(self.data[k], self.data[c])
                    k = c
                else:
                    break
        else:
            while 2*k + 2 < n:
                var c = 2*k + 4
                if n <= c or self.data[c] < self.data[c - 2]:
                    c -= 2
                if c < n and self.data[k] < self.data[c]:
                    swap(self.data[k], self.data[c])
                    k = c
                else:
                    break
        return k

    # ノード k0 から上方向にヒープの性質を維持するために調整 O(logn)
    proc up[T](self:var IntervalHeap[T], k0: int, root: int = 1): int {.discardable.}=
        var k = k0 
        if (k or 1) < self.data.len and self.data[k and not 1] < self.data[k or 1]:
            swap(self.data[k and not 1], self.data[k or 1])
            k = k xor 1

        var p: int
        while root < k:
            p = self.parent(k)
            if self.data[p] < self.data[k]:
                swap(self.data[p], self.data[k])
                k = p
            else:
                break
        while root < k:
            p = self.parent(k) or 1
            if self.data[k] < self.data[p]:
                swap(self.data[p], self.data[k])
                k = p
            else:
                break
        return k
