//
//  SignInView.swift
//  Daily Music
//
//  The unauthenticated landing screen. v1 fakes Sign in with Apple through the
//  mock AuthService; the real ASAuthorizationAppleIDButton flow drops in here
//  later. The "Continue as guest" button is compiled into DEBUG builds only, so
//  it can never ship to the App Store.
//

import SwiftUI

struct SignInView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: Theme.Brand.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 8) {
                Text("Daily Music")
                    .font(.dmDisplay())
                Text("One hand-picked song a day, with a story to go with it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await env.session.signInWithApple() }
                } label: {
                    HStack {
                        if env.session.isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "applelogo")
                        }
                        Text("Sign in with Apple")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(env.session.isWorking)

                #if DEBUG
                Button("Continue as guest (debug)") {
                    Task { await env.session.continueAsGuest() }
                }
                .font(.subheadline)
                .disabled(env.session.isWorking)
                #endif

                if let error = env.session.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}
