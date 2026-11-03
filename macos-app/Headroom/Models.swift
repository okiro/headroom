import Foundation

/// Utilisation read from the `anthropic-ratelimit-unified-*` response headers.
struct RateLimits: Codable, Equatable, Sendable {
    var status: String
    /// Nil when the plan has no 5-hour limit (Ultra): the API then sends no `5h-*` headers.
    var fiveHourUtil: Double?
    /// Epoch seconds at which the 5-hour window resets.
    var fiveHourReset: Double?
    var sevenDayUtil: Double
    /// Epoch seconds at which the 7-day window resets.
    var sevenDayReset: Double?
    var overageUtil: Double
    var fetchedAt: Date
}

/// Tokens summed from local JSONL entries inside one rate-limit window.
struct WindowTokens: Codable, Equatable, Sendable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0

    var total: Int { input + output }
}

struct TimeWindow: Sendable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool { date >= start && date <= end }
}

struct UsageTotals: Codable, Equatable, Sendable {
    var cost = 0.0
    var inputTokens = 0
    var outputTokens = 0
    var cacheRead = 0
    var cacheWrite = 0
    var sessions = 0
    var todayCost = 0.0
    var monthCost = 0.0
}

struct ProjectSummary: Codable, Equatable, Identifiable, Sendable {
    /// The encoded directory name under ~/.claude/projects.
    var id: String
    var name: String
    var cost: Double
    var firstSeen: Date?
    var lastSeen: Date?
    var totalTokens: Int
}

/// One local calendar day of spend, for the popover's bar chart.
struct DailySpend: Codable, Equatable, Identifiable, Sendable {
    /// Start of the day in the local time zone.
    var date: Date
    var cost: Double

    var id: Date { date }
}

/// All-time spend on one model, keyed by its display name ("Opus 5.5").
struct ModelSpend: Codable, Equatable, Identifiable, Sendable {
    var name: String
    var cost: Double

    var id: String { name }
}

struct UsageSummary: Codable, Equatable, Sendable {
    var totals = UsageTotals()
    var recentProjects: [ProjectSummary] = []
    var topProjects: [ProjectSummary] = []
    /// Every project with any spend, of which the two lists show the first few.
    var projectCount = 0
    /// The last 14 days, oldest first, today last; days without usage are zero.
    var dailySpend: [DailySpend] = []
    /// Highest spend first.
    var modelSpend: [ModelSpend] = []
}

extension UsageSummary {
    /// Tolerates a dashboard cache written before `projectCount`, `dailySpend` and
    /// `modelSpend` existed.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totals = try container.decode(UsageTotals.self, forKey: .totals)
        recentProjects = try container.decode([ProjectSummary].self, forKey: .recentProjects)
        topProjects = try container.decode([ProjectSummary].self, forKey: .topProjects)
        projectCount = try container.decodeIfPresent(Int.self, forKey: .projectCount) ?? 0
        dailySpend = try container.decodeIfPresent([DailySpend].self, forKey: .dailySpend) ?? []
        modelSpend = try container.decodeIfPresent([ModelSpend].self, forKey: .modelSpend) ?? []
    }
}
