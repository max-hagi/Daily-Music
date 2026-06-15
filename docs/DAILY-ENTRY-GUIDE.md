# Daily Entry Guide

Reference for adding and editing songs in the `daily_entries` table.
Go to: **Supabase Dashboard → SQL Editor** (or Table Editor for quick edits).

---

## Field Reference

### `date`
The calendar day this entry belongs to. One entry per day.
```
Format: YYYY-MM-DD
Example: 2026-06-15
```

---

### `title`
The song title, exactly as it appears on streaming services.
```
Example: Green Light
Example: drop dead        ← lowercase is fine, match the official release
```

---

### `artist`
Artist name(s) as they appear on the release.
```
Example: Lorde
Example: Zara Larsson & Shakira
```

---

### `album_art_url`
Direct link to the album artwork image. Paste from Apple Music or any CDN.
```
Example: https://is1-ssl.mzstatic.com/image/thumb/.../1200x1200bb.jpg
```
**Tip:** On Apple Music web, right-click the album art → Copy Image Address.

---

### `journal_md`
Your write-up for the entry. Supports **Markdown** formatting.
```
Example: "Every piano note in *Nightswimming* feels like a held breath..."

Markdown you can use:
  *italic*     **bold**     # Heading     > blockquote
```

---

### `apple_music_id`
The numeric ID at the end of an Apple Music song URL.
```
URL:  https://music.apple.com/us/song/green-light/1224055391
ID:   1224055391
```

---

### `spotify_uri`
The Spotify track URI. Get it by right-clicking a song in Spotify desktop → Share → Copy Song URI.
```
Format:  spotify:track:XXXXXXXXXXXXXXXXXXXXXX
Example: spotify:track:6ie2Bw3xLj2oRFGBcJqFTc
```

---

### `genre`
Pick the one that best fits. Free text, but keep it consistent with these:

| Genre | Use for |
|---|---|
| `Pop` | Mainstream pop, synth-pop, dance-pop |
| `Alternative` | Indie rock, indie pop, alt-rock, dream pop, shoegaze |
| `Electronic` | Ambient, IDM, art-electronic, club |
| `Hip-Hop/Rap` | Rap, trap, R&B-rap |
| `R&B` | Soul, contemporary R&B |
| `Rock` | Classic rock, hard rock |
| `Country` | Country, country-pop, Americana |
| `Folk` | Folk, acoustic singer-songwriter |
| `Jazz` | Jazz, neo-soul with jazz influence |
| `Classical` | Orchestral, classical |
| `Metal` | Heavy metal, post-metal |

---

### `year`
The **release year** of the original song (not a re-release or remaster).
```
Format: YYYY (integer)
Example: 1997
```

---

### `mood`
The **emotional tone** — how the song *feels*. Pick one:

| Value | When to use |
|---|---|
| `Euphoric` | Pure ecstasy, peak energy joy — festival anthems, euphoric dance tracks |
| `Joyful` | Warm, upbeat, sunny happiness — feels good without being overwhelming |
| `Tender` | Intimate, loving, soft warmth — gentle love songs, emotional closeness |
| `Serene` | Calm, peaceful, settled — no tension, just stillness |
| `Dreamy` | Hazy, ethereal, floating — shoegaze, ambient, soft blur of feeling |
| `Nostalgic` | Bittersweet looking-back — wistful, warm but slightly aching |
| `Melancholy` | Sad but beautiful — meaningful sadness, not despair |
| `Defiant` | Fired up, pushing back, refusing to back down — anthems, punk, fight |
| `Dark` | Heavy, brooding, unsettling — gothic, menacing, existential |

**Mood vs. energy:** Mood is *what* you feel. Energy is *how intense* it is.
A tender song can be low energy (a quiet ballad) or high energy (a soaring string crescendo).

---

### `energy`
Arousal and intensity on a **1–5 scale**:

| Value | Label | Use for |
|---|---|---|
| `1` | Intimate | Near-silence, sparse, barely-there — solo piano, whispered vocals |
| `2` | Low | Subdued, gentle, mostly quiet |
| `3` | Medium | Balanced — neither hushed nor explosive |
| `4` | High | Driving, energetic, strong momentum |
| `5` | Explosive | Maximum intensity — loud, relentless, full production |

