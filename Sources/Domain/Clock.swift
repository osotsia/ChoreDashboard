import Foundation

/// Defines an injectable time provider to decouple domain calculations from continuous wall-clock time.
public protocol Clock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

/// Standard production clock utilizing system wall-clock time.
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
    public var calendar: Calendar { Calendar.current }
}

/// Deterministic clock for testing time shifts and midnight rollovers.
public struct TestClock: Clock {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date = Date(), calendar: Calendar = Calendar.current) {
        self.now = now
        self.calendar = calendar
    }

    public mutating func advance(byDays days: Int) {
        self.now = calendar.date(byAdding: .day, value: days, to: now) ?? now
    }

    public mutating func advance(byMinutes minutes: Int) {
        self.now = calendar.date(byAdding: .minute, value: minutes, to: now) ?? now
    }
}