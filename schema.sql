-- Driving Test Centre Guide — Supabase schema
-- Run this once in your Supabase project's SQL editor (Dashboard > SQL Editor > New query).

create extension if not exists pgcrypto;

create table if not exists test_centres (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  town text not null,
  county text,
  region text,
  postcode text,
  created_at timestamptz not null default now()
);

create table if not exists pass_rate_stats (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references test_centres(id) on delete cascade,
  period_label text not null,           -- e.g. '2024-25'
  tests_conducted integer check (tests_conducted >= 0),
  tests_passed integer check (tests_passed >= 0),
  first_attempt_tests integer check (first_attempt_tests >= 0),
  first_attempt_passes integer check (first_attempt_passes >= 0),
  first_attempt_zero_fault_passes integer check (first_attempt_zero_fault_passes >= 0),
  automatic_tests integer check (automatic_tests >= 0),
  automatic_passes integer check (automatic_passes >= 0),
  source text not null default 'DVSA DRT122A/C/E (Open Government Licence v3.0)',
  imported_at timestamptz not null default now(),
  unique (centre_id, period_label)
);
-- tests_conducted/tests_passed and the first_attempt_* columns are all
-- nullable: a handful of very-low-volume centres only appear in one of
-- DVSA's two source files (DRT122A / DRT122C), not both.

create table if not exists age_pass_rates (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references test_centres(id) on delete cascade,
  period_label text not null,
  age integer not null check (age between 17 and 25),
  tests_conducted integer not null check (tests_conducted >= 0),
  tests_passed integer not null check (tests_passed >= 0),
  unique (centre_id, period_label, age)
);
-- DVSA (DRT122D) only publishes a per-centre age breakdown for 17-25 year olds.

create table if not exists wait_time_stats (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references test_centres(id) on delete cascade,
  period_label text not null,          -- e.g. 'July 2026' — a single month, not a year
  median_wait_weeks numeric,
  weeks_to_10pct_availability numeric,
  availability_pct numeric,
  unique (centre_id, period_label)
);
-- From DRT122F. Unlike the pass-rate tables this is monthly, not annual —
-- re-import periodically if you want it to stay current.

create table if not exists route_traces (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references test_centres(id) on delete cascade,
  points jsonb not null,                -- [[lat, lng], [lat, lng], ...]
  distance_km numeric,
  duration_min numeric,
  submitted_role text check (submitted_role in ('pupil', 'instructor')),
  notes text check (char_length(notes) <= 500),
  is_approved boolean not null default false,
  created_at timestamptz not null default now()
);
-- GPS traces recorded in-browser during practice/mock-test drives near a
-- centre (never during the real test — phones must be off then). Same
-- moderation model as reviews: lands unapproved, you verify before it
-- shows publicly.

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  centre_id uuid not null references test_centres(id) on delete cascade,
  rating integer check (rating between 1 and 5),
  outcome text check (outcome in ('pass', 'fail')),
  reviewer_role text check (reviewer_role in ('pupil', 'instructor')),
  comment text check (char_length(comment) <= 1000),
  route_notes text check (char_length(route_notes) <= 500),
  is_approved boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_pass_rate_stats_centre on pass_rate_stats(centre_id);
create index if not exists idx_age_pass_rates_centre on age_pass_rates(centre_id);
create index if not exists idx_wait_time_stats_centre on wait_time_stats(centre_id);
create index if not exists idx_route_traces_centre on route_traces(centre_id, is_approved);
create index if not exists idx_reviews_centre on reviews(centre_id);
create index if not exists idx_reviews_approved on reviews(centre_id, is_approved);

alter table test_centres enable row level security;
alter table pass_rate_stats enable row level security;
alter table age_pass_rates enable row level security;
alter table wait_time_stats enable row level security;
alter table route_traces enable row level security;
alter table reviews enable row level security;

-- Anyone (anon key) can read centres and pass-rate stats.
create policy "public read test_centres" on test_centres for select using (true);
create policy "public read pass_rate_stats" on pass_rate_stats for select using (true);
create policy "public read age_pass_rates" on age_pass_rates for select using (true);
create policy "public read wait_time_stats" on wait_time_stats for select using (true);

-- Anyone can read reviews, but only once approved by you.
create policy "public read approved reviews" on reviews for select using (is_approved = true);

-- Anyone can submit a review (it lands unapproved until you moderate it).
create policy "public submit review" on reviews for insert with check (is_approved = false);

-- Same pattern for GPS route traces.
create policy "public read approved route_traces" on route_traces for select using (is_approved = true);
create policy "public submit route_traces" on route_traces for insert with check (is_approved = false);

-- No public update/delete policies on any table: moderation and data
-- import happen from the Supabase Table Editor / SQL editor, logged in
-- as the project owner (which bypasses RLS), not from the public site.
