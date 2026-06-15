//
//  EntryDetailImmersive.swift
//  Daily Music
//
//  The immersive two-zone snap layout used by Today (and Vault/Favorites
//  fullscreen covers): a full-screen "song" zone and a reading-mode "story"
//  zone that snaps in on scroll. Split out of EntryDetailView.swift; the
//  shared state and backdrop live there.
//

import SwiftUI

// MARK: - Immersive layout (Today) — two zones with snap

extension EntryDetailView {
    var immersiveLayout: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    songZone {
                        scrollToJournal(proxy)
                    }
                    .id(ImmersiveSection.song)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)   // ≈ one viewport → snap target
                    journalZone
                        .id(ImmersiveSection.journal)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(StorySnapScrollTargetBehavior())
            // Drive the dock's opacity from scroll position so it reads as part
            // of the journal: gone while reading, back when the song zone returns.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                let fadeDistance = max(1, geometry.containerSize.height * 0.25)
                return (1 - offset / fadeDistance).clamped(to: 0...1)
            } action: { _, fade in
                journalDockFade = fade
            }
        }
    }

    // Hero sleeve size on Today. Deliberately tunable — expect to adjust when testing.
    private var coverSleeveSize: CGFloat { 300 }

    private func songZone(openJournal: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let preArtworkMessage {
                Text(preArtworkMessage)
                    .font(.caption.weight(.semibold))   // shrunk greeting
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, Theme.Spacing.sm)
            } else {
                Color.clear
                    .frame(height: 16)
                    .padding(.top, Theme.Spacing.sm)
            }
            if onRequestListen != nil {
                // Today: the cover IS the sleeve, so pending→mint collection state
                // reads at a glance (same language as the Vault).
                SleeveView(
                    entry: entry,
                    status: env.listensStore.status(for: entry),
                    size: coverSleeveSize
                )
                .frame(maxWidth: .infinity)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7),
                    value: env.listensStore.status(for: entry).indicatorColor
                )
            } else {
                AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.card)
                    .padding(.horizontal, albumArtHorizontalPadding)
            }
            entryIdentityWithInlineControls(dateLabel: dateLabel)
            ratingExperience
            openInSectionWithRatingNudge
            Spacer(minLength: Theme.Spacing.sm)
            JournalPreviewDock(
                preview: JournalPreview.text(from: entry.journalMarkdown),
                openJournal: openJournal
            )
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            .opacity(journalDockFade)
            .allowsHitTesting(journalDockFade > 0.5)
        }
        // Clamp accessibility text sizes so the one-screen song zone stays intact;
        // the journal (reading) text below is left fully scalable.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func scrollToJournal(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(ImmersiveSection.journal, anchor: .top)
        } else {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                proxy.scrollTo(ImmersiveSection.journal, anchor: .top)
            }
        }
    }

    private var ratingExperience: some View {
        RatingBar(
            entry: entry,
            accent: palette.accent,
            controlSize: 48,
            symbolSize: 22,
            spacing: 14,
            isReadOnly: !allowsRating
        )
        .frame(maxWidth: 420)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 2)
    }

    // The tip stacks ABOVE the Open In buttons — never covering them — so the
    // primary action (actually playing the song) stays tappable on first run.
    private var openInSectionWithRatingNudge: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if shouldShowRatingNudge {
                ratingNudge
                    .padding(.horizontal)
            }

            if isCollected || onRequestListen == nil {
                OpenInSection(
                    entry: entry,
                    accent: palette.accent,
                    rowState: openInRowState,
                    saveAction: saveToLibrary
                )
                .alert("Couldn't save this song", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(saveErrorMessage)
                }
            } else {
                Button { onRequestListen?() } label: {
                    Label("Listen to collect", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: palette.accent))
                .padding(.horizontal)
            }
        }
        .padding(.top, Theme.Spacing.lg)
        .animation(ratingNudgeAnimation, value: shouldShowRatingNudge)
    }

    private var isCollected: Bool {
        env.listensStore.isHeard(entry)
    }

    private var shouldShowRatingNudge: Bool {
        isAnonymousUser ? !didDismissAnonymousRatingNudge : !hasSeenRatingNudge
    }

    private var isAnonymousUser: Bool {
        env.session.session?.isGuest == true
    }

    private var ratingNudgeAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)
    }

    private func dismissRatingNudge() {
        withAnimation(ratingNudgeAnimation) {
            if isAnonymousUser {
                didDismissAnonymousRatingNudge = true
            } else {
                hasSeenRatingNudge = true
            }
        }
    }

    /// One-time tip paired with the rating control so the thumbs read as an Insights input.
    private var ratingNudge: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tune your Insights")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.primary)
                Text("Use 👍 or 👎 to shape your taste stats.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.xs)

            Button {
                dismissRatingNudge()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .glassIconButtonStyle(tint: .secondary.opacity(0.9), size: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .bottom))
            )
        )
        .accessibilityElement(children: .combine)
    }

    private var journalZone: some View {
        let shouldReduceMotion = reduceMotion

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            Text(entry.title).font(.dmTitle())
            JournalText(markdown: entry.journalMarkdown)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))   // opaque reading surface rises over the art
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .scrollTransition { content, phase in
            content
                .opacity(shouldReduceMotion || phase.isIdentity ? 1 : 0)
                .offset(y: shouldReduceMotion ? 0 : (phase.isIdentity ? 0 : 40))
        }
    }
}

private enum ImmersiveSection: Hashable {
    case song
    case journal
}

private struct JournalPreviewDock: View {
    let preview: String
    let openJournal: () -> Void

    var body: some View {
        Button(action: openJournal) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Capsule()
                    .fill(.secondary.opacity(0.34))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("Today's journal")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.primary)

                    Spacer(minLength: Theme.Spacing.sm)

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.secondary)
                }

                Text(preview)
                    .font(.caption.weight(.semibold))
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 10)
            .padding(.bottom, Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .stroke(.white.opacity(0.38), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Read today's journal")
        .accessibilityHint("Opens the story for today's song.")
    }
}

private struct StorySnapScrollTargetBehavior: ScrollTargetBehavior {
    private let commitRatio: CGFloat = 0.62
    private let flickVelocity: CGFloat = 1_100

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard context.axes.contains(.vertical) else { return }

        let maxOffset = max(0, context.contentSize.height - context.containerSize.height)
        guard maxOffset > 0 else { return }

        let originalY = context.originalTarget.rect.minY.clamped(to: 0...maxOffset)
        let proposedY = target.rect.minY.clamped(to: 0...maxOffset)
        let delta = proposedY - originalY
        guard delta != 0 else { return }

        let destinationY = delta > 0 ? maxOffset : 0
        let travelDistance = abs(destinationY - originalY)
        let clearsResistance = abs(delta) >= travelDistance * commitRatio
        let isIntentionalFlick = abs(context.velocity.dy) >= flickVelocity

        target.rect.origin.y = clearsResistance || isIntentionalFlick ? destinationY : originalY
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
