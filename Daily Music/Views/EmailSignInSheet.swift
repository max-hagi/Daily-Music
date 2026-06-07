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
            ZStack {
                LinearGradient(
                    colors: Theme.Brand.gradient.map { $0.opacity(0.28) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            if pendingEmail == nil {
                                emailStep
                            } else if let pendingEmail {
                                codeStep(for: pendingEmail)
                            }

                            if let error = env.session.errorMessage {
                                errorMessage(error)
                            }
                        }
                        .cardStyle()
                    }
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
//            .navigationTitle("Sign in with email")
//            .navigationBarTitleDisplayMode(.inline)
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

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
//            Image(systemName: pendingEmail == nil ? "envelope.fill" : "number.circle.fill")
//                .font(.system(size: 42, weight: .bold, design: .rounded))
//                .foregroundStyle(Theme.Brand.gradient[0])
//                .frame(width: 76, height: 76)
//                .background(.regularMaterial, in: Circle())

            VStack(spacing: Theme.Spacing.sm) {
                Text(pendingEmail == nil ? "Sign in with email" : "Check your inbox")
                    .font(.dmTitle())
                    .multilineTextAlignment(.center)

                Text(pendingEmail == nil ? "We'll send you a 6-digit code to get you back to your music." : "Enter the code we sent to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            fieldLabel("Email")

            TextField(text: $email, prompt: Text(verbatim: "you@example.com").foregroundStyle(.secondary)) {
                Text("Email address")
            }
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.plain)
            .font(.dmHeadline())
            .padding(Theme.Spacing.md)
            .background(fieldBackground)

            Text("We'll email you a 6-digit sign-in code.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            primaryButton("Email me a code", isDisabled: trimmedEmail.isEmpty || env.session.isWorking, action: sendCode)
        }
    }

    private func codeStep(for pendingEmail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            fieldLabel("Enter code")

            TextField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.plain)
                .font(.dmNumber())
                .multilineTextAlignment(.center)
                .padding(Theme.Spacing.md)
                .background(fieldBackground)

            Text("Sent to \(pendingEmail). Check your inbox and spam folder.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            primaryButton("Verify & sign in", isDisabled: trimmedCode.isEmpty || env.session.isWorking, action: verify)

            Button(action: resendCode) {
                secondaryLabel("Resend code")
            }
            .disabled(env.session.isWorking)

            Button {
                env.session.clearPendingEmailCode()
                email = ""
                code = ""
            } label: {
                secondaryLabel("Use a different email")
            }
            .disabled(env.session.isWorking)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.dmHeadline())
            .foregroundStyle(.primary)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .stroke(Theme.Surface.cardStroke, lineWidth: 1)
            }
    }

    private func primaryButton(_ title: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if env.session.isWorking {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.dmHeadline())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
    }

    private func errorMessage(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
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

#Preview {
    EmailSignInSheet()
        .environment(AppEnvironment.mock())
}
