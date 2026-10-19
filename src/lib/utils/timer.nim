include ../header

# 計算量: 初期化・reset・時刻取得・ratio・expired はすべて O(1)。
when not declared TimeModule:
    const TimeModule = true

    type Timer = object
        startTicks: int64

    proc initTimer(): Timer =
        result.startTicks = getMonoTime().ticks()

    proc reset(self: var Timer) =
        self.startTicks = getMonoTime().ticks()

    proc getTimeNs(self: Timer): int64 =
        getMonoTime().ticks() - self.startTicks

    proc getTime(self: Timer): float =
        self.getTimeNs.float / 1_000_000_000.0

    proc elapsedNs(self: Timer): int64 =
        self.getTimeNs

    proc elapsedSec(self: Timer): float =
        self.getTime

    proc ratio(self: Timer, timeLimitSec: float): float =
        when defined(debug):
            assert timeLimitSec > 0.0, "Timer time limit must be positive"
        self.getTime / timeLimitSec

    proc expired(self: Timer, timeLimitSec: float): bool =
        self.getTime >= timeLimitSec
