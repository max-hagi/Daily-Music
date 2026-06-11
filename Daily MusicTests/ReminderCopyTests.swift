import Foundation
import Testing
@testable import Daily_Music

struct ReminderCopyTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 8))!
    }

    @Test func nextReminderCarriesTheStreak() {
        let content = ReminderCopy.content(
            for: date(month: 6, day: 10), isNextReminder: true, streak: 12, calendar: calendar
        )
        #expect(content.title.contains("12-day streak"))
    }

    @Test func laterRemindersNeverBakeInAStaleStreak() {
        let content = ReminderCopy.content(
            for: date(month: 6, day: 14), isNextReminder: false, streak: 12, calendar: calendar
        )
        #expect(!content.title.contains("streak"))
    }

    @Test func tinyStreaksGetGenericCopy() {
        // A "1-day streak on the line" reads as parody, not motivation.
        let content = ReminderCopy.content(
            for: date(month: 6, day: 10), isNextReminder: true, streak: 1, calendar: calendar
        )
        #expect(!content.title.contains("streak"))
    }

    @Test func copyRotatesAcrossConsecutiveDays() {
        let first = ReminderCopy.content(
            for: date(month: 6, day: 10), isNextReminder: false, streak: nil, calendar: calendar
        )
        let second = ReminderCopy.content(
            for: date(month: 6, day: 11), isNextReminder: false, streak: nil, calendar: calendar
        )
        #expect(first != second)
    }

    @Test func rotationIsDeterministicForTheSameDay() {
        // Re-scheduling on every app open must not shuffle a given day's copy.
        let a = ReminderCopy.content(
            for: date(month: 6, day: 10), isNextReminder: false, streak: nil, calendar: calendar
        )
        let b = ReminderCopy.content(
            for: date(month: 6, day: 10), isNextReminder: false, streak: nil, calendar: calendar
        )
        #expect(a == b)
    }

    @Test func journalPreviewUsesFirstNonEmptyParagraphAndStripsMarkdown() {
        let markdown = """

        **Tonight** starts with a bassline that feels like a streetlight turning on.

        The second paragraph should not be part of the preview.
        """

        #expect(JournalPreview.text(from: markdown) == "Tonight starts with a bassline that feels like a streetlight turning on.")
    }

    @Test func journalPreviewFallsBackWhenMarkdownIsEmpty() {
        #expect(JournalPreview.text(from: "   \n\n ") == "Read the story behind today's song.")
    }
}
