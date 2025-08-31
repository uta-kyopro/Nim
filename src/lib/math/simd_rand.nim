
include ../header


# SIMDを使った8並列乱数生成(標準の約2倍程度の速度)
when not declared SimdRandModule:       # 乱数生成高速化
    {.passC: "-mavx2".}
    {.push header: "immintrin.h".}
    type M256i {.importc: "__m256i".} = object
    func mm256_setr_epi32(a7,a6,a5,a4,a3,a2,a1,a0: cuint): M256i {.importc: "_mm256_setr_epi32".}
    func mm256_store_si256(p: ptr M256i, a: M256i) {.importc: "_mm256_store_si256".}
    func mm256_load_si256(p: ptr M256i): M256i {.importc: "_mm256_load_si256".}
    func mm256_slli_epi32(a: M256i, i: cuint): M256i {.importc: "_mm256_slli_epi32".}
    func mm256_srli_epi32(a: M256i, i: cuint): M256i {.importc: "_mm256_srli_epi32".}
    func mm256_add_epi32(a, b: M256i): M256i {.importc: "_mm256_add_epi32".}
    func mm256_or_si256(a, b: M256i): M256i {.importc: "_mm256_or_si256".}
    func mm256_xor_si256(a, b: M256i): M256i {.importc: "_mm256_xor_si256".}
    proc mm256_set1_epi32(a: cuint): M256i {.importc: "_mm256_set1_epi32".}
    proc mm256_mullo_epi32(a,b: M256i): M256i {.importc: "_mm256_mullo_epi32".}
    {.pop.}

    type SimdRng = object
        a0, a1, c: M256i
        data {.align: 32.}: array[8, cuint]
        i: int

    proc initSimdRng(seed: uint64 = 0x106689D45497FDB5'u64): SimdRng =
        proc splitmix64(x: var uint64): uint64 =
            x += 0x9E3779B97F4A7C15'u64
            x = (x xor (x shr 30)) * 0xBF58476D1CE4E5B9'u64
            x = (x xor (x shr 27)) * 0x94D049BB133111EB'u64
            x xor (x shr 31)

        var x = seed
        var l, h {.align: 32.}: array[8, cuint]
        for i in 0..7:
            let b = splitmix64(x)
            l[i] = cast[cuint](splitmix64(x) or 1'u64)
            h[i] = cast[cuint]((splitmix64(x) shr 32) or 1'u64)
        result.a0 = mm256_load_si256(cast[ptr M256i](l[0].addr))
        result.a1 = mm256_load_si256(cast[ptr M256i](h[0].addr))
        result.c = mm256_set1_epi32(cast[cuint](0x9E3779BB))

    template rotl(s: M256i, k: int): M256i =
        mm256_or_si256(mm256_slli_epi32(s, k), mm256_srli_epi32(s, 32-k))

    template next(r: var SimdRng) =
        # xoroshiro64**
        var v = mm256_mullo_epi32(r.a0, r.c).rotl(5)
        v = mm256_add_epi32(mm256_slli_epi32(v, 2), v)
        mm256_store_si256(cast[ptr M256i](r.data[0].addr), v)

        let a1 = mm256_xor_si256(r.a0, r.a1)
        r.a0 = mm256_xor_si256(
                r.a0.rotl(26),
                mm256_xor_si256(a1, mm256_slli_epi32(a1, 9)))
        r.a1 = a1.rotl(13)

    # 0..ma の範囲を返す
    proc rand(r: var SimdRng, ma: int): int =
        if ma<=0: return 0
        if ((ma+1) and ma) == 0:  # 2冪はマスクで高速化
            if r.i == 0: r.next()
            result = cast[int](r.data[r.i]) and ma
            r.i = (r.i+1) and 7
        else:
            let max32 = cast[uint32](ma+1)
            let max64 = cast[uint64](max32)
            let thresh = (0'u32 - max32) mod max32
            while true:
                if r.i == 0: r.next()
                let x = cast[uint64](r.data[r.i]) * max64
                r.i = (r.i+1) and 7
                if cast[uint32](x) >= thresh:
                    return cast[int](x shr 32)

    # 0..<ma の範囲を返す
    template randrange(r: var SimdRng, ma: int): int = r.rand(ma-1)

