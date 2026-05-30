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
        VStack(alignment: .leading, spacing: 16) {
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(attributed(paragraph))
                    .font(.body)
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paragraphs: [String] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }
}
