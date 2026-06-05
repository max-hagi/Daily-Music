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
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProfileEditor(displayName: $displayName, avatarURL: $avatarURL)
                    .padding(.top, 24)
                if let saveError {
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
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
                        saveError = nil
                        Task {
                            do {
                                try await env.profileStore.save(
                                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    avatarURL: avatarURL
                                )
                                dismiss()
                            } catch {
                                saveError = "Couldn't save your profile. Check your connection and try again."
                            }
                            isSaving = false
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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
