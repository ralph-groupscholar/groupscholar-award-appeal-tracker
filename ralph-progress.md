# Ralph Progress Log

## Iteration 1
- Created the Dart CLI for logging award appeals with add/list/update-status/summary commands.
- Added Postgres schema + seed data, env-based configuration, and formatter utilities.
- Documented setup, usage, and testing in the README.

## Iteration 2
- Added an aging report command with minimum-days and include-closed options.
- Added days-between formatter helper and test coverage.
- Updated README and changelog for the new report workflow.

## Iteration 3
- Implemented the days-between helper used by the aging report output.
- Added unit tests to cover day-difference calculations.
- Updated the changelog for the bugfix release.
