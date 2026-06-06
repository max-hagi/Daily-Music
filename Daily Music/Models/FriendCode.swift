//  FriendCode.swift — pure helpers for the shareable friend code.
import Foundation

enum FriendCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// Uppercase and keep only allowed characters (for user-entered codes).
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) })
    }
}
