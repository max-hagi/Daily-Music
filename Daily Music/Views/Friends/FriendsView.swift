//  FriendsView.swift — the Friends tab: add by code/QR, approve requests, see friends.
import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    @State private var enteredCode = ""
    @State private var showShare = false
    @State private var sendError: String?
    @FocusState private var isFriendCodeFocused: Bool

    private var store: FriendsStore { env.friendsStore }

    private var friendLink: String { "dailymusic://friend/\(store.myCode)" }

    var body: some View {
        NavigationStack {
            List {
                addFriendSection
                if !store.requests.isEmpty { requestsSection }
                friendsSection
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
            .sheet(isPresented: $showShare) {
                ShareLink(item: friendLink) { Label("Share your invite", systemImage: "square.and.arrow.up") }
                    .padding()
                    .presentationDetents([.height(120)])
            }
        }
    }

    private var addFriendSection: some View {
        Section("Add a friend") {
            VStack(spacing: 14) {
                QRCodeView(string: friendLink, size: 170)
                Text(store.myCode)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .tracking(4)
                Button { showShare = true } label: {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

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
                Text("No friends yet — share your code to get started.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.friends) { friend in
                    NavigationLink {
                        FriendInsightsView(friend: friend, onOpenEntry: onOpenEntry)
                    } label: {
                        HStack(spacing: 12) {
                            avatar(friend.profile)
                            Text(friend.profile.displayName ?? "Friend").font(.headline)
                            Spacer()
                        }
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
            }
        }
    }

    @ViewBuilder private func avatar(_ profile: UserProfile) -> some View {
        if let s = profile.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: profile.displayName, size: 40) }
                .frame(width: 40, height: 40).clipShape(Circle())
        } else {
            InitialsAvatar(name: profile.displayName, size: 40)
        }
    }
}
