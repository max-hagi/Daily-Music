-- Prescheduled daily entries: 2026-06-11 → 2026-07-03 (23 songs)
-- Run in Supabase Dashboard → SQL Editor.
-- Before running, check for date collisions:
--   SELECT date, title FROM daily_entries WHERE date >= '2026-06-11' ORDER BY date;
--
-- Apple Music IDs + artwork pulled from the iTunes API (verified 2026-06-11).
-- Spotify URIs verified via web search 2026-06-11.
-- journal_md left as a placeholder for your own write-ups.
-- published_at = 04:00 UTC = midnight Toronto (EDT), per DAILY-ENTRY-GUIDE.

INSERT INTO daily_entries
  (date, title, artist, album_art_url, journal_md, apple_music_id, spotify_uri, genre, year, mood, energy, theme, language, published_at)
VALUES

-- 1 · Pop / Joyful — giddy queer crush fantasy, Rise and Fall of a Midwest Princess
('2026-06-11', 'Naked In Manhattan', 'Chappell Roan',
 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/42/a0/c5/42a0c5e6-6b98-f1f9-7d6b-6d6c61aba562/23UMGIM84225.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1707413111', 'spotify:track:4LKYOetuIF5c9XjeLBL9av',
 'Pop', 2023, 'Joyful', 4, 'Longing & Desire', 'English', '2026-06-11 04:00:00+00'),

-- 2 · Hip-Hop / Defiant — race, wealth and ownership in America, 4:44
('2026-06-12', 'The Story of O.J.', 'JAY-Z',
 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/ee/d1/da/eed1da86-9e2f-a19b-498a-f03622b183b2/00854242007569.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1440935733', 'spotify:track:6JpN5w95em8SODPiM7W2PH',
 'Hip-Hop/Rap', 2017, 'Defiant', 3, 'Rebellion & Protest', 'English', '2026-06-12 04:00:00+00'),

-- 3 · Pop / Nostalgic — child''s memory of Wilhelm Reich, "something good is gonna happen", Hounds of Love
('2026-06-13', 'Cloudbusting', 'Kate Bush',
 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/62/97/32/62973286-5bb3-0de7-c051-8b2de8d95472/cover.jpg/1200x1200bb.jpg',
 'TODO journal', '1675560844', 'spotify:track:74vfedGgRZKqkbr8gdzvkK',
 'Pop', 1985, 'Nostalgic', 3, 'Hope & Perseverance', 'English', '2026-06-13 04:00:00+00'),

-- 4 · R&B / Joyful — the smoothest hook of the 90s, Another Level
('2026-06-14', 'No Diggity (feat. Dr. Dre & Queen Pen)', 'Blackstreet',
 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/9f/b4/45/9fb4457e-7ab5-0484-a81f-4666ba8fae80/06UMGIM01977.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1440908981', 'spotify:track:0BSUsLKmtxKWFckXM4CVTH',
 'R&B', 1996, 'Joyful', 3, 'Love & Romance', 'English', '2026-06-14 04:00:00+00'),

-- 5 · Alternative / Melancholy — insomniac surrender, Laurel Hell (single Dec 2021)
('2026-06-15', 'Heat Lightning', 'Mitski',
 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/fe/01/99/fe019995-88e4-9e5c-9621-d28953dc9aa5/27273.jpg/1200x1200bb.jpg',
 'TODO journal', '1589296012', 'spotify:track:01vuMD0IeeHeQTSUk0f7iK',
 'Alternative', 2021, 'Melancholy', 2, 'Loneliness', 'English', '2026-06-15 04:00:00+00'),

-- 6 · Country / Defiant — keyed cars and carved leather seats, Some Hearts
('2026-06-16', 'Before He Cheats', 'Carrie Underwood',
 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/e7/14/80/e714805d-8aff-9e66-b25f-c75e5683a130/mzi.omppwbeg.jpg/1200x1200bb.jpg',
 'TODO journal', '214696369', 'spotify:track:0ZUo4YjG4saFnEJhdWp9Bt',
 'Country', 2005, 'Defiant', 4, 'Heartbreak', 'English', '2026-06-16 04:00:00+00'),

-- 7 · Electronic / Dark — commanding, sensual art-R&B, LP1
('2026-06-17', 'Two Weeks', 'FKA twigs',
 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/5d/4b/8e/5d4b8e65-8789-f72b-8748-3acc311c0e6f/889030011893.png/1200x1200bb.jpg',
 'TODO journal', '1546107585', 'spotify:track:7E66uxFz2NtHWAyiGXotha',
 'Electronic', 2014, 'Dark', 3, 'Longing & Desire', 'English', '2026-06-17 04:00:00+00'),

