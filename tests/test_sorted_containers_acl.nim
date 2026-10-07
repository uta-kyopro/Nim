# nim cpp -r tests/test_sorted_containers_acl.nim
# nim cpp -d:aclFirst -r tests/test_sorted_containers_acl.nim
when defined(aclFirst):
    include atcoder/extra/structure/set_map
include ../src/lib/collections/sorted_containers
when not defined(aclFirst):
    include atcoder/extra/structure/set_map
import std/unittest
{.checks: on, assertions: on.}

suite "sqrt containers coexist with ACL":
    test "ACL and sqrt types and constructors are independently usable":
        var tree: SortedSet(int) = initSortedSet[int]()
        var treeMulti: SortedMultiSet(int) = initSortedMultiSet[int]()
        var treeMap = initSortedMap[int, string]()
        var sqrtSet: SqrtSet[int] = initSqrtSet[int](4)
        var sqrtMulti: SqrtMultiSet[int] = initSqrtMultiSet[int](4)
        var sqrtDict: SqrtDict[int, string] = initSqrtDict[int, string](4)
        for x in [3, 1, 3, 2]:
            tree.incl(x)
            treeMulti.incl(x)
            sqrtSet.incl(x)
            sqrtMulti.add(x)
        treeMap[1] = "acl"
        sqrtDict[1] = "sqrt"
        check tree.len == 3 and sqrtSet.len == 3
        check treeMulti.len == 4 and sqrtMulti.len == 4
        check treeMap[1] == "acl" and sqrtDict[1] == "sqrt"
        check toSeq(sqrtSet.items) == @[1, 2, 3]
        check toSeq(sqrtMulti.items) == @[1, 2, 3, 3]

    test "sorted set matches an ordered unique sequence":
        var rng = initRand(1001)
        var sortedSet = initSqrtSet[int](8)
        var reference: seq[int]
        for _ in 0..<5000:
            let value = rng.rand(-100..100)
            if rng.rand(1) == 0:
                let expected = value notin reference
                check sortedSet.incl(value) == expected
                if expected: reference.add(value); reference.sort()
            else:
                let index = reference.find(value)
                check sortedSet.excl(value) == (index >= 0)
                if index >= 0: reference.delete(index)
            check toSeq(sortedSet.items) == reference
            check sortedSet.lowerBound(value) == reference.lowerBoundLocal(value)
            check sortedSet.upperBound(value) == reference.upperBoundLocal(value)

    test "sorted multiset matches a sorted sequence":
        var rng = initRand(1002)
        var multi = initSqrtMultiSet[int](8)
        var reference: seq[int]
        for _ in 0..<5000:
            let value = rng.rand(-30..30)
            if rng.rand(2) > 0:
                multi.add(value)
                reference.add(value); reference.sort()
            else:
                let index = reference.find(value)
                check multi.remove(value) == (index >= 0)
                if index >= 0: reference.delete(index)
            check toSeq(multi.items) == reference
            check multi.count(value) == reference.count(value)
            if reference.len > 0:
                let index = rng.rand(0..<reference.len)
                check multi[index] == reference[index]

    test "sorted dict preserves key order":
        var rng = initRand(1003)
        var dict = initSqrtDict[int, int](8)
        var reference = initTable[int, int]()
        for _ in 0..<3000:
            let key = rng.rand(-100..100)
            if rng.rand(2) > 0:
                let value = rng.rand(-1000..1000)
                dict[key] = value
                reference[key] = value
            else:
                check dict.del(key) == reference.hasKey(key)
                reference.del(key)
            let expectedKeys = reference.keys.toSeq.sorted()
            check toSeq(dict.keys) == expectedKeys
            check toSeq(dict.pairs) == expectedKeys.mapIt((it, reference[it]))
