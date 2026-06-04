//
//  InitialsAvatar.swift
//  Daily Music
//
//  The universal avatar fallback: a name's initials on a deterministic gradient.
//  Shown anywhere a person has no uploaded photo (onboarding, Settings, and later
//  friend bubbles).
//

import SwiftUI

struct InitialsAvatar: View {
    let name: String?
    var size: CGFloat = 64

    // Each palette is a 2-color gradient. AvatarStyle picks one stably per name.
    private static let palettes: [[Color]] = [
        [Color(red: 1.00, green: 0.49, blue: 0.42), Color(red: 1.00, green: 0.37, blue: 0.49)],
        [Color(red: 0.42, green: 0.84, blue: 1.00), Color(red: 0.35, green: 0.55, blue: 1.00)],
        [Color(red: 0.78, green: 0.61, blue: 1.00), Color(red: 0.48, green: 0.36, blue: 1.00)],
        [Color(red: 0.55, green: 0.91, blue: 0.60), Color(red: 0.22, green: 0.70, blue: 0.52)],
        [Color(red: 1.00, green: 0.88, blue: 0.40), Color(red: 1.00, green: 0.66, blue: 0.30)],
        [Color(red: 1.00, green: 0.66, blue: 0.77), Color(red: 1.00, green: 0.42, blue: 0.62)]
    ]

    private var palette: [Color] {
        Self.palettes[AvatarStyle.paletteIndex(for: name, paletteCount: Self.palettes.count)]
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Text(AvatarStyle.initials(from: name))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        InitialsAvatar(name: "Maxime Save")
        InitialsAvatar(name: "Ada")
        InitialsAvatar(name: nil)
    }
    .padding()
}
