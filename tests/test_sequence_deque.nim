# -d:testUnrolled でUnrolledLinkedList、指定なしでImplicitTreapを検証。
when defined(testUnrolled):
    include ../src/lib/collections/unrolled_linked_list
    template make(T: typedesc): untyped = initUnrolledLinkedList[T](blockSize = 4)
else:
    include ../src/lib/collections/implicit_treap
    template make(T: typedesc): untyped = initImplicitTreap[T](seed = 123)
import std/unittest

var q = make(int)
var reference: seq[int]
var rng = initRand(20260924)
for step in 0..<10000:
    let action = if reference.len == 0: 0 else: rng.rand(7)
    let value = rng.rand(-100..100)
    case action
    of 0:
        q.addFirst(value)
        reference.insert(value, 0)
    of 1:
        when defined(testUnrolled): q.addLast(value)
        else: q.add(value)
        reference.add(value)
    of 2:
        doAssert q.popFirst() == reference[0]
        reference.delete(0)
    of 3:
        when defined(testUnrolled): doAssert q.popLast() == reference[^1]
        else: doAssert q.pop() == reference[^1]
        discard reference.pop()
    of 4:
        q.peakFirst() = value
        reference[0] = value
    of 5:
        q.peakLast() = value
        reference[^1] = value
    of 6:
        q.shiftForward()
        let first = reference[0]
        reference.delete(0)
        reference.add(first)
    else:
        let l = rng.rand(reference.len)
        let r = rng.rand(l..reference.len)
        q.reverse(l, r)
        if l < r: reference.reverse(l, r-1)
    doAssert q.len == reference.len
    doAssert toSeq(q.items) == reference
    if q.len > 0:
        doAssert q.peakFirst() == reference[0]
        doAssert q.peakLast() == reference[^1]

q.clear()
q.addLast(7)
q.shiftForward()
doAssert q.popLast() == 7
doAssert q.len == 0
q.addFirst(8)
doAssert q.popFirst() == 8
when defined(debug):
    expect AssertionDefect: discard q.popFirst()
    expect AssertionDefect: discard q.popLast()
    expect AssertionDefect: discard q.peakFirst()
    expect AssertionDefect: discard q.peakLast()
    expect AssertionDefect: q.shiftForward()
    when not defined(testUnrolled):
        expect AssertionDefect: discard q.pop()

var words = make(string)
words.addLast("abc")
words.addLast("def")
words.reverse(0, 2)
words.peakFirst().add("!")
words.shiftForward()
doAssert words.popFirst() == "abc"
doAssert words.popLast() == "def!"
when not defined(testUnrolled):
    words.add("one")
    words.add("two")
    doAssert words.pop() == "two"
    words.pop()
    doAssert words.len == 0
echo "OK: 10000 mixed operations, singleton, empty, mutable string endpoints"
