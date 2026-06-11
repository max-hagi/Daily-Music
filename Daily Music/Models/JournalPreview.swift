//
//  JournalPreview.swift
//  Daily Music
//
//  Extracts the short first-screen preview for the Today journal dock.
//

import Foundation

enum JournalPreview {
    static let fallback = "Read the story behind today's song."

    static func text(from markdown: String) -> String {
        let paragraph = markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        let stripped = stripInlineMarkdown(from: paragraph)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped.isEmpty ? fallback : stripped
    }

    private static func stripInlineMarkdown(from text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
}
