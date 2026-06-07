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

    private var pendingEmail: String? {
        env.session.pendingEmailCodeEmail
    }

    var body: some View {
        NavigationStack {
            Form {
                if pendingEmail == nil {
                    Section {
                        TextField(text: $email, prompt: Text("you@example.com").foregroundStyle(.secondary)) {
                            Text("Email address")
                        }
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
                } else if let pendingEmail {
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    } header: {
                        Text("Enter code")
                    } footer: {
                        Text("Sent to \(pendingEmail). Check your inbox (and spam).")
                    }

                    Section {
                        Button(action: verify) {
                            centeredLabel("Verify & sign in")
                        }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || env.session.isWorking)

                        Button(action: resendCode) {
                            centeredLabel("Resend code")
                        }
                        .disabled(env.session.isWorking)

                        Button("Use a different email") {
                            env.session.clearPendingEmailCode()
                            email = ""
                            code = ""
                        }
                        .foregroundStyle(.secondary)
                        .disabled(env.session.isWorking)
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
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: seedEmailFromPendingCode)
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

    private func seedEmailFromPendingCode() {
        if let pendingEmail, email.isEmpty {
            email = pendingEmail
        }
    }

    private func sendCode() {
        Task {
            _ = await env.session.sendEmailCode(to: trimmedEmail)
        }
    }

    private func resendCode() {
        guard let pendingEmail else { return }
        Task {
            _ = await env.session.sendEmailCode(to: pendingEmail)
        }
    }

    private func verify() {
        guard let pendingEmail else { return }
        Task {
            await env.session.verifyEmailCode(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                email: pendingEmail
            )
        }
    }
}
