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
    // Pre-indexed lookup: day (midnight) → entry, so each cell can ask "is there
    // an entry for this day?" in O(1) instead of scanning the array.
    private let entriesByDay: [Date: DailyEntry]
    // Which month is on screen. @State so the chevrons can change it and redraw.
    @State private var month: Date
    private let calendar = Calendar.current

    // A CUSTOM init. Normally SwiftUI synthesizes one, but here we transform the
    // input and seed @State from a computed value.
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
        // To initialize an @State from init you assign its UNDERSCORE-prefixed
        // backing storage directly: `_month = State(initialValue:)`. (You can't
        // write `month = …` here because the wrapper isn't set up yet.)
        _month = State(initialValue: monthStart)
    }

    // `body` composes named sub-views (defined below) for readability — SwiftUI
    // treats `monthHeader`, `grid`, etc. just like inline views.
    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            grid
            Spacer(minLength: 0)   // push everything to the top
        }
        .padding(.vertical)
    }

    private var monthHeader: some View {
        HStack {
            // Button(action:label:) trailing-closure form: the first `{ }` is the
            // tap action, `label: { }` is what's drawn.
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            // e.g. "June 2026" — formatted directly from the Date.
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentOrFutureMonth)   // can't page into the future
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)   // applies to BOTH buttons (modifier on the HStack)
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
        // 7 equal flexible columns = a week. LazyVGrid lays children into those
        // columns top-to-bottom. `.enumerated()` pairs each element with its index;
        // `id: \.offset` uses that index as identity (days can be nil, so we can't
        // use the value itself).
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)            // a real day
                } else {
                    Color.clear.frame(height: 44)   // leading blank to align the 1st
                }
            }
        }
    }

    // @ViewBuilder on a FUNCTION lets it contain the if/else and return either
    // branch as the view. Returns a tappable cell for days with an entry, a dimmed
    // number otherwise.
    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let number = calendar.component(.day, from: day)   // day-of-month integer
        if let entry = entriesByDay[calendar.startOfDay(for: day)] {
            // NavigationLink(value:) is the modern data-driven nav: tapping pushes
            // a value, and a `.navigationDestination(for:)` elsewhere decides what
            // screen that value opens (see VaultView). The entry must be Hashable.
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
        // How many blank cells before the 1st so it sits under the right weekday
        // column. The `+ 7) % 7` keeps the result in 0...6 regardless of which day
        // the user's calendar starts the week on (firstWeekday).
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        // Start with the blanks, then append one Date per day of the month.
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }

    // Weekday header labels (S M T W…), rotated so they start on the user's
    // firstWeekday. The slice trick `symbols[shift...] + symbols[..<shift]` moves
    // the front items to the back.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    // True if the displayed month is this month or later → disables the "next" chevron.
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
