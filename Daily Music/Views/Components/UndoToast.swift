//
//  UndoToast.swift
//  Daily Music
//
//  A small reusable "Removed · Undo" banner. The host view owns the state (what
//  was removed + an auto-dismiss timer) and overlays this at the bottom; tapping
//  Undo calls back. Deliberately simple — no global toast system.
//

import SwiftUI

struct UndoBanner: View {
    let message: String
    var actionTitle: String = "Undo"
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text(actionTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.Brand.gradient[0])
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 20)
    }
}
