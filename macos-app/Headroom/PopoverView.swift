import SwiftUI

struct PopoverView: View {
    let model: AppModel
    let updater: Updater
    let presentation: PopoverPresentation
    @State private var showsErrors = false
    @AppStorage("showsTopProjects") private var showsTopProjects = false
    @AppStorage("popoverTab") private var tab = Tab.spend

    private enum Tab: String {
        case spend, projects
    }

    var body: some View {
        content
            .frame(width: 320)
    }

    /// Re-renders `content` every second while the popover is shown, and never while
    /// it is closed. Only the text that depends on the time goes in here, so the rest
    /// of the popover renders only when the model changes.
    private func ticking(@ViewBuilder _ content: @escaping (Date) -> some View) -> some View {
        TimelineView(PopoverClock(isActive: presentation.isShown)) { context in
            content(context.date)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            if let version = updater.pendingVersion {
                updateBanner(version: version)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            Divider()
            limits
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            Divider()
            tabs
            if !model.errors.isEmpty {
                Divider()
                errorList
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            Divider()
            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
    }

    // ─── Header ─────────────────────────────────────────────────────────────────

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Headroom")
                    .font(.headline)
                Text(model.plan.map { "Claude Code · \($0.capitalized) plan" } ?? "Claude Code usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let status = connectionStatus {
                StatusPill(label: status.label, color: status.color)
            }
        }
    }

    /// nil while the first rate-limit request is still in flight.
    private var connectionStatus: (label: String, color: Color)? {
        if !model.isConnected { return ("Not connected", .gray) }
        if let limits = model.rateLimits { return (Self.statusLabel(limits.status), Self.statusColor(limits.status)) }
        if model.rateLimitError != nil { return ("Unavailable", .gray) }
        return nil
    }

    private static func statusLabel(_ status: String) -> String {
        switch status {
        case "allowed": "Within limits"
        case "allowed_warning": "Approaching limit"
        case "rejected": "Rate limited"
        default: status
        }
    }

    private static func statusColor(_ status: String) -> Color {
        switch status {
        case "allowed_warning": .orange
        case "rejected": .red
        default: .green
        }
    }

    // ─── Usage limits ───────────────────────────────────────────────────────────

    @ViewBuilder
    private var limits: some View {
        if model.isConnected, model.rateLimitError == nil, let limits = model.rateLimits {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle(limits.fiveHourUtil == nil ? "7-day window" : "5-hour window")
                    Spacer()
                    ticking { now in peakHours(now: now) }
                }
                if let fiveHourUtil = limits.fiveHourUtil {
                    window(
                        utilization: fiveHourUtil, reset: limits.fiveHourReset,
                        tokens: model.fiveHourTokens, name: "5-hour"
                    )
                    sevenDay(limits)
                        .padding(.top, 4)
                } else {
                    // No 5-hour limit (Ultra): the 7-day window is the headline.
                    window(
                        utilization: limits.sevenDayUtil, reset: limits.sevenDayReset,
                        tokens: model.sevenDayTokens, name: "7-day"
                    )
                }
                if limits.overageUtil != 0 {
                    HStack(spacing: 6) {
                        Text("OVERAGE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.15), in: .capsule)
                        Text("\(Format.percent(limits.overageUtil)) used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    sectionTitle("Usage Limits")
                    Spacer()
                    ticking { now in peakHours(now: now) }
                }
                if !model.isConnected {
                    connectPrompt
                } else if let rateLimitError = model.rateLimitError {
                    message(Text(verbatim: rateLimitError), isError: true)
                } else {
                    message(Text("Loading…"))
                }
            }
        }
    }

    private func window(
        utilization: Double, reset: Double?, tokens: WindowTokens?, name: String
    ) -> some View {
        let left = Headroom(utilization: utilization)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(left.percent)%")
                        .font(.system(size: 32, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(left.textColor)
                    Text("left")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    ticking { now in
                        if let reset = Self.resetText(reset, now: now) {
                            Text(reset)
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                    if let tokens = Format.tokens(tokens?.total) {
                        Text("\(tokens) tokens used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HeadroomBar(headroom: left, height: 8)
                .accessibilityLabel("\(left.percent) percent of the \(name) window left")
        }
    }

    private func sevenDay(_ limits: RateLimits) -> some View {
        let left = Headroom(utilization: limits.sevenDayUtil)
        let tokens = Format.tokens(model.sevenDayTokens?.total).map { "\($0) tokens used" }
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("7-day window")
                Spacer()
                Text("\(left.percent)% left")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(left.textColor)
            }
            HeadroomBar(headroom: left, height: 4)
                .accessibilityLabel("\(left.percent) percent of the 7-day window left")
            ticking { now in
                let details = [
                    tokens,
                    Self.resetText(limits.sevenDayReset, now: now).map { $0.prefix(1).lowercased() + $0.dropFirst() },
                ].compactMap { $0 }
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// "Resets in 2h 14m", or "Resets now" once the window has rolled over.
    private static func resetText(_ epoch: Double?, now: Date) -> String? {
        guard let countdown = Format.countdown(to: epoch, now: now) else { return nil }
        return countdown == "now" ? "Resets now" : "Resets in \(countdown)"
    }

    @ViewBuilder
    private func peakHours(now: Date) -> some View {
        let peak = PeakHours.status(at: now)
        if peak.isActive {
            Text(peak.text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.14), in: .capsule)
        } else {
            Text(peak.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 8) {
            Image(nsImage: GaugeIcon.image(fill: 0))
                .renderingMode(.template)
                .resizable()
                .frame(width: 22, height: 27)
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 11))
            Text("See how much room you have left")
                .font(.headline)
            Text("Headroom reads Claude Code's sign-in from your keychain to check your 5-hour and 7-day limits. The token is never written to disk.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Connect to Claude Code") {
                Task { await model.connect() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)
            if let connectError = model.connectError {
                message(Text(verbatim: connectError), isError: true)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // ─── Spend and Projects tabs ────────────────────────────────────────────────

    private var tabs: some View {
        VStack(spacing: 12) {
            Picker("Show", selection: $tab) {
                Text("Spend").tag(Tab.spend)
                Text("Projects").tag(Tab.projects)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // Both tabs are laid out so the taller one sets the height and the popover
            // doesn't resize on every switch.
            ZStack(alignment: .top) {
                tabContent(.spend) { spend }
                tabContent(.projects) { projects }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func tabContent(_ tab: Tab, @ViewBuilder content: () -> some View) -> some View {
        let isSelected = self.tab == tab
        return content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    // ─── Spend ──────────────────────────────────────────────────────────────────

    private var spend: some View {
        let totals = model.usage?.totals
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    sectionTitle("Today")
                    Text(Format.cost(totals?.todayCost))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                HStack(spacing: 14) {
                    ticking { now in costColumn(now.formatted(.dateTime.month(.wide)), totals?.monthCost) }
                    costColumn("All time", totals?.cost)
                }
            }
            if let days = model.usage?.dailySpend, !days.isEmpty {
                SpendChart(days: days)
            }
            if let models = model.usage?.modelSpend, !models.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    sectionTitle("By model · all time")
                    ModelList(models: models)
                }
            }
        }
    }

    private func costColumn(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Format.cost(value))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
    }

    // ─── Projects ───────────────────────────────────────────────────────────────

    private var projects: some View {
        let projects = showsTopProjects ? model.usage?.topProjects : model.usage?.recentProjects
        let largest = projects?.map(\.cost).max() ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let projects, let count = model.usage?.projectCount, count > projects.count {
                    Text("\(projects.count) of \(count) projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Projects", selection: $showsTopProjects) {
                    Text("Recent").tag(false)
                    Text("Top").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
            if let projects, !projects.isEmpty {
                ticking { now in
                    ForEach(projects) { project in
                        ProjectRow(project: project, share: largest > 0 ? project.cost / largest : 0, showsTop: showsTopProjects, now: now)
                    }
                }
            } else {
                message(Text(model.usage == nil ? "—" : "No projects found"))
            }
        }
    }

    // ─── Update, errors and footer ──────────────────────────────────────────────

    private func updateBanner(version: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text("Headroom \(version) is available")
                .font(.caption)
            Spacer(minLength: 0)
            Button("Update") { updater.checkForUpdates() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: 8))
    }

    private var errorList: some View {
        DisclosureGroup(isExpanded: $showsErrors) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(model.errors, id: \.self) { error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Label(
                model.errors.count == 1 ? "1 issue detected" : "\(model.errors.count) issues detected",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.red)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r")
            .disabled(model.isRefreshing)
            .help("Refresh (⌘R)")
            .accessibilityLabel("Refresh")
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                ticking { now in
                    if let freshness = freshness(now: now) {
                        Text(freshness)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            moreMenu
        }
        // ⌘Q while the popover is key; the visible Quit lives in the ⋯ menu.
        .background {
            Button("Quit Headroom") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    /// Rate limits are what the popover leads with, and they refresh only every 15
    /// minutes, so their age is the one worth showing.
    private func freshness(now: Date) -> String? {
        if model.isConnected, let limits = model.rateLimits {
            return "Limits checked \(Format.ago(limits.fetchedAt, now: now))"
        }
        return model.updatedAt.map { "Updated \(Format.ago($0, now: now))" }
    }

    /// Mirrors the menu bar item's right-click menu.
    private var moreMenu: some View {
        Menu {
            Text("Headroom \(model.appVersion)")
            Divider()
            Button("Check for Updates…") { updater.checkForUpdates() }
            Toggle("Update Automatically", isOn: Binding(
                get: { updater.updatesAutomatically },
                set: { updater.updatesAutomatically = $0 }
            ))
            Toggle("Open at Login", isOn: Binding(
                get: { LoginItem.shared.isEnabled },
                set: { LoginItem.shared.setEnabled($0) }
            ))
            Divider()
            if model.isConnected {
                Button("Disconnect from Claude Code") {
                    Task { await model.disconnect() }
                }
            } else {
                Button("Connect to Claude Code") {
                    Task { await model.connect() }
                }
            }
            Divider()
            Button("Quit Headroom") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Version, updates and settings")
        .accessibilityLabel("More")
    }

    // ─── Pieces ─────────────────────────────────────────────────────────────────

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func message(_ text: Text, isError: Bool = false) -> some View {
        text
            .font(.caption)
            .foregroundStyle(isError ? Color.red : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The share of a rate-limit window still available, and how alarming that is.
private struct Headroom {
    /// 0...1. Utilisation can exceed 1.0 (overage) or be NaN from a garbage header.
    let fraction: Double

    init(utilization: Double) {
        fraction = utilization.isFinite ? 1 - min(1, max(0, utilization)) : 1
    }

    var percent: Int { Int((fraction * 100).rounded()) }

    var barColor: Color {
        fraction > 0.5 ? .accentColor : fraction > 0.2 ? .orange : .red
    }

    var textColor: Color {
        fraction > 0.5 ? .primary : fraction > 0.2 ? .orange : .red
    }
}

private struct HeadroomBar: View {
    let headroom: Headroom
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(headroom.barColor)
                    .frame(width: proxy.size.width * headroom.fraction)
            }
        }
        .frame(height: height)
        .accessibilityElement()
    }
}

private struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

private struct SpendChart: View {
    let days: [DailySpend]

    var body: some View {
        let peak = days.max { $0.cost < $1.cost }
        let scale = max(peak?.cost ?? 0, 0.01)
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day.id == days.last?.id ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(height: max(2, 56 * day.cost / scale))
                        .frame(maxWidth: .infinity)
                        .help("\(Format.shortDate(day.date) ?? ""): \(Format.cost(day.cost))")
                }
            }
            .frame(height: 56, alignment: .bottom)
            HStack {
                Text(Format.shortDate(days.first?.date) ?? "")
                Spacer()
                if let peak, peak.cost > 0 {
                    Text("Peak \(Format.cost(peak.cost)) · \(Format.shortDate(peak.date) ?? "")")
                }
                Spacer()
                Text("Today")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(peak: peak))
    }

    private func accessibilityText(peak: DailySpend?) -> String {
        guard let peak, peak.cost > 0 else { return "No spend in the last \(days.count) days" }
        return "Daily spend over the last \(days.count) days, highest \(Format.cost(peak.cost)) on \(Format.shortDate(peak.date) ?? "")"
    }
}

/// All-time spend by model: the top three, then everything else.
private struct ModelList: View {
    let models: [ModelSpend]

    private static let colors: [Color] = [.accentColor, .accentColor.opacity(0.45), .orange, .gray]

    private var rows: [(name: String, cost: Double, share: Double)] {
        let total = models.reduce(0) { $0 + $1.cost }
        guard total > 0 else { return [] }
        var rows = models.prefix(3).map { (name: $0.name, cost: $0.cost, share: $0.cost / total) }
        let rest = models.dropFirst(3).reduce(0) { $0 + $1.cost }
        if rest > 0 { rows.append((name: "Other", cost: rest, share: rest / total)) }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.colors[index])
                        .frame(width: 8, height: 8)
                    Text(row.name)
                        .font(.caption)
                    Spacer(minLength: 4)
                    Text(Self.percent(row.share))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(Format.cost(row.cost))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static func percent(_ share: Double) -> String {
        share < 0.005 ? "<1%" : "\(Int((share * 100).rounded()))%"
    }
}

private struct ProjectRow: View {
    let project: ProjectSummary
    /// Cost relative to the most expensive project in the list, 0...1.
    let share: Double
    /// Top projects show when they started, recent ones when they were last active.
    let showsTop: Bool
    let now: Date

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(Format.cost(project.cost))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: max(2, proxy.size.width * share))
                }
            }
            .frame(height: 2)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        let date = showsTop
            ? project.firstSeen.flatMap(Format.shortDate).map { "since \($0)" }
            : project.lastSeen.map { "active \(Format.lastActive($0, now: now))" }
        return [Format.tokens(project.totalTokens).map { "\($0) tokens" }, date]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// Ticks every second while active. Inactive, it has just the one entry it starts
/// with, so nothing re-renders while the popover is closed; turning it back on
/// restarts it from the current time.
private struct PopoverClock: TimelineSchedule {
    let isActive: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        guard isActive else { return AnyIterator(CollectionOfOne(startDate).makeIterator()) }
        return AnyIterator(PeriodicTimelineSchedule(from: startDate, by: 1).entries(from: startDate, mode: mode))
    }
}
