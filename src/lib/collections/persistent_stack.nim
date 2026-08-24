include ../header

# 計算量: push・pop・top・空判定は O(1)、get(i) は O(i)、全取得は O(n)。
when not declared PersistentStackModule:
    const PersistentStackModule = true

    type PersistentNode[T] = ref object
        next: PersistentNode[T]
        value: T

    type PersistentStack[T] = object
        root: PersistentNode[T]
        len: int

    proc makeNode[T](next: PersistentNode[T], value: T): PersistentNode[T] =
        PersistentNode[T](next: next, value: value)

    proc initPersistentStack[T](): PersistentStack[T] = discard

    proc isEmpty[T](self: PersistentStack[T]): bool =
        self.root.isNil

    proc top[T](self: PersistentStack[T]): lent T =
        when defined(debug):
            assert not self.isEmpty, "cannot peek into an empty PersistentStack"
        self.root.value

    proc push[T](self: PersistentStack[T], value: T): PersistentStack[T] =
        result.root = self.root.makeNode(value)
        result.len = self.len+1

    proc pop[T](self: PersistentStack[T]): PersistentStack[T] =
        when defined(debug):
            assert not self.isEmpty, "cannot pop from an empty PersistentStack"
        result.root = self.root.next
        result.len = self.len-1

    proc emplace[T](self: PersistentStack[T], value: T): PersistentStack[T] =
        self.push(value)

    proc get[T](self: PersistentStack[T], index: int): lent T =
        when defined(debug):
            assert index in 0..<self.len, "PersistentStack index is out of range"
        var current = self.root
        var currentIndex = 0
        while currentIndex < index:
            current = current.next
            currentIndex.inc
        current.value

    proc getAll[T](self: PersistentStack[T]): seq[T] =
        result = newSeqOfCap[T](self.len)
        var current = self.root
        while current != nil:
            result.add(current.value)
            current = current.next
