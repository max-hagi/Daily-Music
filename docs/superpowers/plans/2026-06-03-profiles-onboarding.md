# Profiles & Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a first-run onboarding wizard (name + photo → reminder → streaming preference) and a `UserProfile` (display name + uploaded avatar) that other social features will build on.

**Architecture:** Follows the app's protocol → mock + Supabase → store pattern. A new `ProfileService` (mock + Supabase Storage-backed) is owned by a `ProfileStore` in `AppEnvironment`. A 3-step `OnboardingView` is gated in `RootView` by an `@AppStorage("hasCompletedOnboarding")` flag and reuses the existing `SettingsViewModel`/`NotificationService` for steps 2–3. Pure logic (initials, image downscale) is unit-tested; views are build- and simulator-verified.

**Tech Stack:** SwiftUI, Swift Testing, `supabase-swift` (Postgrest + Storage), PhotosUI, UIKit (`UIGraphicsImageRenderer`/`ImageRenderer`).

**Spec:** `docs/superpowers/specs/2026-06-03-profiles-onboarding-design.md`

---

## Conventions used in every task

**Always export the toolchain first** (the machine defaults to CommandLineTools):

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

**BUILD** =
```bash
xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**TEST** =
```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Daily MusicTests" 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`

New `.swift` files auto-join the target (Xcode 16 synchronized folders) — no `.pbxproj` edits. Module name is `Daily_Music`; test target is `Daily MusicTests`. In Swift, a "failing test" for not-yet-written code shows up as a **compile error** ("cannot find X in scope") — that is the expected red state.

## File structure

**Create:**
- `docs/superpowers/specs/profiles-onboarding.sql` — DB migration + Storage bucket/policies (user runs it)
- `Daily Music/Models/UserProfile.swift` — the profile value type
- `Daily Music/Models/AvatarStyle.swift` — pure initials + palette-index helpers
- `Daily Music/Models/AvatarImageProcessor.swift` — pure image downscale → JPEG
- `Daily Music/Views/Components/InitialsAvatar.swift` — initials-gradient avatar view
- `Daily Music/Services/ProfileService.swift` — protocol + `MockProfileService`
- `Daily Music/Services/Supabase/SupabaseProfileService.swift` — live impl
- `Daily Music/ViewModels/ProfileStore.swift` — observable store
- `Daily Music/Views/Components/AvatarPickerView.swift` — pick + crop + upload control
- `Daily Music/Views/Components/CircularImageCropper.swift` — pinch/drag crop sheet
- `Daily Music/Views/Components/ProfileEditor.swift` — reusable avatar + name editor
- `Daily Music/Views/Onboarding/OnboardingHelloStep.swift`
- `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
- `Daily Music/Views/Onboarding/OnboardingListenStep.swift`
- `Daily Music/Views/Onboarding/OnboardingView.swift` — wizard container + gate flag
- `Daily Music/Views/ProfileEditView.swift` — Settings "Edit profile" sheet
- `Daily MusicTests/AvatarStyleTests.swift`
- `Daily MusicTests/AvatarImageProcessorTests.swift`
- `Daily MusicTests/ProfileStoreTests.swift`

**Modify:**
- `Daily Music/App/AppEnvironment.swift` — add `profiles`/`profileStore`
- `Daily Music/App/RootView.swift` — onboarding gate
- `Daily Music/Views/SettingsView.swift` — profile header + Edit Profile sheet

---

### Task 1: Database migration & Storage bucket (deliverable + manual run)

**Files:**
- Create: `docs/superpowers/specs/profiles-onboarding.sql`

- [ ] **Step 1: Write the SQL file**

```sql
-- Profiles & Onboarding migration
-- Adds identity columns to the existing `profiles` table and a public `avatars`
-- Storage bucket with owner-scoped write policies.

-- 1) Identity columns (the existing row already has: id uuid pk, settings jsonb, updated_at)
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists avatar_url  text;

-- 2) Public-read avatars bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 3) Storage RLS. NOTE: the folder check compares auth.uid()::text (lowercase)
--    against the first path segment, so the app MUST upload to a lowercased uuid
--    folder: "{uid.lowercased}/avatar_*.jpg".
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Users upload their own avatar"
  on storage.objects for insert
  with check ( bucket_id = 'avatars'
               and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users update their own avatar"
  on storage.objects for update
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );

create policy "Users delete their own avatar"
  on storage.objects for delete
  using ( bucket_id = 'avatars'
          and auth.uid()::text = (storage.foldername(name))[1] );
```

- [ ] **Step 2: Commit the SQL file**

```bash
git add "docs/superpowers/specs/profiles-onboarding.sql"
git commit -m "feat(profiles): add profiles+avatars migration SQL"
```

- [ ] **Step 3: MANUAL — user runs it in Supabase**

Paste the SQL into Supabase → SQL Editor → Run. (Needed only before exercising the **live** environment; the mock path works without it.) If a policy already exists, the `create policy` lines error harmlessly — drop and re-create or skip them.

- [ ] **Step 4: MANUAL — verify (after running)**

In SQL Editor: `select display_name, avatar_url from public.profiles limit 1;` returns the columns (no error), and Storage shows an `avatars` bucket marked Public.

---

### Task 2: `UserProfile` model

**Files:**
- Create: `Daily Music/Models/UserProfile.swift`

- [ ] **Step 1: Create the model**

```swift
//
//  UserProfile.swift
//  Daily Music
//
//  A user's public identity: the name + photo other people will see (friend
//  bubbles, lists). Stored as first-class columns on the `profiles` row,
//  separate from the private `settings` JSONB blob.
//

import Foundation

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String?
    var avatarURL: String?
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Models/UserProfile.swift"
git commit -m "feat(profiles): add UserProfile model"
```

---

### Task 3: `AvatarStyle` pure helpers (TDD)

**Files:**
- Create: `Daily MusicTests/AvatarStyleTests.swift`
- Create: `Daily Music/Models/AvatarStyle.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Daily_Music