-- 8 · Rock / Melancholy — the apology-as-cathedral closer
('2026-06-18', 'Purple Rain', 'Prince & The Revolution',
 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/c1/b6/79/c1b679f5-d59d-1b3e-62ab-514de20f06c6/093624912002.jpg/1200x1200bb.jpg',
 'TODO journal', '1229320478', 'spotify:track:54X78diSLoUDI3joC2bjMz',
 'Rock', 1984, 'Melancholy', 4, 'Heartbreak', 'English', '2026-06-18 04:00:00+00'),

-- 9 · Hip-Hop / Defiant — self-acceptance anthem, Indicud
('2026-06-19', 'Just What I Am (feat. King Chip)', 'Kid Cudi',
 'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/e4/8f/68/e48f6836-73ad-7d83-6102-655b9d8cf6a3/13UMGIM27810.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1443748667', 'spotify:track:20bJBbPapGQ4bqs0YcA9xY',
 'Hip-Hop/Rap', 2012, 'Defiant', 4, 'Empowerment & Self-Worth', 'English', '2026-06-19 04:00:00+00'),

-- 10 · Pop / Euphoric — ABBA-sampling disco rush, Confessions on a Dance Floor
('2026-06-20', 'Get Together', 'Madonna',
 'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/24/5a/e8/245ae865-c767-310b-c8ee-6b3a05e43fd4/dj.hgvybcjz.jpg/1200x1200bb.jpg',
 'TODO journal', '91990021', 'spotify:track:1AQQ9DdpEemMVTHNz4eG9a',
 'Pop', 2005, 'Euphoric', 4, 'Love & Romance', 'English', '2026-06-20 04:00:00+00'),

-- 11 · Alternative / Dreamy — 9-minute psychedelic haze, NFR! (single Sept 2018)
('2026-06-21', 'Venice Bitch', 'Lana Del Rey',
 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/c6/5f/b9/c65fb9eb-da2f-89a9-b640-2fff1fc3a660/19UMGIM61350.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1474669067', 'spotify:track:3hwQhakFwm9soLEBnSDH17',
 'Alternative', 2018, 'Dreamy', 2, 'Love & Romance', 'English', '2026-06-21 04:00:00+00'),

-- 12 · Hip-Hop / Melancholy — "forever ever?" apology to the ex''s mother, Stankonia
('2026-06-22', 'Ms. Jackson', 'OutKast',
 'https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/d6/21/fb/d621fbde-c099-6794-7102-2692f10c4dbb/886448814283.jpg/1200x1200bb.jpg',
 'TODO journal', '1536684150', 'spotify:track:0I3q5fE6wg7LIfHGngUTnV',
 'Hip-Hop/Rap', 2000, 'Melancholy', 3, 'Heartbreak', 'English', '2026-06-22 04:00:00+00'),

-- 13 · Pop / Defiant — "the best people in life are free", 1989 (original 2014 release)
('2026-06-23', 'New Romantics', 'Taylor Swift',
 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a7/98/d8/a798d867-344d-2bf2-fbfe-d2d1412dcef8/14UMDIM03793.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1440933800', 'spotify:track:0qAIiGFKLdV1xpNlEhjpq8',
 'Pop', 2014, 'Defiant', 4, 'Freedom & Escape', 'English', '2026-06-23 04:00:00+00'),

-- 14 · Rock / Nostalgic — Lindsey''s blue eyes, Street Angel
('2026-06-24', 'Blue Denim', 'Stevie Nicks',
 'https://is1-ssl.mzstatic.com/image/thumb/Music/e5/7e/24/mzi.usdjvpnu.jpg/1200x1200bb.jpg',
 'TODO journal', '218343112', 'spotify:track:1MjyiWINFr2W13nxxqtHQt',
 'Rock', 1994, 'Nostalgic', 3, 'Memory & Nostalgia', 'English', '2026-06-24 04:00:00+00'),

-- 15 · Hip-Hop / Melancholy — unrequited yearning under the IGOR synths
('2026-06-25', 'RUNNING OUT OF TIME', 'Tyler, The Creator',
 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/0c/06/05/0c060581-6242-6a2a-a677-20170f2cf8da/886447710180.jpg/1200x1200bb.jpg',
 'TODO journal', '1463409596', 'spotify:track:5QvBXUm5MglLJ3iBfTX2Wo',
 'Hip-Hop/Rap', 2019, 'Melancholy', 3, 'Longing & Desire', 'English', '2026-06-25 04:00:00+00'),

