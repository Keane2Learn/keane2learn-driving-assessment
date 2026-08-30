# Driving Test Centre Guide

A free, static site: official DVSA pass rates per UK driving test centre, plus
anonymous reviews from candidates and instructors. No named examiners, no
scraped social media — pass-rate data comes from DVSA's own published
statistics, and reviews are submitted directly by real users of the site.

Single static page (`index.html`) + a Postgres backend on Supabase's free
tier. No server to run, no build step.

## 1. Create a free Supabase project

1. Go to [supabase.com](https://supabase.com) → New project (free tier is enough).
2. Once it's created, open **SQL Editor** and run the contents of `schema.sql`
   in this repo. That creates three tables — `test_centres`, `pass_rate_stats`,
   `reviews` — with row-level security already locked down (public can read
   centres/pass-rates and submit reviews; only you, logged into the dashboard,
   can approve reviews or import pass-rate data).
3. Go to **Project Settings → API** and copy the **Project URL** and the
   **anon public key**.
4. Open `index.html` in this repo and paste them into the two constants near
   the top of the `<script>` block:
   ```js
   const SUPABASE_URL = 'https://xxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJ...';
   ```
   The anon key is safe to ship in client-side code — it's designed to be
   public, and row-level security is what actually protects the data.

## 2. Load test centres and pass rates

`import_real_data.sql` has the real thing: 318 UK car test centres with
official 2024–25 data, built from three DVSA releases —
[gov.uk/government/statistics/driving-test-statistics](https://www.gov.uk/government/statistics/driving-test-statistics),
Open Government Licence v3.0:

- **DRT122A** — overall pass rate per centre
- **DRT122C** — first-attempt pass rate + zero-fault passes per centre
- **DRT122D** — pass rate by age (17–25) per centre

Paste the file's contents into the Supabase SQL Editor and run it — it
migrates the schema (adds the first-attempt and age-breakdown tables) and
replaces whatever's in `test_centres`/`pass_rate_stats` with the real data
in one go. `seed_centres.csv` (a placeholder ~45-centre starter list, no
pass rates) is superseded by this and only useful if you want a smaller
sample.

The site lets visitors sort by overall or first-time pass rate, filter to a
specific age band (17–25) — which re-sorts the list by that age's rate
where a centre has it — and each centre's page shows an age-by-age
breakdown when DVSA published one for it. The region filter only appears
once centres have a `region` value set — DVSA's files don't include one, so
it's empty until you backfill it yourself (e.g. from postcode) or drop it.

DVSA republishes both files every autumn — download the new ones, send them
to Claude, and it'll regenerate `import_real_data.sql` for the new year.

## 3. Moderate reviews

Every review submitted through the site lands with `is_approved = false` —
it won't show on the public page until you flip it to `true`. Do that in
**Table Editor → reviews**, filtered to `is_approved = false`. Read each one
before approving; if someone names an examiner despite the form's request
not to, edit the comment to remove the name (or reject it) rather than
approving it as-is.

## 4. Host it for free

This repo is set up so this branch (`claude/test-centre-guide`) is a
self-contained static site — `index.html` at the root, nothing else needed
to serve it.

**GitHub Pages** (free): repo **Settings → Pages → Source → Deploy from a
branch → `claude/test-centre-guide` / `(root)`**. GitHub gives you a URL like
`https://keane2learn.github.io/keane2learn-driving-assessment/` within a
minute or two. You can point a custom domain at it later for free too (just
a DNS record), if you buy one.

## What's deliberately not built yet

- **No admin UI** — moderation and data import happen in the Supabase
  dashboard directly. Fine at low volume; worth a proper admin screen once
  review volume picks up.
- **No spam/abuse protection beyond a honeypot field** — if you get spam
  submissions, add a Turnstile/hCaptcha widget to the review form next.
- **No AI-written summaries** — the "what candidates say" section is
  computed from simple keyword matching across approved reviews, entirely
  client-side, no API key or ongoing cost. An LLM-generated summary is a
  reasonable Phase 2 if the keyword tags feel too blunt once there's real
  review volume — but it needs a small server-side function (an API key
  can't live in client-side code), and needs the same no-names instruction
  as the review form itself.