struct AvatarStyleTests {
    @Test func twoWordInitials() { #expect(AvatarStyle.initials(from: "Maxime Save") == "MS") }
    @Test func oneWordInitial() { #expect(AvatarStyle.initials(from: "Maxime") == "M") }
    @Test func trimsAndUppercases() { #expect(AvatarStyle.initials(from: "  ada lovelace ") == "AL") }
    @Test func emptyFallsBackToQuestionMark() {
        #expect(AvatarStyle.initials(from: "   ") == "?")
        #expect(AvatarStyle.initials(from: nil) == "?")
    }
    @Test func paletteIndexIsDeterministicAndInRange() {
        let a = AvatarStyle.paletteIndex(for: "Maxime", paletteCount: 6)
        let b = AvatarStyle.paletteIndex(for: "Maxime", paletteCount: 6)
        #expect(a == b)
        #expect((0..<6).contains(a))
    }
    @Test func paletteIndexHandlesEmptyPalette() {
        #expect(AvatarStyle.paletteIndex(for: "x", paletteCount: 0) == 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: TEST — Expected: compile error `cannot find 'AvatarStyle' in scope`.

- [ ] **Step 3: Implement**

```swift
//
//  AvatarStyle.swift
//  Daily Music
//
//  Pure helpers for the initials-avatar fallback: derive up to two initials from
//  a name, and pick a stable color palette from a name via a small string hash
//  (djb2) so a given name always gets the same color.
//

import Foundation

enum AvatarStyle {
    /// Up to two uppercase initials, or "?" when there's no usable name.
    static func initials(from name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let letters = trimmed.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.map(String.init).joined().uppercased()
    }

    /// Deterministic palette index in 0..<paletteCount for a given name.
    static func paletteIndex(for name: String?, paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        var hash = 5381
        for byte in (name ?? "").lowercased().utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)   // &+ = overflow-safe add
        }
        return (hash & Int.max) % paletteCount          // mask → non-negative, no abs() trap
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: TEST — Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/AvatarStyle.swift" "Daily MusicTests/AvatarStyleTests.swift"
git commit -m "feat(profiles): add AvatarStyle initials + palette helpers (TDD)"
```

---

### Task 4: `InitialsAvatar` view

**Files:**
- Create: `Daily Music/Views/Components/InitialsAvatar.swift`

- [ ] **Step 1: Create the view**

```swift
//
//  InitialsAvatar.swift
//  Daily Music
//
//  The universal avatar fallback: a name's initials on a deterministic gradient.
//  Shown anywhere a person has no uploaded photo (onboarding, Settings, and later
//  friend bubbles).
//

import SwiftUI

struct InitialsAvatar: View {
    let name: String?
    var size: CGFloat = 64

    // Each palette is a 2-color gradient. AvatarStyle picks one stably per name.
    private static let palettes: [[Color]] = [
        [Color(red: 1.00, green: 0.49, blue: 0.42), Color(red: 1.00, green: 0.37, blue: 0.49)],
        [Color(red: 0.42, green: 0.84, blue: 1.00), Color(red: 0.35, green: 0.55, blue: 1.00)],
        [Color(red: 0.78, green: 0.61, blue: 1.00), Color(red: 0.48, green: 0.36, blue: 1.00)],
        [Color(red: 0.55, green: 0.91, blue: 0.60), Color(red: 0.22, green: 0.70, blue: 0.52)],
        [Color(red: 1.00, green: 0.88, blue: 0.40), Color(red: 1.00, green: 0.66, blue: 0.30)],
        [Color(red: 1.00, green: 0.66, blue: 0.77), Color(red: 1.00, green: 0.42, blue: 0.62)]
    ]

    private var palette: [Color] {
        Self.palettes[AvatarStyle.paletteIndex(for: name, paletteCount: Self.palettes.count)]
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Text(AvatarStyle.initials(from: name))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        InitialsAvatar(name: "Maxime Save")
        InitialsAvatar(name: "Ada")
        InitialsAvatar(name: nil)
    }
    .padding()
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/InitialsAvatar.swift"
git commit -m "feat(profiles): add InitialsAvatar fallback view"
```

---

### Task 5: `AvatarImageProcessor` downscale (TDD)

**Files:**
- Create: `Daily MusicTests/AvatarImageProcessorTests.swift`
- Create: `Daily Music/Models/AvatarImageProcessor.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import UIKit
@testable import Daily_Music

struct AvatarImageProcessorTests {
    static func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return r.image { ctx in
            UIColor.systemPurple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func capsLongestSideAtMax() throws {
        let big = Self.solidImage(width: 2000, height: 1000)
        let data = try #require(AvatarImageProcessor.downscaledJPEG(big, maxDimension: 512))
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 512)
    }

    @Test func doesNotUpscaleSmallImages() throws {
        let small = Self.solidImage(width: 100, height: 80)
        let data = try #require(AvatarImageProcessor.downscaledJPEG(small, maxDimension: 512))
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 100)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: TEST — Expected: compile error `cannot find 'AvatarImageProcessor' in scope`.

- [ ] **Step 3: Implement**

```swift
//
//  AvatarImageProcessor.swift
//  Daily Music
//
//  Pure image helper: shrink a picked avatar so it never exceeds maxDimension on
//  its longest side, then JPEG-encode it. Keeps uploads small and predictable.
//

import UIKit

enum AvatarImageProcessor {
    static func downscaledJPEG(_ image: UIImage,
                               maxDimension: CGFloat = 512,
                               quality: CGFloat = 0.8) -> Data? {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxDimension / max(w, h))     // min(1, …) = never upscale
        let newSize = CGSize(width: w * scale, height: h * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1                                 // size is in pixels, not points
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: TEST — Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Models/AvatarImageProcessor.swift" "Daily MusicTests/AvatarImageProcessorTests.swift"
git commit -m "feat(profiles): add AvatarImageProcessor downscale (TDD)"
```

---

### Task 6: `ProfileService` protocol + mock

**Files:**
- Create: `Daily Music/Services/ProfileService.swift`

- [ ] **Step 1: Create protocol + mock**

```swift
//
//  ProfileService.swift
//  Daily Music
//
//  The profile seam. `save` writes BOTH identity fields (callers pass the current
//  name and avatar), so it never accidentally clears one. The mock keeps a single
//  in-memory profile so previews and tests need no network.
//

import Foundation

protocol ProfileService: Sendable {
    func load() async throws -> UserProfile?
    func save(displayName: String?, avatarURL: String?) async throws
    /// Uploads JPEG bytes and returns the public URL string to store in `avatar_url`.
    func uploadAvatar(_ jpegData: Data) async throws -> String
}

actor MockProfileService: ProfileService {
    private var profile = UserProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        displayName: nil,
        avatarURL: nil
    )

    func load() async throws -> UserProfile? { profile }

    func save(displayName: String?, avatarURL: String?) async throws {
        profile.displayName = displayName
        profile.avatarURL = avatarURL
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        "mock://avatar/\(UUID().uuidString).jpg"
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Services/ProfileService.swift"
git commit -m "feat(profiles): add ProfileService protocol + mock"
```

---

### Task 7: `ProfileStore` (TDD)

**Files:**
- Create: `Daily MusicTests/ProfileStoreTests.swift`
- Create: `Daily Music/ViewModels/ProfileStore.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct ProfileStoreTests {
    @Test func saveThenCurrentReflectsName() async throws {
        let store = ProfileStore(service: MockProfileService())
        await store.load()
        try await store.save(displayName: "Maxime", avatarURL: nil)
        #expect(store.current?.displayName == "Maxime")
    }

    @Test func uploadReturnsURLString() async throws {
        let store = ProfileStore(service: MockProfileService())
        let url = try await store.uploadAvatar(Data([0x1, 0x2]))
        #expect(url.hasPrefix("mock://avatar/"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: TEST — Expected: compile error `cannot find 'ProfileStore' in scope`.

- [ ] **Step 3: Implement**

```swift
//
//  ProfileStore.swift
//  Daily Music
//
//  Owns "who I am" for the app (Settings header now, friend bubbles later).
//  Mirrors SessionStore / FavoritesStore: wraps a service and exposes observable
//  state. After a save it re-loads so `current` reflects the source of truth.
//

import Foundation

@MainActor
@Observable
final class ProfileStore {
    private(set) var current: UserProfile?
    private let service: ProfileService

    init(service: ProfileService) { self.service = service }

    func load() async { current = try? await service.load() }

    func save(displayName: String?, avatarURL: String?) async throws {
        try await service.save(displayName: displayName, avatarURL: avatarURL)
        await load()
    }

    func uploadAvatar(_ data: Data) async throws -> String {
        try await service.uploadAvatar(data)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: TEST — Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/ViewModels/ProfileStore.swift" "Daily MusicTests/ProfileStoreTests.swift"
git commit -m "feat(profiles): add ProfileStore (TDD)"
```

---

### Task 8: `SupabaseProfileService` live implementation

**Files:**
- Create: `Daily Music/Services/Supabase/SupabaseProfileService.swift`

- [ ] **Step 1: Create the live service**

```swift
//
//  SupabaseProfileService.swift
//  Daily Music
//
//  Live profile persistence: identity columns on the `profiles` row + avatar
//  bytes in the public `avatars` Storage bucket. The avatar path's folder is the
//  LOWERCASED user id — the Storage RLS policy compares it to auth.uid()::text.
//

import Foundation
import Supabase

final class SupabaseProfileService: ProfileService {
    private let client = Supa.client

    func load() async throws -> UserProfile? {
        let userID = try await client.auth.session.user.id
        let rows: [ProfileIdentityRow] = try await client
            .from("profiles")
            .select("id, display_name, avatar_url")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first.map {
            UserProfile(id: $0.id, displayName: $0.displayName, avatarURL: $0.avatarURL)
        }
    }

    func save(displayName: String?, avatarURL: String?) async throws {
        let userID = try await client.auth.session.user.id
        try await client
            .from("profiles")
            .upsert(ProfileIdentityUpsert(id: userID, displayName: displayName, avatarURL: avatarURL),
                    onConflict: "id")
            .execute()
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        let userID = try await client.auth.session.user.id
        let path = "\(userID.uuidString.lowercased())/avatar_\(Int(Date().timeIntervalSince1970)).jpg"
        try await client.storage
            .from("avatars")
            .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }
}

private struct ProfileIdentityRow: Decodable {
    let id: UUID
    let displayName: String?
    let avatarURL: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

private struct ProfileIdentityUpsert: Encodable {
    let id: UUID
    let displayName: String?
    let avatarURL: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Services/Supabase/SupabaseProfileService.swift"
git commit -m "feat(profiles): add SupabaseProfileService (Postgrest + Storage)"
```

---

### Task 9: Wire `ProfileService` + `ProfileStore` into `AppEnvironment`

**Files:**
- Modify: `Daily Music/App/AppEnvironment.swift`

- [ ] **Step 1: Add the stored properties**

After `let settings: SettingsService` (line ~33) add:

```swift
    let profiles: ProfileService
```

After `let favoritesStore: FavoritesStore` (line ~37) add:

```swift
    let profileStore: ProfileStore
```

- [ ] **Step 2: Add the init parameter and assignments**

Add `profiles: ProfileService,` to the `init(...)` parameter list (e.g. right after `settings: SettingsService,`). In the body, after `self.settings = settings` add:

```swift
        self.profiles = profiles
```

And next to the other wrappers (after `self.favoritesStore = FavoritesStore(service: favorites)`):

```swift
        self.profileStore = ProfileStore(service: profiles)
```

- [ ] **Step 3: Wire both factories**

In `mock()` add `profiles: MockProfileService(),` (e.g. after `settings: MockSettingsService(),`).
In `live()` add `profiles: SupabaseProfileService(),` (e.g. after `settings: SupabaseSettingsService(),`).

- [ ] **Step 4: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/App/AppEnvironment.swift"
git commit -m "feat(profiles): wire ProfileService + ProfileStore into AppEnvironment"
```

---

### Task 10: `CircularImageCropper` + `AvatarPickerView`

**Files:**
- Create: `Daily Music/Views/Components/CircularImageCropper.swift`
- Create: `Daily Music/Views/Components/AvatarPickerView.swift`

- [ ] **Step 1: Create the cropper**

```swift
//
//  CircularImageCropper.swift
//  Daily Music
//
//  A minimal square cropper with a circular guide: pinch to zoom, drag to
//  reposition. The SAME transformed view is used for the preview and the capture
//  (via ImageRenderer), so what you see is what gets saved. Output is a square
//  UIImage (we clip to a circle wherever avatars are shown).
//

import SwiftUI

struct CircularImageCropper: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let side: CGFloat = 300

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                transformed
                    .overlay {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: side, height: side)
                    }
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale = max(1, lastScale * $0) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width,
                                                             height: lastOffset.height + $0.translation.height) }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") { onConfirm(rendered()) }.tint(.white).bold()
                }
            }
        }
    }

    // The image, scaled-to-fill the square, then transformed and clipped to it.
    private var transformed: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: side, height: side)
            .clipped()
    }

