# nim cpp -r -d:debug --nimcache:build/nimcache_simd --outdir:build/tests tests/test_simd_rand.nim
include ../src/lib/math/simd_rand
import std/unittest

suite "SIMD random generator":
  test "initialization uses SplitMix64 reference values":
    var r = initSimdRng(0)
    var lo, hi {.align: 32.}: array[8, uint32]
    mm256_store_si256(cast[ptr M256i](lo[0].addr), r.a0)
    mm256_store_si256(cast[ptr M256i](hi[0].addr), r.a1)
    check (uint64(hi[0]) shl 32 or uint64(lo[0])) == 0xE220A8397B1DCDAF'u64
    check (uint64(hi[1]) shl 32 or uint64(lo[1])) == 0x6E789E6AA1B965F4'u64

  test "SIMD output matches scalar xoroshiro64 starstar across refills":
    proc rot32(x: uint32, k: int): uint32 =
      (x shl k) or (x shr (32-k))
    for seed in [0'u64, 123'u64, uint64.high]:
      var r = initSimdRng(seed)
      var s0, s1 {.align: 32.}: array[8, uint32]
      mm256_store_si256(cast[ptr M256i](s0[0].addr), r.a0)
      mm256_store_si256(cast[ptr M256i](s1[0].addr), r.a1)
      for i in 0..<80000:
        let lane = i and 7
        let expected = rot32(s0[lane] * 0x9E3779BB'u32, 5) * 5'u32
        let mixed = s0[lane] xor s1[lane]
        s0[lane] = rot32(s0[lane], 26) xor mixed xor (mixed shl 9)
        s1[lane] = rot32(mixed, 13)
        check r.rand(int(0xFFFFFFFF'u64)) == int(expected)

  test "conversion handles endpoints and full 32-bit width":
    var r = initSimdRng(123)
    for bound in [1, 2, 255, 1000, int(0xFFFFFFFE'u64), int(0xFFFFFFFF'u64)]:
      r.i = 1
      r.data[1] = 0
      r.data[2] = 0xFFFFFFFF'u32
      check r.rand(bound) == 0
      check r.rand(bound) == bound
    var a = initSimdRng(456)
    var b = initSimdRng(456)
    check a.rand(0) == 0
    check a.randrange(1) == 0
    for _ in 0..<1000:
      check a.randrange(int(0x100000000'u64)) == b.rand(int(0xFFFFFFFF'u64))
      let v = r.randrange(1001)
      check v >= 0 and v < 1001

  test "mixed bounds are deterministic and stay within range":
    var a = initSimdRng(789)
    var b = initSimdRng(789)
    for i in 0..<10000:
      let bound = 100 + (i and 1023)
      let value = a.rand(bound)
      check value == b.rand(bound)
      check value >= 0 and value <= bound

  when defined(debug):
    test "invalid bounds are rejected in debug builds":
      var r = initSimdRng(123)
      expect AssertionDefect:
        discard r.rand(-1)
      expect AssertionDefect:
        discard r.rand(int(0x100000000'u64))
      expect AssertionDefect:
        discard r.randrange(0)
      expect AssertionDefect:
        discard r.randrange(int.low)
      expect AssertionDefect:
        discard r.randrange(int(0x100000001'u64))
