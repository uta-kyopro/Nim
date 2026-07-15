
include min_cost_flow_common

# Heap Primal-Dual法による最小費用流。
# 計算量:
#   flow / slope: O(I E log V)
#   初期残余グラフに負コスト辺がある場合は、初期ポテンシャル計算の
#   O(VE) が追加され、全体で O(VE + I E log V)。
#   使用メモリ: O(V + E)
# 疎グラフ向け。負閉路は扱わない。
when not declared MinCostFlowHeapModule:
    const MinCostFlowHeapModule = true

    type MinCostFlowHeap = object
        data: MinCostFlowData

    proc initMinCostFlowHeap(nodeCount: Natural): MinCostFlowHeap =
        result.data = initMinCostFlowData(nodeCount)
    proc len(self: MinCostFlowHeap): int = self.data.len
    proc addEdge(self: var MinCostFlowHeap, src, dst: int,
            capacity: FlowCap, cost: FlowCost): int {.discardable.} =
        self.data.addEdge(src, dst, capacity, cost)
    proc getEdge(self: MinCostFlowHeap, index: int): MinCostFlowEdge = self.data.getEdge(index)
    proc edges(self: MinCostFlowHeap): seq[MinCostFlowEdge] = self.data.edges()

    proc slope(self: var MinCostFlowHeap, src, dst: int,
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
            var queue = initHeapQueue[(FlowCost, int)]()
            distance[src] = 0
            queue.push((0'i64, src))
            while queue.len > 0:
                let (currentDistance, node) = queue.pop()
                if currentDistance != distance[node]: continue
                for edgeIndex, edge in self.data.graph[node]:
                    if edge.cap <= 0: continue
                    let nextDistance = currentDistance + edge.cost +
                        potential[node] - potential[edge.dst]
                    if nextDistance < distance[edge.dst]:
                        distance[edge.dst] = nextDistance
                        parentNode[edge.dst] = node
                        parentEdge[edge.dst] = edgeIndex
                        queue.push((nextDistance, edge.dst))
            if parentNode[dst] < 0: break
            for node in 0..<self.len:
                if distance[node] != FlowCostInf: potential[node] += distance[node]
            let amount = self.data.augment(parentNode, parentEdge, src, dst,
                flowLimit - result[^1].flow)
            result.appendSlopePoint(amount)

    proc flow(self: var MinCostFlowHeap, src, dst: int,
            flowLimit: FlowCap = high(FlowCap)): FlowResult =
        self.slope(src, dst, flowLimit)[^1]