    @MainActor private func rendered() -> UIImage {
        let renderer = ImageRenderer(content: transformed)
        renderer.scale = 1024 / side    // capture at ~1024px for quality
        return renderer.uiImage ?? image
    }
}
```

- [ ] **Step 2: Create the avatar picker control**

```swift
//
//  AvatarPickerView.swift
//  Daily Music
//
//  The tappable avatar: shows the current photo (or InitialsAvatar), opens the
//  privacy-preserving PhotosPicker (no usage string needed), crops, downscales,
//  uploads, and writes the resulting public URL back to the bound avatarURL.
//

import SwiftUI
import PhotosUI

struct AvatarPickerView: View {
    @Binding var avatarURL: String?
    let displayName: String?
    var size: CGFloat = 96

    @Environment(AppEnvironment.self) private var env

    @State private var pickerItem: PhotosPickerItem?
    @State private var cropItem: IdentifiableImage?
    @State private var isUploading = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    preview
                    Circle()
                        .fill(Theme.Brand.gradient[0])
                        .frame(width: size * 0.32, height: size * 0.32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay { Circle().stroke(Color(.systemBackground), lineWidth: 3) }
                }
            }
            .buttonStyle(.plain)

            if isUploading { ProgressView() }
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }
        }
        .onChange(of: pickerItem) { _, item in Task { await loadPicked(item) } }
        .sheet(item: $cropItem) { wrapped in
            CircularImageCropper(
                image: wrapped.image,
                onConfirm: { cropped in cropItem = nil; Task { await upload(cropped) } },
                onCancel: { cropItem = nil }
            )
        }
    }

    @ViewBuilder private var preview: some View {
        if let avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { $0.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: displayName, size: size) }
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: displayName, size: size)
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            cropItem = IdentifiableImage(ui)
        }
        pickerItem = nil
    }

    private func upload(_ image: UIImage) async {
        guard let data = AvatarImageProcessor.downscaledJPEG(image) else { return }
        isUploading = true; errorText = nil
        defer { isUploading = false }
        do { avatarURL = try await env.profileStore.uploadAvatar(data) }
        catch { errorText = "Couldn't upload that photo. Try again." }
    }
}

