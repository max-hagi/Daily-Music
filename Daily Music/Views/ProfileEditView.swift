//
//  ProfileEditView.swift
//  Daily Music
//
//  The "Edit profile" sheet opened from Settings. Reuses ProfileEditor and saves
//  name + avatar through ProfileStore. Name is required to save.
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var avatarURL: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProfileEditor(displayName: $displayName, avatarURL: $avatarURL)
                    .padding(.top, 24)
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            try? await env.profileStore.save(
                                displayName: displayName.trimmingCharacters(in: .whitespaces),
                                avatarURL: avatarURL
                            )
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .task {
                await env.profileStore.load()
                displayName = env.profileStore.current?.displayName ?? ""
                avatarURL = env.profileStore.current?.avatarURL
            }
        }
    }
}
