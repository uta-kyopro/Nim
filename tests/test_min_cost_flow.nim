include ../src/lib/flow/min_cost_flow_heap
include ../src/lib/flow/min_cost_flow_dense
include ../src/lib/flow/min_cost_flow_bellman_ford

import std/unittest

type TestEdge = tuple[src, dst: int, capacity, cost: int64]

proc bruteForce(nodeCount, source, sink: int, edges: seq[TestEdge],
        flowLimit: int64): FlowResult =
  var balance = newSeq[int64](nodeCount)
  var best: FlowResult = (flow: -1'i64, cost: FlowCostInf)

  proc enumerate(edgeIndex: int, cost: int64) =
    if edgeIndex == edges.len:
      for node in 0..<nodeCount:
        if node != source and node != sink and balance[node] != 0:
          return
      let flow = balance[sink]
      if flow < 0 or flow > flowLimit or balance[source] != -flow:
        return
      if flow > best.flow or (flow == best.flow and cost < best.cost):
        best = (flow, cost)
      return
    let edge = edges[edgeIndex]
    for amount in 0'i64..edge.capacity:
      balance[edge.src] -= amount
      balance[edge.dst] += amount
      enumerate(edgeIndex + 1, cost + amount * edge.cost)
      balance[edge.src] += amount
      balance[edge.dst] -= amount

  enumerate(0, 0)
  result = if best.flow < 0: (0'i64, 0'i64) else: best

template addAll(graph: untyped, edges: seq[TestEdge]) =
  for edge in edges:
    discard graph.addEdge(edge.src, edge.dst, edge.capacity, edge.cost)

suite "minimum-cost flow edge cases":
  test "unreachable sink returns zero flow":
    var heap = initMinCostFlowHeap(4)
    heap.addEdge(0, 1, 10, -3)
    check heap.flow(0, 3, 5) == (flow: 0'i64, cost: 0'i64)

  test "zero flow limit does not change residual graph":
    var graph = initMinCostFlowHeap(2)
    let edgeId = graph.addEdge(0, 1, 7, 4)
    check graph.flow(0, 1, 0) == (flow: 0'i64, cost: 0'i64)
    check graph.getEdge(edgeId).flow == 0

  test "negative edges are initialized correctly":
    let edges: seq[TestEdge] = @[
      (0, 1, 2'i64, -5'i64),
      (1, 3, 2'i64, 7'i64),
      (0, 2, 2'i64, 1'i64),
      (2, 3, 2'i64, 3'i64)
    ]
    var heap = initMinCostFlowHeap(4)
    var dense = initMinCostFlowDense(4)
    var bellman = initMinCostFlowBellmanFord(4)
    addAll(heap, edges); addAll(dense, edges); addAll(bellman, edges)
    let expected = (flow: 4'i64, cost: 12'i64)
    check heap.flow(0, 3, 4) == expected
    check dense.flow(0, 3, 4) == expected
    check bellman.flow(0, 3, 4) == expected

  test "slope merges consecutive equal marginal costs":
    template build(graph: untyped) =
      graph.addEdge(0, 1, 2, 1)
      graph.addEdge(1, 3, 2, 1)
      graph.addEdge(0, 2, 3, 3)
      graph.addEdge(2, 3, 3, 1)
    var heap = initMinCostFlowHeap(4)
    var dense = initMinCostFlowDense(4)
    var bellman = initMinCostFlowBellmanFord(4)
    build(heap); build(dense); build(bellman)
    let expected = @[
      (flow: 0'i64, cost: 0'i64),
      (flow: 2'i64, cost: 4'i64),
      (flow: 5'i64, cost: 16'i64)
    ]
    check heap.slope(0, 3, 10) == expected
    check dense.slope(0, 3, 10) == expected
    check bellman.slope(0, 3, 10) == expected

  test "edge inspection reports capacity, flow and cost":
    var graph = initMinCostFlowHeap(3)
    let first = graph.addEdge(0, 1, 5, -2)
    let second = graph.addEdge(1, 2, 3, 4)
    check graph.flow(0, 2, 2) == (flow: 2'i64, cost: 4'i64)
    check graph.getEdge(first) == MinCostFlowEdge(
      src: 0, dst: 1, capacity: 5, flow: 2, cost: -2)
    check graph.getEdge(second).flow == 2
    check graph.edges.len == 2

  test "flow can be requested incrementally":
    var graph = initMinCostFlowHeap(3)
    graph.addEdge(0, 1, 4, 2)
    graph.addEdge(1, 2, 4, 3)
    check graph.flow(0, 2, 1) == (flow: 1'i64, cost: 5'i64)
    check graph.flow(0, 2, 2) == (flow: 2'i64, cost: 10'i64)
    check graph.flow(0, 2, 10) == (flow: 1'i64, cost: 5'i64)

suite "minimum-cost flow exhaustive comparison":
  test "all implementations match brute force on tiny DAGs":
    var rng = initRand(20260714)
    for caseIndex in 0..<250:
      let nodeCount = rng.rand(2..6)
      var edges: seq[TestEdge]
      for src in 0..<nodeCount:
        for dst in src+1..<nodeCount:
          if edges.len < 7 and rng.rand(2) == 0:
            edges.add((src, dst, int64(rng.rand(1..2)),
                       int64(rng.rand(-5..8))))
      let limit = int64(rng.rand(0..5))
      let expected = bruteForce(nodeCount, 0, nodeCount-1, edges, limit)
      var heap = initMinCostFlowHeap(nodeCount)
      var dense = initMinCostFlowDense(nodeCount)
      var bellman = initMinCostFlowBellmanFord(nodeCount)
      addAll(heap, edges); addAll(dense, edges); addAll(bellman, edges)
      checkpoint "case=" & $caseIndex & " edges=" & $edges & " limit=" & $limit
      check heap.flow(0, nodeCount-1, limit) == expected
      check dense.flow(0, nodeCount-1, limit) == expected
      check bellman.flow(0, nodeCount-1, limit) == expected
