
include ../header

# 静的次元の点集合に対するKD-tree。
# 点は構築後不変で、検索結果には入力時のindexを返す。
when not declared KdTreeModule:
    const KdTreeModule = true

    type
        KdPoint[K: static[int], T] = array[K, T]

        KdNode[K: static[int], T] = object
            point: KdPoint[K, T]
            originalIndex: int
            left, right: int
            axis: int

        KdTree[K: static[int], T: SomeNumber] = object
            nodes: seq[KdNode[K, T]]
            root: int

        KdNeighbor = tuple[index: int, distanceSquared: float64]

    proc squaredDistance[K, T](a, b: KdPoint[K, T]): float64 {.inline.} =
        for axis in 0..<K:
            let d = float64(a[axis]) - float64(b[axis])
            result += d * d

    proc pointLess[K, T](points: openArray[KdPoint[K, T]],
            a, b, axis: int): bool {.inline.} =
        if points[a][axis] != points[b][axis]:
            points[a][axis] < points[b][axis]
        else:
            a < b

    proc selectKth[K, T](points: openArray[KdPoint[K, T]],
            indices: var seq[int], first, last, kth, axis: int) =
        # [first,last)のkthへquickselect。median-of-threeでpivotを選ぶ。
        var left = first
        var right = last
        while right - left > 1:
            let middle = (left + right) shr 1
            if points.pointLess(indices[middle], indices[left], axis):
                swap(indices[middle], indices[left])
            if points.pointLess(indices[right-1], indices[left], axis):
                swap(indices[right-1], indices[left])
            if points.pointLess(indices[right-1], indices[middle], axis):
                swap(indices[right-1], indices[middle])
            let pivotIndex = indices[middle]
            swap(indices[middle], indices[right-1])
            var store = left
            for i in left..<right-1:
                if points.pointLess(indices[i], pivotIndex, axis):
                    swap(indices[store], indices[i])
                    store.inc
            swap(indices[store], indices[right-1])
            if store == kth: return
            if kth < store: right = store
            else: left = store + 1

    proc initKdTree[K: static[int], T: SomeNumber](
            points: openArray[KdPoint[K, T]]): KdTree[K, T] =
        static: doAssert K > 0, "KD-tree dimension must be positive"
        result.root = -1
        if points.len == 0: return
        let storedPoints = @points
        var builtNodes = newSeqOfCap[KdNode[K, T]](points.len)
        var indices = (0..<points.len).toSeq()

        proc build(first, last, depth: int): int =
            if first >= last: return -1
            let axis = depth mod K
            let middle = (first + last) shr 1
            storedPoints.selectKth(indices, first, last, middle, axis)
            result = builtNodes.len
            builtNodes.add(KdNode[K, T](
                point: storedPoints[indices[middle]],
                originalIndex: indices[middle], left: -1, right: -1,
                axis: axis))
            let left = build(first, middle, depth + 1)
            let right = build(middle + 1, last, depth + 1)
            builtNodes[result].left = left
            builtNodes[result].right = right

        result.root = build(0, points.len, 0)
        result.nodes = move(builtNodes)

    proc len[K, T](self: KdTree[K, T]): int {.inline.} = self.nodes.len

    proc nearest[K, T](self: KdTree[K, T],
            query: KdPoint[K, T]): KdNeighbor =
        if self.root < 0: return (-1, Inf)
        result = (-1, Inf)
        var stack = @[(self.root, 0.0)]
        while stack.len > 0:
            let (node, lowerBound) = stack.pop()
            if node < 0 or lowerBound > result.distanceSquared: continue
            let current = self.nodes[node]
            let distance = squaredDistance(current.point, query)
            if distance < result.distanceSquared or
                    (distance == result.distanceSquared and
                    current.originalIndex < result.index):
                result = (current.originalIndex, distance)
            let delta = float64(query[current.axis]) -
                float64(current.point[current.axis])
            let near = if delta < 0: current.left else: current.right
            let far = if delta < 0: current.right else: current.left
            if delta * delta <= result.distanceSquared:
                stack.add((far, delta * delta))
            stack.add((near, 0.0))

    proc kNearest[K, T](self: KdTree[K, T], query: KdPoint[K, T],
            count: Natural): seq[KdNeighbor] =
        if count == 0 or self.root < 0: return
        let limit = min(count, self.nodes.len)
        # 負距離を使い、HeapQueueの先頭を現在の最悪候補にする。
        var heap = initHeapQueue[(float64, int)]()
        var stack = @[(self.root, 0.0)]
        while stack.len > 0:
            let (node, lowerBound) = stack.pop()
            let currentWorst = if heap.len < limit: Inf else: -heap[0][0]
            if node < 0 or lowerBound > currentWorst: continue
            let current = self.nodes[node]
            let distance = squaredDistance(current.point, query)
            let candidate = (-distance, -current.originalIndex)
            if heap.len < limit:
                heap.push(candidate)
            elif candidate > heap[0]:
                discard heap.pop()
                heap.push(candidate)
            let delta = float64(query[current.axis]) -
                float64(current.point[current.axis])
            let near = if delta < 0: current.left else: current.right
            let far = if delta < 0: current.right else: current.left
            let worst = if heap.len < limit: Inf else: -heap[0][0]
            if delta * delta <= worst:
                stack.add((far, delta * delta))
            stack.add((near, 0.0))
        result = newSeqOfCap[KdNeighbor](heap.len)
        while heap.len > 0:
            let item = heap.pop()
            result.add((-item[1], -item[0]))
        result.sort(proc(a, b: KdNeighbor): int =
            result = cmp(a.distanceSquared, b.distanceSquared)
            if result == 0: result = cmp(a.index, b.index))

    proc radiusSearch[K, T](self: KdTree[K, T], query: KdPoint[K, T],
            radius: SomeNumber): seq[KdNeighbor] =
        let radiusSquared = float64(radius) * float64(radius)
        if radius >= 0:
            var stack = @[self.root]
            while stack.len > 0:
                let node = stack.pop()
                if node < 0: continue
                let current = self.nodes[node]
                let distance = squaredDistance(current.point, query)
                if distance <= radiusSquared:
                    result.add((current.originalIndex, distance))
                let delta = float64(query[current.axis]) -
                    float64(current.point[current.axis])
                if delta <= 0:
                    stack.add(current.left)
                    if delta * delta <= radiusSquared:
                        stack.add(current.right)
                else:
                    stack.add(current.right)
                    if delta * delta <= radiusSquared:
                        stack.add(current.left)
        result.sort(proc(a, b: KdNeighbor): int =
            result = cmp(a.distanceSquared, b.distanceSquared)
            if result == 0: result = cmp(a.index, b.index))

    proc rangeSearch[K, T](self: KdTree[K, T],
            lower, upper: KdPoint[K, T]): seq[int] =
        # 各軸についてlower <= point <= upperの閉区間検索。
        var stack = @[self.root]
        while stack.len > 0:
            let node = stack.pop()
            if node < 0: continue
            let current = self.nodes[node]
            var inside = true
            for axis in 0..<K:
                if current.point[axis] < lower[axis] or
                        current.point[axis] > upper[axis]:
                    inside = false
                    break
            if inside: result.add(current.originalIndex)
            let axis = current.axis
            if lower[axis] <= current.point[axis]: stack.add(current.left)
            if current.point[axis] <= upper[axis]: stack.add(current.right)
        result.sort()
