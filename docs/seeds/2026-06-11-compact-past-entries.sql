-- Compact all past entries onto consecutive days ending yesterday (2026-06-10),
-- so the archive looks like a song was released every single day before today.
-- Run in Supabase Dashboard → SQL Editor.
--
-- How it works:
--   * Takes every entry dated before 2026-06-11 (today's entry and the queued
--     future ones are untouched).
--   * Keeps their relative order (oldest stays oldest), just removes the gaps:
--     the most recent old entry lands on 2026-06-10, the one before it on
--     2026-06-09, and so on.
--   * published_at is rewritten to midnight UTC of each entry's new date, so
--     everything stays visible.
--   * Done in two phases inside one transaction: dates are first shifted far
--     into the past so the per-row unique check on `date` can never collide
--     mid-update.
--
-- Preview the result first (no changes):
--   SELECT date AS old_date,
--          DATE '2026-06-11' - row_number() OVER (ORDER BY date DESC)::int AS new_date,
--          title, artist
--   FROM daily_entries
--   WHERE date < '2026-06-11'
--   ORDER BY date DESC;

BEGIN;

-- Phase 1: park all past entries on temporary dates far in the past (~55 years
-- back) so no reassignment in phase 2 can hit a unique-date conflict.
UPDATE daily_entries
SET date = date - 20000
WHERE date < '2026-06-11';

-- Phase 2: lay them back down on consecutive days ending 2026-06-10,
-- newest-first, preserving the original order.
WITH ordered AS (
  SELECT id,
         row_number() OVER (ORDER BY date DESC) AS rn
  FROM daily_entries
  WHERE date < DATE '2026-06-11' - 10000   -- only the rows parked in phase 1
)
UPDATE daily_entries d
SET date         = DATE '2026-06-11' - o.rn::int,
    published_at = (DATE '2026-06-11' - o.rn::int)::timestamptz
FROM ordered o
WHERE d.id = o.id;

COMMIT;

-- Verify: should show an unbroken run of dates ending 2026-06-10.
--   SELECT date, title, artist FROM daily_entries
--   WHERE date < '2026-06-11' ORDER BY date DESC LIMIT 40;
--
-- And confirm there are no gaps (should return 0 rows):
--   SELECT d1.date + 1 AS missing_day
--   FROM daily_entries d1
--   WHERE d1.date < '2026-06-10'
--     AND d1.date >= (SELECT min(date) FROM daily_entries WHERE date < '2026-06-11')
--     AND NOT EXISTS (SELECT 1 FROM daily_entries d2 WHERE d2.date = d1.date + 1);
