
include min_cost_flow_common

# 配列走査Dijkstraを用いるDense Primal-Dual法。
# 計算量:
#   flow / slope: O(I (V^2 + E)) = 密グラフでは O(I V^2)
#   初期残余グラフに負コスト辺がある場合は O(VE) が追加される。
#   使用メモリ: O(V + E)
# 小規模または密グラフ向け。負閉路は扱わない。
when not declared MinCostFlowDenseModule:
    const MinCostFlowDenseModule = true

    type MinCostFlowDense = object
        data: MinCostFlowData

    proc initMinCostFlowDense(nodeCount: Natural): MinCostFlowDense =
        result.data = initMinCostFlowData(nodeCount)
    proc len(self: MinCostFlowDense): int = self.data.len
    proc addEdge(self: var MinCostFlowDense, src, dst: int,
            capacity: FlowCap, cost: FlowCost): int {.discardable.} =
        self.data.addEdge(src, dst, capacity, cost)
    proc getEdge(self: MinCostFlowDense, index: int): MinCostFlowEdge = self.data.getEdge(index)
    proc edges(self: MinCostFlowDense): seq[MinCostFlowEdge] = self.data.edges()

    proc slope(self: var MinCostFlowDense, src, dst: int,
            flowLimit: FlowCap = high(FlowCap)): seq[FlowResult] =
        when defined(debug):
            assert src in 0..<self.len and dst in 0..<self.len and src != dst
            assert flowLimit >= 0
        result = @[(flow: 0'i64, cost: 0'i64)]
        var potential = self.data.initialPotential(src)
        while result[^1].flow < flowLimit:
            var distance = newSeqWith(self.len, FlowCostInf)
            var parentNode = newSeqWith(self.len, -1)
            var parentEdge = newSeqWith(self.len, -1)
            var used = newSeq[bool](self.len)
            distance[src] = 0
            for _ in 0..<self.len:
                var node = -1
                for candidate in 0..<self.len:
                    if not used[candidate] and distance[candidate] != FlowCostInf and
                            (node < 0 or distance[candidate] < distance[node]):
                        node = candidate
                if node < 0: break
                used[node] = true
                for edgeIndex, edge in self.data.graph[node]:
                    if edge.cap <= 0: continue
                    let nextDistance = distance[node] + edge.cost +
                        potential[node] - potential[edge.dst]
                    if nextDistance < distance[edge.dst]:
                        distance[edge.dst] = nextDistance
                        parentNode[edge.dst] = node
                        parentEdge[edge.dst] = edgeIndex
            if parentNode[dst] < 0: break
            for node in 0..<self.len:
                if distance[node] != FlowCostInf: potential[node] += distance[node]
            let amount = self.data.augment(parentNode, parentEdge, src, dst,
                flowLimit - result[^1].flow)
            result.appendSlopePoint(amount)

    proc flow(self: var MinCostFlowDense, src, dst: int,
            flowLimit: FlowCap = high(FlowCap)): FlowResult =
        self.slope(src, dst, flowLimit)[^1]
