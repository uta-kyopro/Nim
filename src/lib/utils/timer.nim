include ../header

when not declared TimeModule:
    const TimeModule = true

    type Timer = object
        startTicks: int64

    proc initTimer(): Timer {.inline.} =
        result.startTicks = getMonoTime().ticks()

    proc reset(self: var Timer) {.inline.} =
        self.startTicks = getMonoTime().ticks()

    proc getTimeNs(self: Timer): int64 {.inline.} =
        getMonoTime().ticks() - self.startTicks

    proc getTime(self: Timer): float {.inline.} =
        self.getTimeNs.float / 1_000_000_000.0

    proc elapsedNs(self: Timer): int64 {.inline.} =
        self.getTimeNs

    proc elapsedSec(self: Timer): float {.inline.} =
        self.getTime

    proc ratio(self: Timer, timeLimitSec: float): float {.inline.} =
        when defined(debug):
            assert timeLimitSec > 0.0, "Timer time limit must be positive"
        self.getTime / timeLimitSec

    proc expired(self: Timer, timeLimitSec: float): bool {.inline.} =
        self.getTime >= timeLimitSec
