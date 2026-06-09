//
//  FriendInsightsView.swift
//  Daily Music
//
//  A friend's taste, read-only. Pushed from the Friends tab. Shows a "taste match"
//  card (how much you agree, songs you both love, songs you clash on) above their
//  full mirror — rendered by the same TasteMirrorBoard your own Insights uses.
//

import SwiftUI

struct FriendInsightsView: View {
    let friend: Friend
    var onOpenEntry: (DailyEntry) -> Void = { _ in }

    @Environment(AppEnvironment.self) private var env
    @State private var model: FriendInsightsViewModel?
    @State private var expandedMatchSection: MatchSection?

    private var name: String { friend.profile.displayName ?? "Friend" }

    private enum MatchSection: Hashable {
        case bothLoved
        case clashed
    }

    var body: some View {
        Group {
            if let model {
                LoadStateView(
                    state: model.state,
                    emptyTitle: "No taste yet",
                    emptyMessage: "They haven't rated enough songs.",
                    onRetry: { await model.load(friendID: friend.profile.id) }
                ) { result in
                    content(result)
                }
            } else {
                MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .background(wash)
        .task {
            if model == nil {
                model = FriendInsightsViewModel(entries: env.entries, ratings: env.ratings, friends: env.friends)
            }
            await model?.load(friendID: friend.profile.id)
        }
    }

    private func content(_ result: FriendInsightsViewModel.Result) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                matchCard(result.comparison)
                TasteMirrorBoard(mirror: result.mirror, isCurrentUser: false)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text("Their taste mirror")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            headerNudgeButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerNudgeButton: some View {
        let nudgeStore = env.friendNudgeStore

        return Button {
            Task { await nudgeStore.send(to: friend) }
        } label: {
            Label(
                nudgeStore.buttonTitle(for: friend),
                systemImage: nudgeStore.iconName(for: friend)
            )
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(nudgeStore.isDisabled(for: friend))
        .accessibilityHint("Send a push notification encouraging them to check Daily Music")
    }

    @ViewBuilder private var avatar: some View {
        if let s = friend.profile.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: friend.profile.displayName, size: 52) }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: friend.profile.displayName, size: 52)
        }
    }

    // MARK: taste-match card

    private func matchCard(_ c: TasteComparison) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let pct = c.matchPercent {
                Text("\(pct)% match")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("You agree on \(c.agreedCount) of \(c.coRatedCount) songs you've both rated.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Taste match")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text("Not enough shared ratings yet — rate more of the same songs to compare.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !c.bothLoved.isEmpty {
                expandableCoverStack(
                    section: .bothLoved,
                    title: "You both love",
                    systemImage: "heart.fill",
                    tint: .pink,
                    entries: c.bothLoved
                )
            }
            if !c.clashed.isEmpty {
                expandableCoverStack(
                    section: .clashed,
                    title: "You clash on",
                    systemImage: "bolt.fill",
                    tint: .orange,
                    entries: c.clashed
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
    }

    /// Compact match rows expand into a horizontally scrollable run of songs.
    private func expandableCoverStack(
        section: MatchSection,
        title: String,
        systemImage: String,
        tint: Color,
        entries: [DailyEntry]
    ) -> some View {
        let isExpanded = expandedMatchSection == section

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleMatchSection(section, isExpanded: isExpanded)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Label("\(title) · \(entries.count)", systemImage: systemImage)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(tint)

                        Spacer(minLength: 0)

                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(isExpanded ? tint.opacity(0.85) : .secondary.opacity(0.75))
                            .accessibilityHidden(true)
                    }

                    if !isExpanded {
                        coverPile(entries)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(entries.count) songs")
            .accessibilityHint(isExpanded ? "Collapse songs" : "Expand songs")

            if isExpanded {
                matchSongScroller(entries, tint: tint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 2)
        .animation(.snappy(duration: 0.28), value: isExpanded)
    }

    private func toggleMatchSection(_ section: MatchSection, isExpanded: Bool) {
        withAnimation(.snappy(duration: 0.28)) {
            expandedMatchSection = isExpanded ? nil : section
        }
        Haptics.tap()
    }

    private func coverPile(
        _ entries: [DailyEntry],
        cap: Int = 5,
        size: CGFloat = 46
    ) -> some View {
        let shown = Array(entries.prefix(cap))
        let overflow = entries.count - shown.count
        return HStack(spacing: 10) {
            HStack(spacing: -size * 0.34) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { idx, entry in
                    AlbumArtView(url: entry.albumArtURL, cornerRadius: 10)
                        .frame(width: size, height: size)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .zIndex(Double(shown.count - idx))
                }
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func matchSongScroller(_ entries: [DailyEntry], tint: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(entries) { entry in
                    Button {
                        onOpenEntry(entry)
                    } label: {
                        matchSongCard(entry, tint: tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Calendar.current.isDateInToday(entry.date) ? "Open today's song" : "Open in Vault")
                }
            }
            .padding(.vertical, 2)
            .padding(.trailing, Theme.Spacing.md)
        }
    }

    private func matchSongCard(_ entry: DailyEntry, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumArtView(url: entry.albumArtURL, cornerRadius: 12)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(entry.artist)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 108, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }

    // MARK: wash (friend's archetype color)

    private var wash: some View {
        let c = washColors
        return LinearGradient(
            colors: [c[0].opacity(0.55),
                     (c.count > 1 ? c[1] : c[0]).opacity(0.22),
                     Color(.systemBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var washColors: [Color] {
        if case .loaded(let r) = model?.state { return (r.mirror.archetype ?? .theShapeshifter).colors }
        return TasteProfile.theShapeshifter.colors
    }
}
