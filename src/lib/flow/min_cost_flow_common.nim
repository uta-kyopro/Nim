
include ../header

# 記号:
#   V = 頂点数, E = addEdgeで追加した辺数, I = 増加路を流した回数
#   1回の増加でボトルネック容量まで流すため、Iは要求流量以下になる。
# 共通API:
#   init: O(V), addEdge: amortized O(1), getEdge: O(1), edges: O(E)
# 計算量: initialPotential は O(VE)、1回の augment は O(V)。
when not declared MinCostFlowCommonModule:
    const MinCostFlowCommonModule = true

    type
        FlowCap = int64
        FlowCost = int64
        FlowResult = tuple[flow: FlowCap, cost: FlowCost]

        MinCostFlowEdge = object
            src, dst: int
            capacity, flow: FlowCap
            cost: FlowCost

        ResidualCostEdge = object
            dst, rev: int
            cap: FlowCap
            cost: FlowCost

        MinCostFlowData = object
            graph: seq[seq[ResidualCostEdge]]
            positions: seq[(int, int)]

    const FlowCostInf = high(FlowCost) div 4

    proc initMinCostFlowData(nodeCount: Natural): MinCostFlowData =
        result.graph = newSeq[seq[ResidualCostEdge]](nodeCount)

    proc len(self: MinCostFlowData): int {.inline.} = self.graph.len

    proc addEdge(self: var MinCostFlowData, src, dst: int,
            capacity: FlowCap, cost: FlowCost): int =
        when defined(debug):
            assert src in 0..<self.len and dst in 0..<self.len
            assert capacity >= 0, "min-cost-flow capacity must be nonnegative"
        result = self.positions.len
        let srcIndex = self.graph[src].len
        let dstIndex = self.graph[dst].len
        self.positions.add((src, srcIndex))
        self.graph[src].add(ResidualCostEdge(
            dst: dst, rev: dstIndex, cap: capacity, cost: cost))
        self.graph[dst].add(ResidualCostEdge(
            dst: src, rev: srcIndex, cap: 0, cost: -cost))

    proc getEdge(self: MinCostFlowData, edgeIndex: int): MinCostFlowEdge =
        when defined(debug):
            assert edgeIndex in 0..<self.positions.len
        let (src, index) = self.positions[edgeIndex]
        let edge = self.graph[src][index]
        let reverse = self.graph[edge.dst][edge.rev]
        result = MinCostFlowEdge(src: src, dst: edge.dst,
            capacity: edge.cap + reverse.cap, flow: reverse.cap,
            cost: edge.cost)

    proc edges(self: MinCostFlowData): seq[MinCostFlowEdge] =
        result = newSeqOfCap[MinCostFlowEdge](self.positions.len)
        for i in 0..<self.positions.len: result.add(self.getEdge(i))

    proc augment(self: var MinCostFlowData, parentNode, parentEdge: seq[int],
            src, dst: int, limit: FlowCap): FlowResult =
        var amount = limit
        var node = dst
        var unitCost: FlowCost = 0
        while node != src:
            let prev = parentNode[node]
            let edgeIndex = parentEdge[node]
            amount = min(amount, self.graph[prev][edgeIndex].cap)
            unitCost += self.graph[prev][edgeIndex].cost
            node = prev
        node = dst
        while node != src:
            let prev = parentNode[node]
            let edgeIndex = parentEdge[node]
            let reverseIndex = self.graph[prev][edgeIndex].rev
            self.graph[prev][edgeIndex].cap -= amount
            self.graph[node][reverseIndex].cap += amount
            node = prev
        (amount, unitCost * amount)

    proc initialPotential(self: MinCostFlowData, src: int): seq[FlowCost] =
        # 到達可能な負コスト辺に対応するためBellman–Fordを一度実行する。
        var hasNegativeEdge = false
        for adjacency in self.graph:
            for edge in adjacency:
                if edge.cap > 0 and edge.cost < 0:
                    hasNegativeEdge = true
                    break
            if hasNegativeEdge: break
        if not hasNegativeEdge:
            return newSeq[FlowCost](self.len)
        result = newSeqWith(self.len, FlowCostInf)
        result[src] = 0
        for iteration in 0..<self.len:
            var updated = false
            for node in 0..<self.len:
                if result[node] == FlowCostInf: continue
                for edge in self.graph[node]:
                    if edge.cap <= 0: continue
                    let nextDistance = result[node] + edge.cost
                    if nextDistance < result[edge.dst]:
                        result[edge.dst] = nextDistance
                        updated = true
                        when defined(debug):
                            assert iteration + 1 < self.len,
                                "negative cost cycle is reachable from source"
            if not updated: break
        for value in result.mitems:
            if value == FlowCostInf: value = 0

    proc appendSlopePoint(result: var seq[FlowResult], amount: FlowResult) =
        let next = (flow: result[^1].flow + amount.flow,
                    cost: result[^1].cost + amount.cost)
        if result.len >= 2:
            let previousFlow = result[^1].flow - result[^2].flow
            let previousCost = result[^1].cost - result[^2].cost
            if previousCost * amount.flow == amount.cost * previousFlow:
                result[^1] = next
                return
        result.add(next)