// Wraps a UIImage so it can drive `.sheet(item:)`.
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    init(_ image: UIImage) { self.image = image }
}
```

- [ ] **Step 3: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Components/CircularImageCropper.swift" "Daily Music/Views/Components/AvatarPickerView.swift"
git commit -m "feat(profiles): add avatar picker + circular cropper"
```

---

### Task 11: `ProfileEditor` (reusable avatar + name)

**Files:**
- Create: `Daily Music/Views/Components/ProfileEditor.swift`

- [ ] **Step 1: Create the editor**

```swift
//
//  ProfileEditor.swift
//  Daily Music
//
//  The shared avatar + name control, reused by onboarding's first step and the
//  Settings "Edit profile" sheet. It edits bindings only — the parent decides
//  when to persist (Continue / Save).
//

import SwiftUI

struct ProfileEditor: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?

    var body: some View {
        VStack(spacing: 20) {
            AvatarPickerView(avatarURL: $avatarURL,
                             displayName: displayName.isEmpty ? nil : displayName)
            TextField("Your name", text: $displayName)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Components/ProfileEditor.swift"
git commit -m "feat(profiles): add reusable ProfileEditor"
```

---

### Task 12: Onboarding "Say hello" step

**Files:**
- Create: `Daily Music/Views/Onboarding/OnboardingHelloStep.swift`

