include ../header

# seqと同等に扱える固定長stack
when not declared StackModule:
    const StackModule = true

    type Stack[N: static[int], T] = object
        len: int
        data: array[N, T]

    proc initStack[N: static[int], T](): Stack[N, T] = discard

    proc `[]`[N, T](self: var Stack[N, T], i: Natural): var T =
        self.data[i]

    proc `[]=`[N, T](self: var Stack[N, T], i: Natural, value: T) =
        self.data[i] = value

    proc `[]`[N, T](self: var Stack[N, T], i: BackwardsIndex): var T =
        self.data[self.len-int(i)]

    proc `[]=`[N, T](self: var Stack[N, T], i: BackwardsIndex, value: T) =
        self.data[self.len-int(i)] = value

    proc add[N, T](self: var Stack[N, T], value: T) =
        self.data[self.len] = value
        self.len.inc

    proc swap[N, T](self: var Stack[N, T], i: Natural, value: var T) =
        swap(self.data[i], value)

    proc swap_add[N, T](self: var Stack[N, T], value: var T) =
        swap(self.data[self.len], value)
        self.len.inc

    proc push[N, T](self: var Stack[N, T], value: T) =
        self.add(value)

    proc pop[N, T](self: var Stack[N, T]): T {.discardable.} =
        self.len.dec
        self.data[self.len]

    proc clear[N, T](self: var Stack[N, T]) =
        self.len = 0

    iterator items[N, T](self: var Stack[N, T]): T =
        var i = 0
        while i < self.len:
            yield self.data[i]
            i.inc
