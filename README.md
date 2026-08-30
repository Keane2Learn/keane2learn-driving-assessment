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

## 2. Load test centres, pass rates and waiting times

The site has two top-level sections, chosen from a home screen: **Practical
test** (the full per-centre experience) and **Theory test** (a national-only
overview — see below for why). `import_real_data.sql` covers the practical
side: 323 UK car test centres built from five DVSA releases —
[gov.uk/government/statistics/driving-test-statistics](https://www.gov.uk/government/statistics/driving-test-statistics),
Open Government Licence v3.0:

- **DRT122A** — overall pass rate per centre (2024–25)
- **DRT122C** — first-attempt pass rate + zero-fault passes per centre
- **DRT122D** — pass rate by age (17–25) per centre
- **DRT122E** — automatic-gearbox pass rate per centre
- **DRT122F** — median waiting time and slot availability per centre
  (latest available month), and each centre's **region** — which is also
  what feeds the region filter, so it only has options once this file's
  been imported

Paste `import_real_data.sql`'s contents into the Supabase SQL Editor and
run it — it migrates the schema (adds the first-attempt, age-breakdown and
waiting-time tables/columns) and replaces whatever's in
`test_centres`/`pass_rate_stats` with the real data in one go.
`seed_centres.csv` (a placeholder ~45-centre starter list, no pass rates)
is fully superseded and only useful if you want a smaller sample.
A handful of centre names don't match cleanly across DVSA's own files
(different qualifiers in different releases, e.g. "Leeds" vs. "Leeds
(Colton Mill)") — rather than guess at a merge, those stayed as separate
rows; the SQL file's header comment lists them.

The site lets visitors sort by overall or first-time pass rate, filter to a
specific age band (17–25) — which re-sorts the list by that age's rate
where a centre has it — and each centre's page shows pass rate, an
age-by-age breakdown, and (where available) median wait time and booking
availability as of the latest DRT122F month.

DVSA republishes these every autumn (waiting times monthly) — download the
new files, send them to Claude, and it'll regenerate `import_real_data.sql`.

### National context panel + theory test section

Five more files (DRT121A, DRT121D, DRT121E, DRT111C, DRT121G) are GB-wide
or regional, not per-centre, so they don't fit the practical-test schema —
they became a collapsible "National picture" card at the top of the
practical list (GB pass rate, first-time pass rate, zero-fault share,
pass rate by attempt number, median wait by region) and the **Theory
test** home-screen option (national pass rate + year-by-year trend from
DRT111C). None of this is in Supabase; it's hardcoded as `NATIONAL_STATS`
and `THEORY_HISTORY` near the top of `index.html`'s script, since it's a
couple dozen numbers that change once a year, not something worth a
database table and RLS policies for. To refresh next year: download the
same files, send them to Claude, and ask it to regenerate those objects.

Theory test only gets a national trend, deliberately not a per-centre
list: it's a standardised computer-based test at shared venues, not
examiner-led, and DVSA doesn't publish (and there's no real reason to
expect) meaningful per-venue variation the way there is for the practical
test.

### GPS-recorded practice routes

Since DVSA doesn't publish official test routes (deliberately, since 2010 —
see the in-app copy for why) and third-party sites that claim to have them
either republish DVSA's pre-2010 data (their own about page admits it may
be stale) or forbid scraping in their terms, routes here are recorded
first-hand: a "Record one" link on each centre's page uses the browser's
location API (Leaflet + OpenStreetMap for the map — free, no API key) to
trace a drive during a **practice or mock-test** lesson near the centre —
never during the actual DVSA test, since phones have to be off then. Same
moderation model as reviews: lands unapproved in the new `route_traces`
table, you verify it looks like a sensible real route before publishing.

This needs a schema update if you already ran an earlier `import_real_data.sql` —
`schema.sql` now includes the `route_traces` table; either re-run the
relevant `create table` block from it, or run the full file again (it's
idempotent — `if not exists` throughout — and won't touch your existing
centre/pass-rate data).

## 3. Moderate reviews and routes

Every review or route submitted through the site lands with
`is_approved = false` — nothing shows on the public page until you flip it
to `true`. Do that in **Table Editor → reviews** / **route_traces**,
filtered to `is_approved = false`. Read each review before approving; if
someone names an examiner despite the form's request not to, edit the
comment to remove the name (or reject it) rather than approving as-is. For
routes, sanity-check that the points form a plausible local drive (Table
Editor will show the raw `points` JSON — not a visual map, but enough to
spot an obviously bogus submission) before approving.

## 4. Host it for free

This repo is set up so this branch (`claude/test-centre-guide`) is a
self-contained static site — `index.html` at the root, nothing else needed
to serve it.

**GitHub Pages** (free): repo **Settings → Pages → Source → Deploy from a
branch → `claude/test-centre-guide` / `(root)`**. GitHub gives you a URL like
`https://keane2learn.github.io/keane2learn-driving-assessment/` within a
minute or two. You can point a custom domain at it later for free too (just
a DNS record), if you buy one.

### SEO: a static page per test centre

The main app is a single-page app — great for interactivity, bad for
search engines, since Google can't easily index 323 separate centre pages
out of one JS-rendered `index.html`. To fix that, `centres/<slug>.html`
has one plain, pre-rendered static HTML file per centre (no JS needed to
see the content), each with its own `<title>`, meta description, and the
centre's pass rate/wait time baked directly into the HTML — plus a button
through to the full interactive app (`index.html?centre=<id>`, which the
main app reads on load to jump straight to that centre). `sitemap.xml` and
`robots.txt` at the repo root point search engines at all of them.

These are generated from `import_real_data.sql` (not live Supabase data,
which this environment can't reach), so they'll go stale the same way the
pass-rate data does — regenerate them the same way, by asking Claude,
whenever you refresh `import_real_data.sql` for a new year. They don't
carry review counts or GPS routes since those are live/dynamic — the
static page's job is just to get found by search engines and hand off to
the real app.

Submit `sitemap.xml` in [Google Search Console](https://search.google.com/search-console)
once the site's live, so Google actually discovers these pages rather than
waiting to stumble on them.

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