---

### `theme`
What the song is **about** (subject matter, not feeling). Pick one:

| Value | When to use |
|---|---|
| `Love & Romance` | Being in love, attraction, romantic connection |
| `Heartbreak` | End of a relationship, loss of love, grief over someone |
| `Longing & Desire` | Wanting someone or something you can't have — yearning, unrequited |
| `Loneliness` | Isolation, solitude, feeling unseen or disconnected |
| `Memory & Nostalgia` | Looking back — specific memories, the past, time passing |
| `Freedom & Escape` | Breaking free, running away, living without limits |
| `Empowerment & Self-Worth` | Confidence, self-belief, standing in your own power |
| `Rebellion & Protest` | Pushing back against systems, people, or norms — defiance of something external |
| `Coming of Age` | Growing up, crossing thresholds, youth and identity |
| `Hope & Perseverance` | Holding on, making it through, light at the end of the tunnel |

**Mood vs. theme shortcut:**
- "Green Light" by Lorde → mood: `Euphoric`, theme: `Heartbreak` (it feels euphoric but it's about moving on from a breakup)
- "Nightswimming" by R.E.M. → mood: `Melancholy`, theme: `Memory & Nostalgia`

---

### `language`
Primary language of the lyrics.
```
English   French   Spanish   Portuguese   Korean   Japanese
Arabic    German   Italian   Swedish      Hindi
```
Use `English` for songs that are primarily English even if there's a brief line in another language.

---

### `published_at`
When the entry becomes visible in the app. Set this to **midnight Toronto time** of the
entry's `date` — NOT midnight UTC. Midnight UTC is 8 PM the previous evening in Toronto,
which used to leak tomorrow's song into the Vault early.

Easiest way — let Postgres convert for you in the INSERT:
```sql
(DATE '2026-06-15')::timestamp AT TIME ZONE 'America/Toronto'
```
Or as a literal (04:00 UTC in summer/EDT, 05:00 UTC in winter/EST):
```
Format: YYYY-MM-DD 04:00:00+00
Example: 2026-06-15 04:00:00+00
```
Set it in the **past** if you want the entry to appear immediately. Set it to a **future date** to queue it.

---

## Quick SQL Templates

### Add a new entry
```sql
INSERT INTO daily_entries (
  date, title, artist,
  album_art_url, journal_md,
  apple_music_id, spotify_uri,
  genre, year, mood, energy, theme, language,
  published_at
) VALUES (
  '2026-06-15',
  'Song Title',
  'Artist Name',
  'https://artwork-url.jpg',
  'Your journal write-up here.',
  '1234567890',
  'spotify:track:xxxxxxxxxxxxxxxxxxxx',
  'Pop', 2024, 'Joyful', 4, 'Love & Romance', 'English',
  (DATE '2026-06-15')::timestamp AT TIME ZONE 'America/Toronto'
);
```

### Edit a single field
```sql
UPDATE daily_entries
SET mood = 'Defiant'
WHERE title = 'drop dead' AND artist = 'Olivia Rodrigo';
```

### Edit multiple fields
```sql
UPDATE daily_entries
SET mood = 'Euphoric', energy = 5, theme = 'Freedom & Escape'
WHERE title = 'drop dead';
```

### Check what you have queued
```sql
SELECT date, title, artist, mood, energy, theme
FROM daily_entries
ORDER BY date ASC;
```

---

## How the Insights Archetype is Decided

The archetype on the Insights page is driven entirely by your **liked songs' mood**:

| Your top liked mood | Archetype |
|---|---|
| Euphoric | Party Animal |
| Joyful | Flower Child |
| Tender | Hopeless Romantic |
| Serene | The Hippie |
| Dreamy | The Stargazer |
| Nostalgic | Born in the Wrong Generation |
| Melancholy | The Melancholic |
| Defiant | Loud & Proud |
| Dark | The Outsider |
| No clear dominant | The Shapeshifter |

The supporting signals (genre, decade, theme) appear as flavor text ("1980s songs are glowing brighter...") but don't change the archetype — only mood does.
