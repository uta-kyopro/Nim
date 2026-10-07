# Run with and without -d:aclFirst to check both include orders.
when defined(aclFirst):
    include atcoder/extra/other/bitset
include ../src/lib/collections/bitset
when not defined(aclFirst):
    include atcoder/extra/other/bitset
import std/unittest
{.checks: on, assertions: on.}

suite "bitset ACL coexistence":
    test "static bitsets coexist and preserve word boundaries":
        var own: StaticBitSet[65] = initStaticBitSet(65)
        var acl: BitSet[65] = initBitSet[65]()
        own[64] = 1
        acl[64] = 1
        check own[64] and acl[64] == 1
        check own.popCount == 1
        var full = initStaticBitSet1(65)
        check full.popCount == 65
        full ^= own
        check full.popCount == 64 and not full[64]
        full |= own
        full &= own
        check full.popCount == 1
        full.clear()
        check full.popCount == 0
        check initStaticBitSet0(0).popCount == 0
        check initStaticBitSet1(64).popCount == 64
        check initStaticBitSet1(2001).popCount == 2001
        static:
            doAssert not compiles((block:
                var a = initStaticBitSet(64)
                a |= initStaticBitSet(65)
            ))
