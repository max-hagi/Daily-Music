//
//  JournalText.swift
//  Daily Music
//
//  Renders the journal entry's Markdown. SwiftUI's Text only applies *inline*
//  Markdown (bold/italic), not paragraph breaks, so we split on blank lines and
//  render each paragraph as its own Text — preserving the author's spacing.
//

import SwiftUI

struct JournalText: View {
    let markdown: String

    var body: some View {
        // VStack = vertical stack. ForEach builds one Text per paragraph. `id: \.self`
        // tells SwiftUI to identify each row by the string itself (fine since the
        // strings are distinct) — ForEach needs a stable identity for every item.
        VStack(alignment: .leading, spacing: 16) {
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(attributed(paragraph))
                    .font(.body)
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)   // left-align, fill width
    }

    // Split the raw text on blank lines into trimmed, non-empty paragraphs.
    // (Chained array ops: components → map(trim) → filter(non-empty).)
    private var paragraphs: [String] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // Parse one paragraph's inline Markdown (**bold**, *italic*) into an
    // AttributedString. `.inlineOnlyPreservingWhitespace` keeps spaces and ignores
    // block syntax. `try?` + `?? AttributedString(text)` = if parsing fails, just
    // show the plain text rather than nothing.
    private func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }
}
