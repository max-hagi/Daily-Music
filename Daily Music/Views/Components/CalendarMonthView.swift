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
    private let monthPages: [Date]
    private let onSelect: ((DailyEntry) -> Void)?
    // entryID → the emoji THIS user reacted with, so a reacted day shows the emoji
    // in place of the generic dot.
    private let reactionsByEntry: [UUID: String]
    // entryID → its ListenStatus, used to colour the day marker (optional).
    private let statusForEntry: ((DailyEntry) -> ListenStatus)?
    // Which month is on screen. @State so the chevrons can change it and redraw.
    @State private var month: Date
    private let calendar = Calendar.current

    // A CUSTOM init. Normally SwiftUI synthesizes one, but here we transform the
    // input and seed @State from a computed value.
    init(entries: [DailyEntry], reactions: [UUID: String] = [:],
         status: ((DailyEntry) -> ListenStatus)? = nil,
         onSelect: ((DailyEntry) -> Void)? = nil) {
        let cal = Calendar.current
        var dict: [Date: DailyEntry] = [:]
        for entry in entries {
            dict[cal.startOfDay(for: entry.date)] = entry
        }
        self.entriesByDay = dict
        self.reactionsByEntry = reactions
        self.statusForEntry = status
        self.onSelect = onSelect

        // Open on the current month so today's date is visible on first load.
        let today = Date()
        let monthStart = cal.dateInterval(of: .month, for: today)?.start ?? today
        let earliestMonth = entries
            .compactMap { cal.dateInterval(of: .month, for: $0.date)?.start }
            .min() ?? monthStart
        self.monthPages = Self.months(from: earliestMonth, through: monthStart, calendar: cal)
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
            monthPager
            Spacer(minLength: 0)   // push everything to the top
        }
        .padding(.vertical)
    }

    private var monthHeader: some View {
        HStack {
            // Button(action:label:) trailing-closure form: the first `{ }` is the
            // tap action, `label: { }` is what's drawn.
            Button { changeMonth(by: -1, animated: true) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            // e.g. "June 2026" — formatted directly from the Date.
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button { changeMonth(by: 1, animated: true) } label: {
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
        grid(for: month)
    }

    private var monthPager: some View {
        TabView(selection: $month) {
            ForEach(monthPages, id: \.self) { visibleMonth in
                grid(for: visibleMonth)
                    .tag(visibleMonth)
                    .padding(.horizontal, 1)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: gridHeight(for: month))
        .animation(.snappy(duration: 0.28), value: month)
    }

    private func grid(for visibleMonth: Date) -> some View {
        // 7 equal flexible columns = a week. LazyVGrid lays children into those
        // columns top-to-bottom. `.enumerated()` pairs each element with its index;
        // `id: \.offset` uses that index as identity (days can be nil, so we can't
        // use the value itself).
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(days(for: visibleMonth).enumerated()), id: \.offset) { _, day in
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
            Button {
                onSelect?(entry)
            } label: {
                VStack(spacing: 0) {
                    Text("\(number)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 32, height: 22)
                        .overlay {
                            if isToday(day) {
                                Circle().stroke(.secondary, lineWidth: 1)
                            }
                        }

                    // Marker: the emoji you reacted with, else the accent dot. Emoji
                    // glyphs can render taller than their font size, so reserve a
                    // little more vertical room while keeping every cell 40pt tall.
                    Group {
                        if let emoji = reactionsByEntry[entry.id] {
                            Text(emoji)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .fixedSize()
                        } else {
                            Circle()
                                .fill((statusForEntry?(entry).indicatorColor) ?? Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 18)
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
        days(for: month)
    }

    private func days(for visibleMonth: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstDay = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 0
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

    private func changeMonth(by value: Int, animated: Bool = false) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month),
           monthPages.contains(newMonth) {
            if animated {
                withAnimation(.snappy(duration: 0.28)) {
                    month = newMonth
                }
            } else {
                month = newMonth
            }
        }
    }

    private func gridHeight(for visibleMonth: Date) -> CGFloat {
        let rowCount = ceil(Double(days(for: visibleMonth).count) / 7.0)
        return CGFloat(rowCount) * 40 + CGFloat(max(rowCount - 1, 0)) * 8
    }

    private static func months(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        var pages: [Date] = []
        var cursor = start
        while cursor <= end {
            pages.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return pages
    }
}


