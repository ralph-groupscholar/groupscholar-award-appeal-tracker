create schema if not exists groupscholar_award_appeal_tracker;

create extension if not exists pgcrypto;

create table if not exists groupscholar_award_appeal_tracker.appeals (
  id uuid primary key default gen_random_uuid(),
  scholar_name text not null,
  award_program text not null,
  appeal_reason text not null,
  appeal_amount numeric(12, 2) not null,
  status text not null default 'pending',
  submitted_on date not null,
  owner text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists appeals_status_idx
  on groupscholar_award_appeal_tracker.appeals (status);

create index if not exists appeals_submitted_on_idx
  on groupscholar_award_appeal_tracker.appeals (submitted_on desc);
