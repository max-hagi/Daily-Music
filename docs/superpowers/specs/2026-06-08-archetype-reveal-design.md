# Archetype Change Reveal - Design Spec

- **Date:** 2026-06-08
- **Status:** Draft for review
- **Scope:** Insights-only fullscreen reveal when the user's stable archetype changes.

## 1. Goal

When a user's tastes grow enough to change their archetype, entering Insights should feel like a small ceremony. The app should reward the change with a fullscreen themed reveal, then let the new archetype colors become the page background.

The raw taste mirror can keep updating as songs are rated. The archetype identity should not flip day to day. It should be stabilized on a weekly cadence and revealed once when it changes.

## 2. Product Rules

- Ratings continue to affect the live taste mirror whenever Insights loads.
- The displayed archetype is a persisted weekly snapshot, separate from the live candidate archetype.
- The snapshot is evaluated at most once every seven days.
- If the weekly candidate differs from the stored stable archetype, store the new stable archetype and create a pending reveal.
- The reveal plays the next time the user opens Insights.
- After the reveal finishes or is dismissed, clear the pending reveal.
- Never replay an already acknowledged archetype change.
- Do not show a reveal while the archetype is still locked or nil.
- Respect Reduce Motion with a shorter crossfade, no particle storm, and no large-scale motion.

## 3. Experience

The reveal is a fullscreen cover over Insights.

1. The screen starts from the previous stable archetype background color.
2. The new archetype symbol and title appear in the center.
3. A shared pulse expands from the symbol.
4. The new archetype colors flood the entire screen.
5. Archetype-specific flare animates on top.
6. The cover fades away, revealing Insights with the new archetype wash already applied.

Default copy:

```text
Your taste grew into
Festival Goer
More high-energy, euphoric picks are taking the lead.
```

The second line can use the same "why it's you" inputs that already power the hero copy when available. If no good explanation exists, use a short generic line: "Your recent ratings shifted the shape of your taste."

## 4. Flare Model

Every archetype has a flare. The implementation should use one shared reveal component and a small flare descriptor, not a separate view per archetype.

```swift
struct ArchetypeRevealFlare {
    let id: String
    let particleStyle: ParticleStyle
    let lightStyle: LightStyle
    let symbolMotion: SymbolMotion
    let texture: RevealTexture
}
```

The default reveal is always present:

- symbol pulse
- color flood
- centered title/subtitle
- haptic on reveal peak when haptics are enabled

The flare descriptor adds themed elements on top of that default.

## 5. Flare Catalogue

Initial flare assignments:

| Archetype | Flare |
| --- | --- |
| Disco Darling | mirror-ball sparkles, gold glints, radial dance-floor sweep |
| Synth-Pop Kid | cyan waveform ribbons, neon scanlines |
| Festival Goer | pink-purple party lights, confetti, sparkle bursts |
| Anthemist | violet arena beams, raised pulse rings |
| Euphoric | warm sunburst, rising glitter |
| Flower Child | leaf petals, green-gold drifting motes |
| Pop Purist | bubblegum dots, smiley bounce, glossy pop sparkles |
| Indie Kid | lime paper cutouts, headphone pulse rings |
| Young at Heart | sky-blue motion trails, playful stepping dots |
| Joy Seeker | golden rays, buoyant bubbles |
| Canyon Soul | warm canyon dust, guitar-string shimmer |
| Romantic | heart glints, rose-pink bloom |
| Hopeless Romantic | heart fragments reforming into glow |
| Tender Soul | soft rose wash, slow floating hearts |
| Free Spirit | green breeze trails, leaf sweep |
| Mellow Soul | sun-haze bands, soft vinyl wobble |
| Ambient Wanderer | teal wave ripples, drifting mist |
| Still Waters | calm water rings, subtle teal shimmer |
| Neon Rider | purple-blue speed lines, electric bolt pulse |
| Shoegaze Kid | hazy lavender blur, soft feedback waves |
| Indie Mystic | moonlit teal sparks, constellation dots |
| Dream Chaser | lavender star trails, floating sparkle arcs |
| Cloud Drifter | soft clouds, moon-haze glow |
| Rock Pilgrim | amber amp glow, guitar-pick sparks |
| 80s Time Traveler | retro grid sweep, clock ripple, amber synth bars |
| 90s Kid | cassette tape lines, muted blue-violet blocks |
| Memory Keeper | photo-flash tiles, sepia dust |
| Sentimentalist | warm memory vignette, slow gold flecks |
| Dark Waver | violet moon rings, dark wave ripples |
| Grunge Kid | olive paper grain, guitar fuzz sparks |
| Indie Confessor | midnight mic glow, lyric-line streaks |
| Indie Heartbreaker | magenta fracture lines, heart-slice glow |
| Melancholic | cloud-moon fade, blue-gray rain specks |
| Punk Purist | red stencil flashes, jagged burst lines |
| Rockstar | orange stage flash, amp sparks, flame lick |
| Grunge Rebel | rust grit, smoky flame pulse |
| Protest Rebel | megaphone shockwave, red poster stripes |
| Champion | gold victory rays, arena stomp rings |
| Defiant Spirit | ember burst, flame pulse |
| Post-Punk Poet | purple noir spotlight, mic shadow sweep |
| Industrial Heart | steel gear pulse, gray sparks |
| Goth Soul | deep violet smoke, moon glints |
| Noir Soul | burgundy smoke, film-noir light slats |
| Dark Rebel | crimson bolt crack, dark ember scatter |
| Midnight Drifter | black-violet half-moon sweep, low mist |
| Eclectic | blue mosaic tiles, multi-path color ribbons |