-- 16 · Pop / Joyful — dancehall farce, Hot Shot (genre note: it''s reggae/dancehall; "Pop" is the closest house genre)
('2026-06-26', 'It Wasn''t Me (feat. Ricardo Ducent)', 'Shaggy',
 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/5b/78/c0/5b78c053-c5d5-5414-6d95-2a9ab3d3c7a6/06UMGIM55575.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1449315876', 'spotify:track:14qcA7es0C210x1BF5bW0S',
 'Pop', 2000, 'Joyful', 4, 'Love & Romance', 'English', '2026-06-26 04:00:00+00'),

-- 17 · Pop / Melancholy — raw piano ballad, "I need you more than dope", ARTPOP
('2026-06-27', 'Dope', 'Lady Gaga',
 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/2e/7c/89/2e7c89f2-f577-0039-52c7-bc3bb3850094/13UAAIM69753.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1451768059', 'spotify:track:1gPCk3KUE83rPdz9QqGsX9',
 'Pop', 2013, 'Melancholy', 2, 'Longing & Desire', 'English', '2026-06-27 04:00:00+00'),

-- 18 · Hip-Hop / Dreamy — woozy DJ Screw tribute, ASTROWORLD
('2026-06-28', 'R.I.P. SCREW', 'Travis Scott',
 'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/e7/49/8f/e7498f65-df8f-bead-d6e3-2a8d4d642a79/886447235317.jpg/1200x1200bb.jpg',
 'TODO journal', '1421658126', 'spotify:track:1uJ2ClzRD6j0VgEgqwdQPX',
 'Hip-Hop/Rap', 2018, 'Dreamy', 2, 'Memory & Nostalgia', 'English', '2026-06-28 04:00:00+00'),

-- 19 · Alternative / Melancholy — "she said I think I''ll go to Boston", All the Stars and Boulevards
('2026-06-29', 'Boston', 'Augustana',
 'https://is1-ssl.mzstatic.com/image/thumb/Features124/v4/95/e2/6c/95e26c5d-a8be-3098-573c-1243c1c8192a/dj.dojjahpn.jpg/1200x1200bb.jpg',
 'TODO journal', '250202445', 'spotify:track:2WZyfujzMweFLnozyUJBkW',
 'Alternative', 2005, 'Melancholy', 2, 'Freedom & Escape', 'English', '2026-06-29 04:00:00+00'),

-- 20 · Hip-Hop / Dark — outlaw romance over that flipped soul loop, Roman Reloaded Re-Up
('2026-06-30', 'High School (feat. Lil Wayne)', 'Nicki Minaj',
 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/6c/1a/9d/6c1a9ddf-7443-1011-16cb-ba45bc8a1bb8/12UMGIM58931.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1440872332', 'spotify:track:6gCBCoHFLabXeHSOXH5l2b',
 'Hip-Hop/Rap', 2012, 'Dark', 3, 'Love & Romance', 'English', '2026-06-30 04:00:00+00'),

-- 21 · Hip-Hop / Tender — Ponderosa Twins soul sample meets devotion, Yeezus
('2026-07-01', 'Bound 2', 'Kanye West',
 'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/3c/56/e7/3c56e717-06a0-b67d-e694-9b6e6e43a5a8/13UAAIM08444.rgb.jpg/1200x1200bb.jpg',
 'TODO journal', '1440873353', 'spotify:track:3sNVsP50132BTNlImLx70i',
 'Hip-Hop/Rap', 2013, 'Tender', 3, 'Love & Romance', 'English', '2026-07-01 04:00:00+00'),

-- 22 · Electronic / Dark — operatic obsession, LUX (lead single Oct 2025)
-- Language note: verses move between German, Spanish and English; Spanish is the closest single value.
('2026-07-02', 'Berghain', 'ROSALÍA, Björk & Yves Tumor',
 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/95/ae/80/95ae8046-a6b9-e493-0def-5ae33d63f43a/196873722672.jpg/1200x1200bb.jpg',
 'TODO journal', '1848167528', 'spotify:track:6V4ntlX6608rd3Ec5SpVhj',
 'Electronic', 2025, 'Dark', 3, 'Longing & Desire', 'Spanish', '2026-07-02 04:00:00+00'),

-- 23 · Pop / Defiant — trashy-glam hyperpop, single (also on WOR$T GIRL IN AMERICA)
('2026-07-03', 'BEAT UP CHANEL$', 'Slayyyter',
 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7a/ec/26/7aec26e2-09ca-79f0-f75c-fe8943611491/196873376530.jpg/1200x1200bb.jpg',
 'TODO journal', '1828975123', 'spotify:track:10wJ35whDsMVQ04fhkR5QS',
 'Pop', 2025, 'Defiant', 4, 'Empowerment & Self-Worth', 'English', '2026-07-03 04:00:00+00');

-- Sanity check after running:
--   SELECT date, title, artist, mood, energy, theme FROM daily_entries
--   WHERE date BETWEEN '2026-06-11' AND '2026-07-03' ORDER BY date;