- [ ] **Step 1: Create the step**

```swift
//
//  OnboardingHelloStep.swift
//  Daily Music
//
//  Step 1 of onboarding: the identity step. Name is required (the wizard's
//  Continue button enforces it); the photo is optional (initials default).
//

import SwiftUI

struct OnboardingHelloStep: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Say hello 👋")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("What should friends call you?")
                .foregroundStyle(.secondary)
            ProfileEditor(displayName: $displayName, avatarURL: $avatarURL)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingHelloStep.swift"
git commit -m "feat(onboarding): add Say Hello step"
```

---

### Task 13: Onboarding reminder + streaming steps

**Files:**
- Create: `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
- Create: `Daily Music/Views/Onboarding/OnboardingListenStep.swift`

- [ ] **Step 1: Create the reminder step** (reuses `SettingsViewModel`)

```swift
//
//  OnboardingReminderStep.swift
//  Daily Music
//
//  Step 2: pick a reminder time and (optionally) turn the daily nudge on. Toggling
//  it on is the in-context moment we ask for notification permission, via the same
//  SettingsViewModel.applyReminderSetting the Settings screen uses.
//

import SwiftUI

struct OnboardingReminderStep: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Never miss a day")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("A gentle nudge when the new song drops.")
                .foregroundStyle(.secondary)

            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Toggle("Daily reminder", isOn: $settings.reminderEnabled)
                .padding(.horizontal)
                .onChange(of: settings.reminderEnabled) { _, on in
                    Task { await settings.applyReminderSetting(enabled: on) }
                }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 2: Create the streaming step** (data-driven off `StreamingService.allCases`)

```swift
//
//  OnboardingListenStep.swift
//  Daily Music
//
//  Step 3: the preferred streaming service ("Open in…" default). Rendered from
//  StreamingService.allCases so Apple Music / Spotify / Tidal all appear, and any
//  future service is automatic.
//

import SwiftUI

struct OnboardingListenStep: View {
    @Bindable var settings: SettingsViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Where do you listen?")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("So “Open in…” jumps to the right app.")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(StreamingService.allCases) { service in
                    Button {
                        settings.preferredStreamingService = service
                    } label: {
                        HStack(spacing: 12) {
                            ServiceLogo(service: service)
                            Text(service.displayName).fontWeight(.semibold)
                            Spacer()
                            if settings.preferredStreamingService == service {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.Brand.gradient[0])
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 3: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingReminderStep.swift" "Daily Music/Views/Onboarding/OnboardingListenStep.swift"
git commit -m "feat(onboarding): add reminder + streaming steps"
```

---

### Task 14: `OnboardingView` wizard container

