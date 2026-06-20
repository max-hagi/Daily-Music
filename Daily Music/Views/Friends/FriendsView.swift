//  FriendsView.swift — the Friends tab: an art-directed activity feed.
//  A gradient wash sits behind a plain List with clear rows, so the screen
//  matches the rest of the app while keeping swipe-to-remove + keyboard handling.
//  Zones: invite card → activity feed (friends loved/passed recent drops) →
//  requests → friends (with taste-match bars). Friends' badges/streaks are Phase 2.
import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    @State private var enteredCode = ""
    @State private var sendError: String?
    @FocusState private var isFriendCodeFocused: Bool

    private var store: FriendsStore { env.friendsStore }
    private var activity: FriendsActivityStore { env.friendsActivityStore }

    private var friendLink: String { "dailymusic://friend/\(store.myCode)" }

    var body: some View {
        NavigationStack {
            List {
                inviteSection
                if !activity.items.isEmpty { activitySection }
                if !store.requests.isEmpty { requestsSection }
                friendsSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(wash)
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
                await activity.load()
                if let pending = UserDefaults.standard.string(forKey: "pendingFriendCode") {
                    enteredCode = FriendCode.normalize(pending)
                    UserDefaults.standard.removeObject(forKey: "pendingFriendCode")
                }
            }
            .refreshable {
                await store.load()
                await activity.load()
            }
        }
    }

    // Clear-background row helper so every section reads as floating cards on the wash.
    private func clearRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    // MARK: invite

    private var inviteSection: some View {
        Section {
            clearRow {
                VStack(spacing: Theme.Spacing.md) {
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
                                .font(.subheadline.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack {
                        TextField("Enter a 6-character code", text: $enteredCode)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFriendCodeFocused)
                            .onChange(of: enteredCode) { _, newValue in
                                let cleaned = String(FriendCode.normalize(newValue).prefix(6))
                                if cleaned != newValue { enteredCode = cleaned }
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
                .padding(Theme.Spacing.md)
                .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.Surface.cardStroke, lineWidth: 1)
                }
            }
        }
    }

    // MARK: activity feed

    private var activitySection: some View {
        Section {
            ForEach(activity.items) { item in
                clearRow {
                    FriendActivityRow(item: item, onOpenEntry: onOpenEntry)
                }
            }
        } header: {
            sectionHeader("Activity")
        }
    }

    // MARK: requests

    private var requestsSection: some View {
        Section {
            ForEach(store.requests) { request in
                clearRow {
                    HStack(spacing: 12) {
                        avatar(request.profile)
                        Text(request.profile.displayName ?? "New friend").font(.headline)
                        Spacer()
                        Button { Task { await store.respond(request, accept: true) } } label: {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }.buttonStyle(.plain)
                        Button { Task { await store.respond(request, accept: false) } } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                }
            }
        } header: {
            sectionHeader("Requests")
        }
    }

    // MARK: friends

    private var friendsSection: some View {
        Section {
            if store.friends.isEmpty {
                clearRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No friends yet").font(.headline)
                        Text("Share your invite to start comparing taste mirrors.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ShareLink(item: friendLink) {
                            Label("Share invite", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            } else {
                ForEach(store.friends) { friend in
                    clearRow {
                        HStack(spacing: 12) {
                            NavigationLink {
                                FriendInsightsView(friend: friend, onOpenEntry: onOpenEntry)
                            } label: {
                                friendRowLabel(friend)
                            }
                            nudgeButton(friend)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) { Task { await store.remove(friend) } }
                    }
                }
            }
        } header: {
            sectionHeader("Your friends")
        }
    }

    private func friendRowLabel(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            avatar(friend.profile, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.profile.displayName ?? "Friend").font(.headline)
                if let pct = activity.matchByFriend[friend.profile.id] {
                    matchBar(pct)
                } else {
                    Text("Open their taste mirror")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func matchBar(_ pct: Int) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Surface.subtleTrack)
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 7)
            Text("\(pct)%")
                .font(.caption.weight(.bold)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(pct) percent taste match")
    }

    private func nudgeButton(_ friend: Friend) -> some View {
        let nudgeStore = env.friendNudgeStore
        return Button {
            Task { await nudgeStore.send(to: friend) }
        } label: {
            Label(nudgeStore.buttonTitle(for: friend), systemImage: nudgeStore.iconName(for: friend))
                .font(.caption.weight(.semibold))
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(nudgeStore.isDisabled(for: friend))
        .accessibilityLabel("Nudge \(friend.profile.displayName ?? "friend")")
        .accessibilityHint("Send a push notification encouraging them to check Daily Music")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    private var wash: some View {
        LinearGradient(
            colors: [
                Theme.Brand.gradient[0].opacity(0.30),
                Color(.systemBackground).opacity(0.95),
                Theme.Brand.gradient[1].opacity(0.16)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
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
