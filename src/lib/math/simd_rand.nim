
include ../header


# AVX2を使った8並列乱数生成（xoroshiro64**、AVX2対応CPUが必要）。
# 計算量: 初期化・rand・randrange は O(1)（8個単位でSIMD生成）。
# 範囲変換は速度優先の乗算上位32bit方式。幅が2冪以外では僅かな偏りがある。
# 一様な32bit入力に対し各値の確率誤差は絶対値で 2^-32 未満。
# 幅が大きいと相対的な偏りは無視できない。厳密な一様乱数には使わない。
when not declared SimdRandModule:       # 乱数生成高速化
    const SimdRandModule = true
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
            var z = x
            z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
            z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
            z xor (z shr 31)

        var x = seed
        var l, h {.align: 32.}: array[8, cuint]
        for i in 0..7:
            let b = splitmix64(x)
            l[i] = cast[cuint](b)
            h[i] = cast[cuint](b shr 32)
            if b == 0: h[i] = 1  # 各レーンの全ゼロ状態だけを避ける
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

    # 0..ma。前提: 0 <= ma <= 2^32-1（かつintに収まること）。
    # -d:debug のみ引数を検査する。通常ビルドで前提違反の結果は保証しない。
    # ma == 0 は乱数を消費しない。同じseedでも旧実装とは生成列が変わる。
    proc rand(r: var SimdRng, ma: int): int {.inline.} =
        when defined(debug):
            doAssert ma >= 0 and uint64(ma) <= 0xFFFFFFFF'u64,
                "SimdRng.rand requires 0 <= ma <= 2^32-1"
        if ma == 0: return 0
        if r.i == 0: r.next()
        let width = uint64(ma) + 1'u64
        result = int((uint64(r.data[r.i]) * width) shr 32)
        r.i = (r.i+1) and 7

    # 0..<ma。前提: 1 <= ma <= 2^32（かつintに収まること）。
    proc randrange(r: var SimdRng, ma: int): int {.inline.} =
        when defined(debug):
            doAssert ma > 0 and uint64(ma) <= 0x100000000'u64,
                "SimdRng.randrange requires 1 <= ma <= 2^32"
        r.rand(ma-1)