**Files:**
- Create: `Daily Music/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create the container**

```swift
//
//  OnboardingView.swift
//  Daily Music
//
//  The 3-step wizard. Name is required (Continue is disabled on step 1 until it's
//  filled); the photo and steps 2–3 are skippable. Steps 2–3 persist live via a
//  shared SettingsViewModel; the name+avatar are saved on Finish. Completion flips
//  @AppStorage("hasCompletedOnboarding"), which RootView watches.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var displayName = ""
    @State private var avatarURL: String?
    @State private var settings: SettingsViewModel?
    @State private var isSaving = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            progressDots.padding(.top, 24)
            Spacer(minLength: 0)
            Group {
                switch step {
                case 0:
                    OnboardingHelloStep(displayName: $displayName, avatarURL: $avatarURL)
                case 1:
                    if let settings { OnboardingReminderStep(settings: settings) }
                default:
                    if let settings { OnboardingListenStep(settings: settings) }
                }
            }
            Spacer(minLength: 0)
            buttons.padding(.horizontal, 28).padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            if settings == nil {
                settings = SettingsViewModel(notifications: env.notifications, settings: env.settings)
            }
            await env.profileStore.load()
            if let c = env.profileStore.current {
                displayName = c.displayName ?? ""
                avatarURL = c.avatarURL
            }
        }
    }

    private var nameFilled: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Theme.Brand.gradient[0] : Color.secondary.opacity(0.3))
                    .frame(width: i == step ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button { advance() } label: {
                Text(step == totalSteps - 1 ? "Finish" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: Theme.Brand.gradient[0]))
            .disabled((step == 0 && !nameFilled) || isSaving)

            // Skip is offered only on the optional steps (2 & 3), never on step 1.
            if step > 0 {
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { advance() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isSaving)
            }
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        isSaving = true
        Task {
            try? await env.profileStore.save(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                avatarURL: avatarURL
            )
            isSaving = false
            hasCompletedOnboarding = true
        }
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat(onboarding): add wizard container with progress + completion"
```

---

### Task 15: Gate onboarding in `RootView`

**Files:**
- Modify: `Daily Music/App/RootView.swift`

- [ ] **Step 1: Add the completion flag**

After `@State private var isCompletingSignIn = false` (line ~17) add:

```swift
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
```

- [ ] **Step 2: Replace the signed-in branch**

Replace this block (lines ~34–44):

```swift
            } else if env.session.isSignedIn {
                // Phase 2a: signed in → main app. `.task` kicks off favorites
                // loading once MainTabView appears (and cancels if it leaves).
                MainTabView()
                    .task { await env.favoritesStore.load() }
                    // Asymmetric transition: different animation for appearing
                    // (insertion) vs disappearing (removal).
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
```

with:

```swift
            } else if env.session.isSignedIn && !hasCompletedOnboarding {
                // Phase 2a: signed in but no profile yet → first-run wizard.
                OnboardingView()
                    .transition(.opacity)
            } else if env.session.isSignedIn {
                // Phase 2b: signed in → main app. `.task` kicks off favorites +
                // profile loading once MainTabView appears.
                MainTabView()
                    .task {
                        await env.favoritesStore.load()
                        await env.profileStore.load()
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
```

- [ ] **Step 3: Animate the new gate**

After the line `.animation(.spring(response: 0.75, dampingFraction: 0.84), value: env.session.isSignedIn)` (line ~57) add:

```swift
        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: hasCompletedOnboarding)
```

- [ ] **Step 4: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Verify in the simulator**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcodebuild -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'Daily Music.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted maxhagi.Daily-Music
```

To force the wizard: delete the app first (`xcrun simctl uninstall booted maxhagi.Daily-Music`) so `hasCompletedOnboarding` resets, then in the launched app use the DEBUG "Continue as guest" button. Expected: wizard appears (Say hello → reminder → streaming), Continue is disabled until a name is typed, Finish lands on the main tabs. Screenshot: `xcrun simctl io booted screenshot /tmp/onboarding.png`.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/App/RootView.swift"
git commit -m "feat(onboarding): gate first-run wizard in RootView"
```

---

### Task 16: Settings — profile header + Edit Profile sheet

**Files:**
- Create: `Daily Music/Views/ProfileEditView.swift`
- Modify: `Daily Music/Views/SettingsView.swift`

- [ ] **Step 1: Create the edit sheet**

```swift
//
//  ProfileEditView.swift
//  Daily Music
//
//  The "Edit profile" sheet opened from Settings. Reuses ProfileEditor and saves
//  name + avatar through ProfileStore. Name is required to save.
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var avatarURL: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProfileEditor(displayName: $displayName, avatarURL: $avatarURL)
                    .padding(.top, 24)
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            try? await env.profileStore.save(
                                displayName: displayName.trimmingCharacters(in: .whitespaces),
                                avatarURL: avatarURL
                            )
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .task {
                await env.profileStore.load()
                displayName = env.profileStore.current?.displayName ?? ""
                avatarURL = env.profileStore.current?.avatarURL
            }
        }
    }
}
```

- [ ] **Step 2: Read SettingsView to find the insertion point**

Run: `grep -n "var body\|Form\|List\|@State\|@Environment(AppEnvironment" "Daily Music/Views/SettingsView.swift" | head` to locate the top of the settings `Form`/`List` and the existing state.

- [ ] **Step 3: Add state + the profile section + the sheet**

Add near the other `@State` properties:

```swift
    @State private var showingEditProfile = false