## 6. Data Model

Add a small persisted snapshot model, stored locally first through a dedicated `UserDefaults` backed store.

```swift
struct ArchetypeSnapshot: Codable, Equatable {
    var stableArchetypeID: String?
    var previousArchetypeID: String?
    var pendingRevealArchetypeID: String?
    var lastEvaluatedAt: Date?
    var lastRevealedArchetypeID: String?
}
```

Local storage is enough for v1. Supabase sync is out of scope for this iteration.

## 7. Evaluation Logic

Add a pure evaluator so cadence behavior is unit-testable.

```swift
struct ArchetypeSnapshotEvaluator {
    static let cadence: TimeInterval = 7 * 24 * 60 * 60

    func evaluate(
        snapshot: ArchetypeSnapshot,
        candidate: TasteProfile?,
        now: Date
    ) -> ArchetypeSnapshot
}
```

Rules:

- If `candidate == nil`, return the snapshot unchanged.
- If `lastEvaluatedAt` is less than seven days ago, return unchanged.
- If no stable archetype exists, store the candidate as stable but do not create a reveal. This prevents a first-time unlock from feeling like a "changed from nothing" event.
- If the candidate id equals the stable id, update `lastEvaluatedAt` only.
- If the candidate id differs from the stable id, copy the old stable id to `previousArchetypeID`, store the candidate as stable, and set `pendingRevealArchetypeID`.
- If `pendingRevealArchetypeID` already exists, do not overwrite it until it is acknowledged.

## 8. View Integration

`InsightsViewModel` continues to build the live `TasteMirror`. It also owns the snapshot store, evaluates the weekly candidate after each successful load, and exposes the stable archetype state for the view.

View-model surface:

```swift
@Observable
final class InsightsViewModel {
    private(set) var state: LoadState<TasteMirror> = .loading
    private(set) var stableArchetype: TasteProfile?
    private(set) var reveal: ArchetypeRevealRequest?

    func acknowledgeReveal()
}
```

`InsightsView` uses the stable archetype for the page wash when available:

```swift
let pageProfile = model.stableArchetype ?? mirror.archetype ?? .balancedDefault
```

When `reveal` is set, `InsightsView` presents:

```swift
.fullScreenCover(item: $reveal) { request in
    ArchetypeRevealView(request: request) {
        model.acknowledgeReveal()
    }
}
```

The cover is skippable with a close button after the main reveal peak at 2.4 seconds. It auto-dismisses at 4.0 seconds. In Reduce Motion, it crossfades and auto-dismisses at 1.6 seconds.

## 9. Components

New files:

- `Daily Music/Models/ArchetypeSnapshot.swift`
- `Daily Music/Models/ArchetypeRevealFlare.swift`
- `Daily Music/Services/ArchetypeSnapshotStore.swift`
- `Daily Music/Views/Components/ArchetypeRevealView.swift`
- `Daily MusicTests/ArchetypeSnapshotTests.swift`
- `Daily MusicTests/ArchetypeRevealFlareTests.swift`

Edited files:

- `Daily Music/ViewModels/InsightsViewModel.swift`
- `Daily Music/Views/InsightsView.swift`
- `Daily Music/Models/TasteProfile.swift` to add `allCases` and `profile(id:)` helpers.

## 10. Testing

Unit tests:

- first stable archetype stores without pending reveal
- same candidate after seven days updates evaluation date without reveal
- different candidate after seven days creates pending reveal
- evaluation before seven days does nothing
- nil candidate does nothing
- pending reveal is not overwritten
- acknowledging reveal clears pending id and stores `lastRevealedArchetypeID`
- every known `TasteProfile` id maps to a non-default flare descriptor

Manual QA:

- Open Insights with no ratings: no reveal.
- Unlock first archetype: no change reveal, stable wash appears.
- Force a weekly candidate change: reveal plays once.
- Reopen Insights: reveal does not replay.
- Enable Reduce Motion: reveal uses a calm crossfade.
- Festival Goer: default pulse flood plus pink-purple lights and confetti.

## 11. Out of Scope

- Cross-device reveal sync.
- Push notifications about archetype changes.
- Sharing the reveal as a video or card.
- Changing the TasteMirror scoring algorithm.
- Friend Insights reveals.
