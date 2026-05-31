//
//  CalendarMonthView.swift
//  Daily Music
//
//  A month grid for the Vault. Days that have a published entry show a filled
//  marker and are tappable (NavigationLink → EntryDetailView); empty days are
//  dimmed. Chevrons page between months.
//

import SwiftUI

struct CalendarMonthView: View {
    private let entriesByDay: [Date: DailyEntry]
    @State private var month: Date
    private let calendar = Calendar.current

    init(entries: [DailyEntry]) {
        let cal = Calendar.current
        var dict: [Date: DailyEntry] = [:]
        for entry in entries {
            dict[cal.startOfDay(for: entry.date)] = entry
        }
        self.entriesByDay = dict

        // Open on the month of the most recent entry (falls back to today).
        let anchor = entries.map(\.date).max() ?? Date()
        let monthStart = cal.dateInterval(of: .month, for: anchor)?.start ?? anchor
        _month = State(initialValue: monthStart)
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            grid
            Spacer(minLength: 0)
        }
        .padding(.vertical)
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentOrFutureMonth)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let number = calendar.component(.day, from: day)
        if let entry = entriesByDay[calendar.startOfDay(for: day)] {
            NavigationLink(value: entry) {
                VStack(spacing: 3) {
                    Text("\(number)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 32, height: 28)
                        .overlay {
                            if isToday(day) {
                                Circle().stroke(.secondary, lineWidth: 1)
                            }
                        }

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        } else {
            Text("\(number)")
                .font(.callout)
                .foregroundStyle(isToday(day) ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 40, height: 40)
                .overlay {
                    if isToday(day) {
                        Circle().stroke(.secondary, lineWidth: 1)
                    }
                }
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Date math

    /// Cells for the displayed month: leading nils to align the 1st under its
    /// weekday, then one Date per day.
    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var isCurrentOrFutureMonth: Bool {
        guard let thisMonth = calendar.dateInterval(of: .month, for: Date())?.start else { return false }
        return month >= thisMonth
    }

    private func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            month = newMonth
        }
    }
}
