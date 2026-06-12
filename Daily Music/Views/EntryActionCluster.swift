//
//  EntryActionCluster.swift
//  Daily Music
//
//  The favorite + rating + reaction + info controls for EntryDetailView, in
//  full-size and compact variants. Split out of EntryDetailView.swift; the
//  shared state lives there.
//

import SwiftUI

// MARK: - Action cluster (favorite + rating + info)

extension EntryDetailView {
    func toggleFavourite() {
        Haptics.tap()
        Task {
            await env.favoritesStore.toggle(entry)
        }
    }

    /// Save is offered when ANY connected service can write to its library
    /// (Apple Music needs a subscription; Spotify needs a linked account).
    private var canSaveToLibrary: Bool {
        env.librarySaveService != nil
    }

    private func saveToLibrary() {
        guard let service = env.librarySaveService,
              !env.savedTracks.isSaved(entry) else { return }
        Haptics.tap()
        Task {
            do {
                try await service.saveToLibrary(entry)
                env.savedTracks.markSaved(entry)
            } catch {
                if case SpotifyLibraryAPI.APIError.notAllowlisted = error {
                    saveErrorMessage = "This Spotify app is in development mode — your account needs to be allowlisted in the Spotify dashboard first."
                } else {
                    saveErrorMessage = "Check your connected service in Settings and try again."
                }
                saveFailed = true
            }
        }
    }

    private func saveButton(controlSize: CGFloat, symbolSize: CGFloat) -> some View {
        let saved = env.savedTracks.isSaved(entry)
        return Button {
            saveToLibrary()
        } label: {
            Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(saved ? .green : palette.accent)
                .frame(width: controlSize, height: controlSize)
                .symbolEffect(.bounce, value: saved)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(saved)
        .accessibilityLabel(saved ? "Added to your Daily Music playlist" : "Save to your Daily Music playlist")
        .alert("Couldn't save this song", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    var actionCluster: some View {
        HStack(spacing: Theme.Spacing.md) {
            heartButton
            if canSaveToLibrary {
                saveButton(controlSize: 52, symbolSize: 20)
            }
            reactionButton(controlSize: 52, symbolSize: 20)
            Spacer(minLength: Theme.Spacing.sm)
            RatingBar(entry: entry, accent: palette.accent, isReadOnly: !allowsRating)
            Spacer(minLength: Theme.Spacing.sm)
            infoButton
        }
        .padding(.horizontal)
    }

    var primaryRatingControl: some View {
        RatingBar(
            entry: entry,
            accent: palette.accent,
            controlSize: 84,
            symbolSize: 32,
            spacing: 18,
            isReadOnly: !allowsRating
        )
    }

    var compactActions: some View {
        HStack(spacing: 10) {
            compactHeartButton
            if canSaveToLibrary {
                saveButton(controlSize: 46, symbolSize: 18)
            }
            reactionButton(controlSize: 46, symbolSize: 18)
            compactInfoButton
        }
    }

    private var heartButton: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)
        return Button {
            toggleFavourite()
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isFav ? .red : palette.accent)
                .frame(width: 52, height: 52)
                .symbolEffect(.bounce, value: isFav)   // little "pop" on favorite/unfavorite
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    private var infoButton: some View {
        Button { showingInfo = true } label: {
            Image(systemName: "info")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Song info")
    }

    @ViewBuilder
    private func reactionButtonSymbol(symbolSize: CGFloat) -> some View {
        if let selectedReactionEmoji {
            Text(selectedReactionEmoji)
                .font(.system(size: symbolSize + 6))
                .lineLimit(1)
                .fixedSize()
        } else {
            Image(systemName: "face.smiling")
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(palette.accent)
        }
    }

    private func reactionButton(controlSize: CGFloat, symbolSize: CGFloat) -> some View {
        Button {
            showingReactions = true
        } label: {
            reactionButtonSymbol(symbolSize: symbolSize)
                .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("React")
        .popover(isPresented: $showingReactions, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            reactionsPopover
        }
    }

    private var reactionsPopover: some View {
        ReactionsBar(
            entry: entry,
            accent: palette.accent,
            isReadOnly: !allowsEntryReaction,
            onSelection: { emoji in
                selectedReactionEmoji = emoji
                showingReactions = false
            }
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .presentationCompactAdaptation(.popover)
    }

    var compactHeartButton: some View {
        let store = env.favoritesStore
        let isFav = store.isFavorite(entry)
        return Button {
            toggleFavourite()
        } label: {
            Image(systemName: isFav ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isFav ? .red : palette.accent)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
    }

    var compactInfoButton: some View {
        Button { showingInfo = true } label: {
            Image(systemName: "info")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.accent)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Song info")
    }
}
