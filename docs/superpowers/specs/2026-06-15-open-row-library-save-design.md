# Open Row Library Save Design

## Goal

Restore balance to the Today song zone after adding library save. The save action should no longer sit beside the album/title identity area, where it crowds the artwork and makes the hero feel asymmetrical.

## Chosen Approach

Place the save-to-library control in the playback handoff row:

`Open in [preferred service]` + `Save` + `More`

The primary open button remains the main visual action and shrinks flexibly to make room. Save and More are equal circular controls, so the row reads as one CTA cluster instead of a detached side button.

## Visibility

Show Save only when the app has a connected service that can write to a library:

- Apple Music when its session exposes `.librarySave`.
- Spotify when its session exposes `.librarySave`.
- No linked save-capable service means no Save button in the row.

This avoids showing an unavailable action. Connection prompts remain owned by Settings or onboarding; this change keeps Today focused and avoids a disabled-looking button in the main CTA area.

## Behavior

Save reuses the existing library save flow:

- If the entry is unsaved, tapping Save writes through `env.librarySaveService`.
- On success, `env.savedTracks.markSaved(entry)` marks the entry locally.
- Saved entries show the existing green check state and cannot be saved again.
- Existing save errors and Spotify-specific forbidden messages continue to surface through the current alert.

## Layout Changes

On Today's immersive layout:

- Remove Save from `entryIdentityWithInlineControls`.
- Keep Favorite on the left and Info on the right around the title/artist area.
- Add Save to `OpenInSection` between the open button and the More menu when saving is available.

On standard entry layouts:

- The same `OpenInSection` row can show Save when available, keeping CTA behavior consistent across Today, Vault, and Favorites.
- The existing action cluster should not duplicate Save if the row owns it.

## Testing

Add focused coverage around the row composition or extracted row state:

- Save-capable service: row includes Open, Save, and More.
- No save-capable service: row includes Open and More only.
- Saved entry: Save renders the added/check state and is disabled.

Manual verification should confirm the Today hero album art no longer shifts smaller or upward because Save is removed from the identity column.
