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
    /// When true, show a "required" hint under the name field (used by onboarding,
    /// where the name is mandatory). Settings' edit-profile leaves this off.
    var nameRequired: Bool = false

    private var nameIsBlank: Bool {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            AvatarPickerView(avatarURL: $avatarURL,
                             displayName: displayName.isEmpty ? nil : displayName)
            VStack(spacing: 6) {
                TextField("Your name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                if nameRequired {
                    HStack(spacing: 3) {
                        Text("*").foregroundStyle(.red)
                        Text("Required").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .opacity(nameIsBlank ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: nameIsBlank)
                    .accessibilityHidden(!nameIsBlank)
                }
            }
        }
    }
}
