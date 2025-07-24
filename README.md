# Group Scholar Award Appeal Tracker

Track scholarship award appeals with a fast CLI and a production-ready Postgres backend. This tool keeps the appeals queue visible, highlights status counts, and makes it easy to log updates for the operations team.

## Features

- Log new award appeals with program, reason, amount, and owner.
- List appeals with optional status filtering.
- Update appeal statuses with a single command.
- Spot aging appeals that need follow-up.
- Summarize queue volume and total dollars by status.

## Tech Stack

- Dart CLI
- Postgres (production)
- `postgres` and `args` packages

## Getting Started

Install dependencies:

```bash
cd /Users/ralph/projects/groupscholar-award-appeal-tracker
dart pub get
```

Set environment variables (use production values in the deployed environment only):

```bash
export PGHOST=your-host
export PGPORT=5432
export PGDATABASE=your-db
export PGUSER=your-user
export PGPASSWORD=your-password
export PGSSLMODE=require
```

Run the CLI:

```bash
dart run bin/groupscholar_award_appeal_tracker.dart --help
```

### Commands

```bash
# Add an appeal
dart run bin/groupscholar_award_appeal_tracker.dart add \
  --scholar "Avery Martinez" \
  --program "STEM Fellows" \
  --reason "Missing documentation clarified" \
  --amount 1200 \
  --status pending \
  --submitted-on 2026-02-01 \
  --owner "Jordan Lee"

# List appeals
dart run bin/groupscholar_award_appeal_tracker.dart list --status pending

# Update status
dart run bin/groupscholar_award_appeal_tracker.dart update-status \
  --id <uuid> --status approved --notes "Final approval confirmed"

# Summary
dart run bin/groupscholar_award_appeal_tracker.dart summary

# Aging report
dart run bin/groupscholar_award_appeal_tracker.dart aging --min-days 10
```

## Database Setup

The schema and seed data live in `sql/schema.sql` and `sql/seed.sql`.

```bash
psql "$DATABASE_URL" -f sql/schema.sql
psql "$DATABASE_URL" -f sql/seed.sql
```

Use a dedicated schema prefix (`groupscholar_award_appeal_tracker`) to avoid collisions.

## Testing

```bash
dart test
```
