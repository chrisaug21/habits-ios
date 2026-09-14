//
//  StatsView.swift
//  Habits
//
//  Native mirror of the web app's stats.js: range toggle, total workouts,
//  streaks, consistency, workouts-by-type breakdown, and a weight trend
//  chart. Read-only — no editing happens on this screen.
//

import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel
    @State private var isOtherExpanded = false
    @State private var selectedDateLabel: String?

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 0).id(Self.topAnchor)

                    HabitsSegmentedControl(items: StatsRange.allCases, selection: $viewModel.range) { $0.label }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.red)
                    }

                    if viewModel.hasAnyWorkouts {
                        totalWorkoutsCard
                        streaksCard
                        consistencyCard
                        typeBreakdownCard
                    } else {
                        emptyStateCard
                    }

                    weightChartCard

                    HabitsVersionFooter()
                }
                .padding(16)
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle(habitsAppHeaderTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await viewModel.loadAll()
                selectDefaultWeightPoint()
            }
            .task {
                await viewModel.loadAll()
                selectDefaultWeightPoint()
            }
            .onChange(of: viewModel.range) { selectDefaultWeightPoint() }
            .overlay {
                if viewModel.isLoading && viewModel.history.isEmpty {
                    ProgressView()
                        .tint(HabitsColor.accent)
                }
            }
            // TabView keeps each tab's ScrollView position across switches
            // (the view isn't recreated) — onAppear does fire every time the
            // tab becomes visible again, so use it to reset to the top
            // rather than leaving the user wherever they last scrolled.
            .onAppear { proxy.scrollTo(Self.topAnchor, anchor: .top) }
            }
        }
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    private static let topAnchor = "top"

    // MARK: - Shared pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(HabitsColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(HabitsColor.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HabitsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func lastDoneText(_ days: Int) -> String {
        days == 0 ? "Today" : "\(days)d ago"
    }

    private func barTrack(percent: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(HabitsColor.surface)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(HabitsColor.accent)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent))) / 100)
            }
        }
        .frame(height: 8)
    }

    private var emptyStateCard: some View {
        Text("No data yet.")
            .font(.system(size: 14))
            .foregroundStyle(HabitsColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .habitsCard()
    }

    // MARK: - Total Workouts

    private var totalWorkoutsCard: some View {
        VStack(spacing: 10) {
            sectionLabel("Total Workouts")
            statTile(value: "\(viewModel.totalWorkouts)", label: totalWorkoutsSubtitle)
        }
        .habitsCard()
    }

    private var totalWorkoutsSubtitle: String {
        switch viewModel.range {
        case .seven: return "in the last 7 days"
        case .thirty: return "in the last 30 days"
        case .all: return "all time"
        }
    }

    // MARK: - Streaks

    private var streaksCard: some View {
        VStack(spacing: 10) {
            sectionLabel("Streaks")
            HStack(spacing: 12) {
                statTile(value: "\(viewModel.currentStreak)", label: "current streak")
                statTile(value: "\(viewModel.longestStreak)", label: "longest streak")
            }
        }
        .habitsCard()
    }

    // MARK: - Consistency

    private var consistencyCard: some View {
        VStack(spacing: 10) {
            sectionLabel("Consistency")
            statTile(
                value: "\(viewModel.consistencyPercent)%",
                label: "\(viewModel.consistencyDistinctDays) of \(viewModel.consistencyDenominator) days"
            )
        }
        .habitsCard()
    }

    // MARK: - Workouts by Type

    private var typeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Workouts by Type")
            VStack(spacing: 16) {
                ForEach(viewModel.typeRows) { row in
                    typeRow(row)
                }
                if !viewModel.otherEntries.isEmpty {
                    otherRow
                    if isOtherExpanded {
                        otherList
                    }
                }
            }
        }
        .habitsCard()
    }

    private func typeRow(_ row: StatsTypeRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: row.workout.icon)
                .font(.system(size: 16))
                .foregroundStyle(HabitsColor.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(row.workout.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HabitsColor.textPrimary)
                    Spacer()
                    if let days = row.daysSinceLastDone {
                        HabitsPill(text: lastDoneText(days), tone: .forDaysSince(days), showsCheck: days == 0)
                    } else {
                        HabitsPill(text: "Never", tone: .forDaysSince(nil))
                    }
                }
                barTrack(percent: row.percent)
            }
            Text("\(row.count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)
                .frame(minWidth: 22, alignment: .trailing)
        }
    }

    private var otherRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isOtherExpanded.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(HabitsColor.textSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Other")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HabitsColor.textPrimary)
                    barTrack(percent: viewModel.otherPercent)
                }
                Image(systemName: isOtherExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HabitsColor.textSecondary)
                Text("\(viewModel.otherEntries.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)
                    .frame(minWidth: 22, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
    }

    private var otherList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.otherEntries) { entry in
                HStack(alignment: .top) {
                    Text(formattedShortDate(entry.date))
                        .font(.system(size: 13))
                        .foregroundStyle(HabitsColor.textSecondary)
                    Spacer()
                    Text((entry.note?.isEmpty == false ? entry.note! : nil) ?? "Other activity")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HabitsColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.leading, 34)
    }

    private func formattedShortDate(_ dateStr: String) -> String {
        guard let date = Self.dateFormatter.date(from: dateStr) else { return dateStr }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()

    // MARK: - Weight Trend

    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            weightChartHeader
            if viewModel.weightChartPoints.isEmpty {
                Text("Not enough weight data yet for this range.")
                    .font(.system(size: 14))
                    .foregroundStyle(HabitsColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                weightChart
            }
        }
        .habitsCard()
    }

    /// Swaps to the scrubbed day's readout while a finger is down on the
    /// chart (see `weightChart`'s `chartOverlay`), matching the web app's
    /// hover tooltip — reverts to the plain section label on release.
    private var weightChartHeader: some View {
        Group {
            if let point = selectedWeightPoint {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DATE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(HabitsColor.textSecondary)
                        Text(point.dateLabel)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(HabitsColor.textPrimary)
                    }
                    .frame(minWidth: 56, alignment: .leading)
                    weightStat("Weight", point.raw, color: HabitsColor.coral)
                    weightStat("7-day avg", point.rollingAverage, color: HabitsColor.accent)
                    weightStat("Trend", point.trend, color: HabitsColor.textPrimary)
                }
            } else {
                sectionLabel("Weight Trend")
            }
        }
        .animation(.easeOut(duration: 0.12), value: selectedDateLabel)
    }

    private func weightStat(_ title: String, _ value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(HabitsColor.textSecondary)
            Text(formattedWeight(value))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
        }
        // Fixed width so the row doesn't shift when a value's digit count
        // changes (e.g. "151 lbs" vs "153.6 lbs").
        .frame(minWidth: 68, alignment: .leading)
    }

    private func formattedWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + " lbs"
    }

    private var selectedWeightPoint: WeightChartPoint? {
        guard let selectedDateLabel else { return nil }
        return viewModel.weightChartPoints.first { $0.dateLabel == selectedDateLabel }
    }

    /// Shows the most recent day's numbers up front — the most useful
    /// reading at a glance — rather than making the user tap first.
    private func selectDefaultWeightPoint() {
        selectedDateLabel = viewModel.weightChartPoints.last?.dateLabel
    }

    private var weightChart: some View {
        let points = viewModel.weightChartPoints
        let allValues = points.flatMap { [$0.raw, $0.rollingAverage, $0.trend] }
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 0
        let spread = maxValue - minValue
        let buffer = max(1.5, spread * 0.12)

        return Chart(points) { point in
            PointMark(x: .value("Date", point.dateLabel), y: .value("Weight", point.raw))
                .foregroundStyle(HabitsColor.coral)
                .symbolSize(24)
            // `foregroundStyle(by:)` + `chartForegroundStyleScale` below is
            // the pattern Swift Charts needs to treat these as two distinct
            // lines — distinguishing them only by the y-value's label (as
            // two plain `.foregroundStyle(Color)` LineMarks) silently drops
            // one of them instead of drawing both.
            LineMark(x: .value("Date", point.dateLabel), y: .value("Value", point.rollingAverage))
                .foregroundStyle(by: .value("Series", "7-day average"))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Date", point.dateLabel), y: .value("Value", point.trend))
                .foregroundStyle(by: .value("Series", "Trend"))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            if point.dateLabel == selectedDateLabel {
                RuleMark(x: .value("Date", point.dateLabel))
                    .foregroundStyle(HabitsColor.textSecondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartForegroundStyleScale([
            "7-day average": HabitsColor.accent,
            "Trend": HabitsColor.textPrimary,
        ])
        .chartYScale(domain: (minValue - buffer)...(maxValue + buffer))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: xAxisTickLabels(points)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel().foregroundStyle(HabitsColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(HabitsColor.border)
                AxisValueLabel().foregroundStyle(HabitsColor.textSecondary)
            }
        }
        .frame(height: 200)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        // `minimumDistance: 0` makes a plain tap register as
                        // a zero-length drag, so this also handles scrubbing
                        // across days without lifting a finger. Selection
                        // persists after release (tap a different day, or
                        // switch ranges, to change/clear it) rather than
                        // hiding on touch-up, matching "tap to see a day."
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let originX = geometry[plotFrame].origin.x
                                let x = value.location.x - originX
                                if let label: String = proxy.value(atX: x) {
                                    selectedDateLabel = label
                                }
                            }
                    )
            }
        }
    }

    /// Picks up to 5 evenly-spaced labels to show, mirroring Chart.js's
    /// `maxTicksLimit: 5` — a categorical axis doesn't support `.stride`,
    /// so this is done by hand. Divides the range into (picks + 1) equal
    /// segments and only takes the *interior* boundaries, so every pick
    /// keeps a full segment's worth of margin from both edges — a single
    /// index of margin wasn't enough for larger datasets, where that
    /// still landed close enough to the edge for the label to get
    /// truncated; better to leave a visible gap than show a clipped date.
    private func xAxisTickLabels(_ points: [WeightChartPoint]) -> [String] {
        let labels = points.map(\.dateLabel)
        guard labels.count > 2 else { return labels }
        let picks = min(5, labels.count - 2)
        guard picks > 0 else { return [] }
        return (1...picks).map { i in
            let idx = Int((Double(i) * Double(labels.count - 1) / Double(picks + 1)).rounded())
            return labels[idx]
        }
    }
}
