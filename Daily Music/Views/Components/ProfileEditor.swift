//
//  ProfileEditor.swift
//  Daily Music
//
//  The shared avatar + name control, reused by onboarding's first step and the
//  Settings "Edit profile" sheet. It edits bindings only — the parent decides
//  when to persist (Continue / Save).
//

import SwiftUI

struct ProfileEditor: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?

    var body: some View {
        VStack(spacing: 20) {
            AvatarPickerView(avatarURL: $avatarURL,
                             displayName: displayName.isEmpty ? nil : displayName)
            TextField("Your name", text: $displayName)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
        }
    }
}
