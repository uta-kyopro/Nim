import ../src/lib/math/int128
import std/[unittest, algorithm, tables, os, sequtils, random]

suite "128bit integers":
    test "limits, decimal parsing and formatting":
        check sizeof(Int128) == 16
        check sizeof(UInt128) == 16
        check $low(Int128) == "-170141183460469231731687303715884105728"
        check $high(Int128) == "170141183460469231731687303715884105727"
        check $high(UInt128) == "340282366920938463463374607431768211455"
        for x in [low(Int128), high(Int128), initInt128(0), initInt128(-7)]:
            check parseInt128($x) == x
        check parseInt128("+00042") == initInt128(42)
        check parseInt128("-0") == initInt128(0)
        check parseUInt128("+00042") == initUInt128(42)
        check parseUInt128($high(UInt128)) == high(UInt128)

    test "integer conversion and signed division":
        check toInt[int64](initInt128(low(int64))) == low(int64)
        check toInt[int8](initInt128(-128)) == -128'i8
        check toInt[uint64](initInt128(high(uint64))) == high(uint64)
        check toInt[uint64](initUInt128(high(uint64))) == high(uint64)
        check toInt[int16](initUInt128(32767)) == 32767'i16
        check toInt128(initUInt128(high(uint64))) == initInt128(high(uint64))
        check toUInt128(high(Int128)) == parseUInt128($high(Int128))
        check initInt128(-7) div initInt128(3) == initInt128(-2)
        check initInt128(-7) mod initInt128(3) == initInt128(-1)
        var x = initInt128(10)
        x += initInt128(7)
        x *= initInt128(3)
        x = x div initInt128(2)
        check x == initInt128(25)
        inc x
        dec x
        check x == initInt128(25)
        var calls = 0
        var values = @[initInt128(2)]
        proc index(): int =
            inc calls
            0
        values[index()] += initInt128(3)
        check calls == 1
        check values[0] == initInt128(5)

    test "bits, unsigned wrap, sequences and hashing":
        let x = initInt128(1) shl 100
        check $x == "1267650600228229401496703205376"
        check (initInt128(-8) shr 1) == initInt128(-4)
        check (initInt128(-1) shl 127) == low(Int128)
        check (initUInt128(1) shl 127) == parseUInt128("170141183460469231731687303715884105728")
        check high(UInt128) + initUInt128(1) == low(UInt128)
        check low(UInt128) - initUInt128(1) == high(UInt128)
        check high(UInt128) * initUInt128(2) == high(UInt128) - initUInt128(1)
        check not initUInt128(0) == high(UInt128)
        check (initInt128(-1) and initInt128(15)) == initInt128(15)
        var values = @[high(Int128), x, low(Int128), initInt128(0)]
        values.sort(proc(a, b: Int128): int = cmp(a, b))
        check values[0] == low(Int128)
        var copied = values
        copied[0] = initInt128(2)
        check values[0] == low(Int128)
        var table = initTable[Int128, int]()
        table[x] = 42
        check table[parseInt128($x)] == 42
        var unsignedTable = initTable[UInt128, string]()
        unsignedTable[high(UInt128)] = "max"
        check unsignedTable[parseUInt128($high(UInt128))] == "max"

    test "stream input":
        let path = getAppDir() / "int128_input.txt"
        writeFile(path, "  -170141183460469231731687303715884105728\n340282366920938463463374607431768211455")
        var file = open(path)
        check readInt128(file) == low(Int128)
        check readUInt128(file) == high(UInt128)
        file.close()
        removeFile(path)

    test "bitops compatible queries and ascending bit enumeration":
        check popCount(initUInt128(0)) == 0
        check firstSetBit(initUInt128(0)) == 0
        when defined(noUndefinedBitOpts):
            check countTrailingZeroBits(initUInt128(0)) == 0
        elif defined(debug):
            expect AssertionDefect: discard countTrailingZeroBits(initUInt128(0))
        check toSeq(getSetBits(initUInt128(0))).len == 0
        check popCount(high(UInt128)) == 128
        check toSeq(high(UInt128).getSetBits()) == toSeq(0..<128)
        check popCount(initInt128(-1)) == 128
        check firstSetBit(low(Int128)) == 128
        check countTrailingZeroBits(low(Int128)) == 127
        check toSeq(low(Int128).getSetBits()) == @[127]
        for bit in 0..<128:
            let x = initUInt128(1) shl bit
            check popCount(x) == 1
            check firstSetBit(x) == bit + 1
            check countTrailingZeroBits(x) == bit
            check countSetBits(x) == 1
            if bit < 64:
                check firstSetBit(x) == bitops.firstSetBit(1'u64 shl bit)
                check countTrailingZeroBits(x) == bitops.countTrailingZeroBits(1'u64 shl bit)
            check toSeq(x.getSetBits()) == @[bit]
        var rng = initRand(20261015)
        for _ in 0..<250:
            var x = initUInt128(0)
            var expected: seq[int]
            for bit in 0..<128:
                if rng.rand(1) == 1:
                    x = x or (initUInt128(1) shl bit)
                    expected.add(bit)
            let original = x
            check popCount(x) == expected.len
            check firstSetBit(x) == (if expected.len == 0: 0 else: expected[0] + 1)
            if expected.len > 0:
                check countTrailingZeroBits(x) == expected[0]
            check toSeq(x.getSetBits()) == expected
            check x == original

    when defined(debug):
        test "invalid input, casts, arithmetic and shifts are checked":
            for s in ["", "+", "-", "12x", " 1", "170141183460469231731687303715884105728",
                      "-170141183460469231731687303715884105729"]:
                expect AssertionDefect: discard parseInt128(s)
            for s in ["", "-1", "12x", "340282366920938463463374607431768211456"]:
                expect AssertionDefect: discard parseUInt128(s)
            expect AssertionDefect: discard initUInt128(-1)
            expect AssertionDefect: discard toUInt128(initInt128(-1))
            expect AssertionDefect: discard toInt128(high(UInt128))
            expect AssertionDefect: discard toInt[int8](initInt128(128))
            expect AssertionDefect: discard toInt[uint8](initInt128(-1))
            expect AssertionDefect: discard toInt[int64](high(UInt128))
            expect AssertionDefect: discard high(Int128) + initInt128(1)
            expect AssertionDefect: discard low(Int128) - initInt128(1)
            expect AssertionDefect: discard high(Int128) * initInt128(2)
            expect AssertionDefect: discard -low(Int128)
            expect AssertionDefect: discard low(Int128) div initInt128(-1)
            expect AssertionDefect: discard low(Int128) mod initInt128(-1)
            expect AssertionDefect: discard initUInt128(1) div initUInt128(0)
            expect AssertionDefect: discard initInt128(1) mod initInt128(0)
            expect AssertionDefect: discard initInt128(1) shl 127
            expect AssertionDefect: discard initUInt128(1) shr 128
            expect AssertionDefect: discard initInt128(1) shl -1
