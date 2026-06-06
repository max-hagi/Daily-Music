//  FriendsView.swift — the Friends tab: add by code/QR, approve requests, see friends.
import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    @State private var enteredCode = ""
    @State private var sendError: String?
    @FocusState private var isFriendCodeFocused: Bool

    private var store: FriendsStore { env.friendsStore }

    private var friendLink: String { "dailymusic://friend/\(store.myCode)" }

    var body: some View {
        NavigationStack {
            List {
                friendsSection
                if !store.requests.isEmpty { requestsSection }
                addFriendSection
            }
            .navigationTitle("Friends")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFriendCodeFocused = false }
                }
            }
            .task {
                await store.load()
                // Prefill a code arriving via the dailymusic://friend/<code> deep link.
                if let pending = UserDefaults.standard.string(forKey: "pendingFriendCode") {
                    enteredCode = FriendCode.normalize(pending)
                    UserDefaults.standard.removeObject(forKey: "pendingFriendCode")
                }
            }
            .refreshable { await store.load() }
        }
    }

    private var addFriendSection: some View {
        Section("Add a friend") {
            HStack(spacing: 12) {
                QRCodeView(string: friendLink, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your invite")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(store.myCode)
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .tracking(3)
                }
                Spacer()
                ShareLink(item: friendLink) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(minWidth: 86, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)

            HStack {
                TextField("Enter a 6-digit code", text: $enteredCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFriendCodeFocused)
                    .onChange(of: enteredCode) { _, newValue in
                        let digits = String(newValue.filter { FriendCode.alphabet.contains($0) }.prefix(6))
                        if digits != newValue { enteredCode = digits }
                    }
                Button("Send") {
                    Task {
                        if await store.send(code: enteredCode) {
                            enteredCode = ""
                            isFriendCodeFocused = false
                        }
                        sendError = store.errorMessage
                    }
                }
                .disabled(FriendCode.normalize(enteredCode).count != 6)
            }
            if let sendError {
                Text(sendError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var requestsSection: some View {
        Section("Requests") {
            ForEach(store.requests) { request in
                HStack(spacing: 12) {
                    avatar(request.profile)
                    Text(request.profile.displayName ?? "New friend").font(.headline)
                    Spacer()
                    Button { Task { await store.respond(request, accept: true) } } label: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }.buttonStyle(.plain)
                    Button { Task { await store.respond(request, accept: false) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                .font(.title3)
            }
        }
    }

    private var friendsSection: some View {
        Section("Your friends") {
            if store.friends.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No friends yet")
                        .font(.headline)
                    Text("Share your invite to start comparing taste mirrors.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ShareLink(item: friendLink) {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(store.friends) { friend in
                    NavigationLink {
                        FriendInsightsView(friend: friend, onOpenEntry: onOpenEntry)
                    } label: {
                        HStack(spacing: 12) {
                            avatar(friend.profile, size: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.profile.displayName ?? "Friend")
                                    .font(.headline)
                                Text("Open their taste mirror")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
            }
        }
    }

    @ViewBuilder private func avatar(_ profile: UserProfile, size: CGFloat = 40) -> some View {
        if let s = profile.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: profile.displayName, size: size) }
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: profile.displayName, size: size)
        }
    }
}
