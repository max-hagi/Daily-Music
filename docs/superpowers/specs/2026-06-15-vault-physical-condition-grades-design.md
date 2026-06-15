# Vault physical condition grades

Date: 2026-06-15
Status: Approved design
Related: `2026-06-15-vault-shelves-aging-redesign-design.md`

## Goal

The Vault tier system is working conceptually: records should feel like a collection
that grows, ages, and can be reclaimed, not like a streak punishment system. This
delta tightens the visual language so the tiers read as physical record conditions
at shelf size.

The selected direction is **physical condition grades**:

- Mint looks pristine and premium.
- Secondhand looks proudly used, still collected, and still accomplished.
- Salvaged looks more heavily worn and repaired, with more of the record exposed.
- Rescue stays as the dusty invitation state.

## System Position

Do not rename the underlying status model. `ListenStatus` and `SleeveTreatment`
remain the source of truth:

- `heardSameDay` -> `mint`
- `caughtUp` -> `secondhand`
- `rescued` -> `salvaged`
- `missed` -> `missing` / Rescue affordance
- `unheard` and `rescuable` -> `pending`

The change is visual only. It does not alter listen tracking, catch-up windows,
collection counts, tab badges, or the rule that opening a Vault entry marks it heard.

## Tier Treatments

### Mint

Mint is already close and should stay the reward state:

- Keep the clean protruding vinyl disc.
- Keep full-colour art, crisp gloss, clean border, and stronger shadow.
- Avoid extra labels; mint should read through polish, not text.

### Secondhand

Secondhand is the main change. It should feel like a real used record found late,
not a downgraded or failed state.

Required visual traits:

- Add a protruding vinyl disc, similar to mint, but slightly lower/side-shifted.
- Make the disc visibly used: softer black, subtle groove rings, faint scratches,
  and a less pristine center label.
- Keep the sleeve attractive: moderate desaturation and brightness reduction only.
- Keep or strengthen ring wear, faint scuffs, dog-ear corner, and the small stamp.
- The overall read should be "used copy I earned," not "damaged punishment."

### Salvaged

Salvaged should be the roughest collected condition. It is reclaimed after the
window closed, so it should feel more dramatic than secondhand but still satisfying.

Required visual traits:

- Show more of the vinyl disc than secondhand.
- Make the disc more worn: stronger scratches, uneven dusty tint, and deeper groove
  texture.
- Keep the repaired sleeve language: tape, creases, dog-ear, slight rotation.
- Use heavier desaturation than secondhand, but keep the album art identifiable.
- The label can remain, but the object condition should carry the meaning first.

### Rescue / Missed

Rescue is not a collected-condition grade. It is an invitation state.

Required visual traits:

- Keep the visible dusty album art.
- Keep the `Rescue` affordance.
- Do not add the protruding disc unless the state is collected; the missing state
  should feel like something waiting to be reclaimed.

## Vault View

The current Shelf / Month structure remains the right container:

- Shelves should feel like browsing month dividers in a record shop.
- The view should not add a new stats card or explanatory copy.
- Tier meaning should be readable through object treatment in the shelf and month
  mosaic, with labels used only as small supporting detail where they already exist.

## Acceptance

- At 132pt shelf size, secondhand is visibly distinct from mint without reading text.
- At compact calendar size, secondhand and salvaged still read as aged versions of
  collected records.
- Salvaged looks more worn than secondhand, but not ugly enough to make rescue feel
  regretful.
- Rescue/missed remains visually distinct from salvaged: dusty invitation, not a
  collected repaired record.
- Existing state derivation tests continue to pass unchanged.
