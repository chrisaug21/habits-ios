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

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await viewModel.loadAll()
            }
            .task {
                await viewModel.loadAll()
            }
            .overlay {
                if viewModel.isLoading && viewModel.history.isEmpty {
                    ProgressView()
                        .tint(HabitsColor.accent)
                }
            }
        }
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

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
            sectionLabel("Weight Trend")
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

    private var weightChart: some View {
        let points = viewModel.weightChartPoints
        let allValues = points.flatMap { [$0.raw, $0.rollingAverage, $0.trend] }
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 0
        let spread = maxValue - minValue
        let buffer = max(1.5, spread * 0.12)

        return Chart(points) { point in
            PointMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.raw))
                .foregroundStyle(HabitsColor.coral)
                .symbolSize(24)
            LineMark(x: .value("Date", point.date, unit: .day), y: .value("7-day average", point.rollingAverage))
                .foregroundStyle(HabitsColor.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Date", point.date, unit: .day), y: .value("Trend", point.trend))
                .foregroundStyle(HabitsColor.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: (minValue - buffer)...(maxValue + buffer))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(HabitsColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(HabitsColor.border)
                AxisValueLabel().foregroundStyle(HabitsColor.textSecondary)
            }
        }
        .frame(height: 200)
    }
}
