import ../../lib/math/int128

let a = parseInt128("123456789012345678901234567890")
let b = initInt128(100)
echo a + b
echo a div b
echo a mod b
echo initInt128(1) shl 100
echo low(Int128), " .. ", high(Int128)
echo "unsigned max = ", high(UInt128)
echo "to int64 = ", toInt[int64](initInt128(-42))
echo "unsigned conversion = ", toUInt128(a)

var value = initInt128(7)
value *= initInt128(6)
echo value
doAssert value == initInt128(42)