```

As the **first** section inside the settings `Form`/`List`, add:

```swift
            Section {
                Button { showingEditProfile = true } label: {
                    HStack(spacing: 14) {
                        profileAvatar
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profileName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Edit profile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
```

Add these helpers inside `SettingsView` (e.g. above `var body`):

```swift
    private var profileName: String {
        let name = env.profileStore.current?.displayName ?? ""
        return name.isEmpty ? "Set your name" : name
    }

    @ViewBuilder private var profileAvatar: some View {
        if let s = env.profileStore.current?.avatarURL, let url = URL(string: s) {
            AsyncImage(url: url) { $0.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: env.profileStore.current?.displayName, size: 48) }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: env.profileStore.current?.displayName, size: 48)
        }
    }
```

Attach to the `Form`/`List` (alongside its other modifiers):

```swift
        .sheet(isPresented: $showingEditProfile) { ProfileEditView() }
        .task { await env.profileStore.load() }
```

(If `SettingsView` does not already read the environment, add `@Environment(AppEnvironment.self) private var env` — note the existing code references `env`, so it already does.)

- [ ] **Step 4: Build**

Run: BUILD — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Verify in the simulator**

Launch (see Task 15 Step 5), open Settings: the top row shows the avatar + name (or "Set your name"). Tapping opens the Edit Profile sheet; changing the name + Save updates the row. Screenshot `/tmp/settings-profile.png`.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/ProfileEditView.swift" "Daily Music/Views/SettingsView.swift"
git commit -m "feat(profiles): add Settings profile header + Edit Profile sheet"
```

---

### Task 17: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the whole test bundle**

Run: TEST — Expected: `** TEST SUCCEEDED **` with `AvatarStyleTests`, `AvatarImageProcessorTests`, `ProfileStoreTests` all passing.

- [ ] **Step 2: Manual mock walkthrough**

In the simulator with the mock environment (DEBUG sign-in toggle set to Mock, "Continue as guest"): complete the wizard end to end — type a name (Continue enables), tap the avatar → pick → crop → see it appear, set a reminder time + toggle (allow the permission prompt), pick Tidal, Finish → main tabs. Reopen Settings → profile row reflects the name/photo → Edit Profile changes persist.

- [ ] **Step 3: Confirm the live path (after the user has run Task 1 SQL)**

Switch the DEBUG data toggle to Live, "Continue as guest", complete onboarding, then in Supabase confirm the `profiles` row has `display_name` set and (if a photo was chosen) `avatar_url` points at the `avatars` bucket and loads.

- [ ] **Step 4: Final no-op commit / branch is ready**

Nothing to commit if clean. The branch is ready to merge per `superpowers:finishing-a-development-branch`.

---

## Self-review notes (author)

- **Spec coverage:** entry flow C (Task 14/15) · required non-unique name (Task 14 `nameFilled` gate; Task 16 save guard) · optional photo + initials default (Tasks 4, 10) · avatar upload to Storage (Tasks 1, 8, 10) · profiles columns (Task 1) · `ProfileService`/`ProfileStore`/`AppEnvironment` (Tasks 6–9) · 3 wizard steps incl. Tidal via `allCases` (Tasks 12–13) · Settings edit (Task 16) · tests for initials + downscale + store (Tasks 3, 5, 7). All spec sections map to a task.
- **Deferred by design (see below):** the production "Get started" anonymous front door, and `display_name` legacy-empty nudges beyond Settings.

## Deferred — needs a product decision before building

The spec's "promote the anonymous **Get started** entry to production" (§4/§5) is intentionally **not** a task here. While planning, this surfaced as entangled with a separate behavior: `isGuest == user.isAnonymous`, and anonymous sessions currently **do not persist ratings or reactions** ([RatingBar.swift:94](../../../Daily%20Music/Views/RatingBar.swift:94), [ReactionsBar.swift:120](../../../Daily%20Music/Views/ReactionsBar.swift:120)) — ratings feed Insights. So shipping a browse-first anonymous door without also deciding "are anonymous users first-class?" would silently drop their ratings. That's a product + App Store call deserving its own short spec. Everything in this plan works today via the email sign-in path (production) and the DEBUG guest button (testing), so onboarding is fully usable and shippable without it.
