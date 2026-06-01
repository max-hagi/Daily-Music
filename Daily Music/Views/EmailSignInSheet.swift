//
//  EmailSignInSheet.swift
//  Daily Music
//
//  Email magic-link sign-in via a 6-digit code: enter email → receive a code →
//  enter it → signed in. The code flow avoids any deep-link / URL-scheme setup.
//

import SwiftUI

struct EmailSignInSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false

    var body: some View {
        NavigationStack {
            Form {
                if !codeSent {
                    Section {
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Email")
                    } footer: {
                        Text("We'll email you a 6-digit sign-in code.")
                    }

                    Section {
                        Button(action: sendCode) {
                            centeredLabel("Email me a code")
                        }
                        .disabled(trimmedEmail.isEmpty || env.session.isWorking)
                    }
                } else {
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    } header: {
                        Text("Enter code")
                    } footer: {
                        Text("Sent to \(trimmedEmail). Check your inbox (and spam).")
                    }

                    Section {
                        Button(action: verify) {
                            centeredLabel("Verify & sign in")
                        }
                        .disabled(code.isEmpty || env.session.isWorking)

                        Button("Use a different email") {
                            codeSent = false
                            code = ""
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                if let error = env.session.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in with email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // Verifying sets the session; close the sheet the moment we're signed in.
        .onChange(of: env.session.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func centeredLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if env.session.isWorking {
                ProgressView()
            } else {
                Text(title).fontWeight(.semibold)
            }
            Spacer()
        }
    }

    private func sendCode() {
        Task {
            if await env.session.sendEmailCode(to: trimmedEmail) {
                codeSent = true
            }
        }
    }

    private func verify() {
        Task {
            await env.session.verifyEmailCode(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                email: trimmedEmail
            )
        }
    }
}
