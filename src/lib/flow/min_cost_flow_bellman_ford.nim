
include min_cost_flow_common

# Bellman–Ford逐次最短路法による最小費用流。
# 計算量:
#   flow / slope: O(I V E)
#   使用メモリ: O(V + E)
# 負コスト辺を直接扱えるため、小規模ケースや高速版の検証用に向く。
# 到達可能な負閉路は扱わない。
when not declared MinCostFlowBellmanFordModule:
    const MinCostFlowBellmanFordModule = true

    type MinCostFlowBellmanFord = object
        data: MinCostFlowData

    proc initMinCostFlowBellmanFord(nodeCount: Natural): MinCostFlowBellmanFord =
        result.data = initMinCostFlowData(nodeCount)
    proc len(self: MinCostFlowBellmanFord): int = self.data.len
    proc addEdge(self: var MinCostFlowBellmanFord, src, dst: int,
            capacity: FlowCap, cost: FlowCost): int {.discardable.} =
        self.data.addEdge(src, dst, capacity, cost)
    proc getEdge(self: MinCostFlowBellmanFord, index: int): MinCostFlowEdge = self.data.getEdge(index)
    proc edges(self: MinCostFlowBellmanFord): seq[MinCostFlowEdge] = self.data.edges()

    proc slope(self: var MinCostFlowBellmanFord, src, dst: int,
            flowLimit: FlowCap = high(FlowCap)): seq[FlowResult] =
        when defined(debug):
            assert src in 0..<self.len and dst in 0..<self.len and src != dst
            assert flowLimit >= 0
        result = @[(flow: 0'i64, cost: 0'i64)]
        while result[^1].flow < flowLimit:
            var distance = newSeqWith(self.len, FlowCostInf)
            var parentNode = newSeqWith(self.len, -1)
            var parentEdge = newSeqWith(self.len, -1)
            distance[src] = 0
            for iteration in 0..<self.len:
                var updated = false
                for node in 0..<self.len:
                    if distance[node] == FlowCostInf: continue
                    for edgeIndex, edge in self.data.graph[node]:
                        if edge.cap <= 0: continue
                        let nextDistance = distance[node] + edge.cost
                        if nextDistance < distance[edge.dst]:
                            distance[edge.dst] = nextDistance
                            parentNode[edge.dst] = node
                            parentEdge[edge.dst] = edgeIndex
                            updated = true
                            when defined(debug):
                                assert iteration + 1 < self.len,
                                    "negative cost cycle is reachable from source"
                if not updated: break
            if parentNode[dst] < 0: break
            let amount = self.data.augment(parentNode, parentEdge, src, dst,
                flowLimit - result[^1].flow)
            result.appendSlopePoint(amount)

    proc flow(self: var MinCostFlowBellmanFord, src, dst: int,
            flowLimit: FlowCap = high(FlowCap)): FlowResult =
        self.slope(src, dst, flowLimit)[^1]
