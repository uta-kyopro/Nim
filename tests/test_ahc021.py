"""Usage: python tests/test_ahc021.py EXE [ORIGINAL_FIXED_WIDTH_EXE]"""
import random
import subprocess
import sys
import time


SAMPLE = """
236
11 200
453 2 378
85 410 239 54
50 240 113 25 294
303 231 146 65 155 252
368 327 321 251 451 182 142
101 17 43 403 217 161 347 398
350 287 363 48 80 447 385 233 197
438 424 439 121 357 380 51 245 57 304
141 91 100 344 194 250 432 322 58 281 219
412 266 26 318 269 111 59 450 99 301 36 320
218 135 278 225 227 268 313 162 420 214 42 166 55
181 191 75 335 332 372 144 342 29 94 427 62 334 409
377 213 369 117 307 428 280 152 242 88 460 175 351 340 230
209 139 288 132 47 456 167 205 455 38 27 326 306 134 108 34
389 441 393 361 120 296 331 316 458 183 170 40 397 274 402 103 408
136 463 82 0 364 150 462 157 67 92 419 371 156 228 1 138 53 349
174 129 71 169 199 367 87 443 359 172 298 22 244 415 401 373 417 160 305
254 158 84 9 435 130 118 430 203 345 185 388 379 207 220 238 196 208 289 153
425 356 109 237 116 212 358 396 270 179 262 76 370 444 308 229 105 148 365 429 248
386 93 376 86 442 184 273 243 81 69 189 204 355 106 154 257 464 107 70 215 77 241
127 404 180 123 362 124 234 300 173 222 72 329 140 147 232 3 187 114 381 133 44 387 60
145 4 210 49 382 433 457 343 315 354 149 255 299 12 28 421 394 211 102 297 360 8 314 328
46 256 416 336 423 295 90 112 168 309 64 96 260 437 440 366 323 35 383 346 79 293 61 312 202
18 23 20 221 31 452 178 461 6 21 201 143 324 277 341 283 291 5 41 66 411 317 258 406 19 188
164 261 16 137 426 264 98 78 45 310 246 176 319 95 384 68 392 37 265 190 249 73 198 15 32 330 311
131 282 434 271 400 445 104 56 119 263 374 337 216 177 449 353 24 192 390 39 33 223 407 348 195 279 290 110
267 89 375 284 13 63 391 422 272 259 30 97 125 459 413 333 52 448 399 122 83 126 275 302 115 14 338 446 339
171 206 74 163 292 454 405 247 395 285 193 325 418 352 286 186 128 7 159 431 226 165 224 436 10 276 414 151 235 253
"""


def check(executable, label, values):
    board = []
    offset = 0
    for y in range(30):
        board.append(values[offset:offset + y + 1])
        offset += y + 1
    data = "\n".join(" ".join(map(str, row)) for row in board) + "\n"
    start = time.perf_counter()
    run = subprocess.run([executable], input=data, text=True,
                         capture_output=True, timeout=10, check=True)
    elapsed = time.perf_counter() - start
    lines = run.stdout.splitlines()
    count = int(lines[0])
    assert 0 <= count <= 10000 and len(lines) == count + 1
    neighbors = {(-1, -1), (-1, 0), (0, -1), (0, 1), (1, 0), (1, 1)}
    for line in lines[1:]:
        y, x, yy, xx = map(int, line.split())
        assert 0 <= x <= y < 30 and 0 <= xx <= yy < 30
        assert (yy - y, xx - x) in neighbors
        board[y][x], board[yy][xx] = board[yy][xx], board[y][x]
    assert sorted(v for row in board for v in row) == list(range(465))
    errors = sum(board[y][x] > board[y + 1][x + dx]
                 for y in range(29) for x in range(y + 1) for dx in (0, 1))
    score = 100000 - 5 * count if errors == 0 else 50000 - 50 * errors
    assert run.stderr.strip() == f"score: {score}"
    # 元実装同様2000手で終了する。逆順は未整列でも合法な部分解を許す。
    if label != "reverse":
        assert errors == 0, (label, count, errors)
    print(f"{label}: K={count}, E={errors}, score={score}, {elapsed:.3f}s")
    # 比較時は両方を同じ固定幅・最適化設定でビルドする。
    # 元コードは初期整列済みを処理できないため、そのケースだけ除外。
    if len(sys.argv) > 2 and label != "sorted":
        start = time.perf_counter()
        reference = subprocess.run([sys.argv[2]], input=data, text=True,
                                   capture_output=True, timeout=10, check=True)
        reference_time = time.perf_counter() - start
        assert run.stdout.split() == reference.stdout.split(), f"different actions: {label}"
        print(f"  original: {reference_time:.3f}s; identical actions")


if __name__ == "__main__":
    executable = sys.argv[1]
    check(executable, "official sample", list(map(int, SAMPLE.split())))
    check(executable, "sorted", list(range(465)))
    check(executable, "reverse", list(reversed(range(465))))
    for seed in range(5):
        values = list(range(465))
        random.Random(seed).shuffle(values)
        check(executable, f"seed={seed}", values)
