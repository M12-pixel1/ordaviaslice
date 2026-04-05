# ORDAVIA Slice 11+12 — Upload Pack for `ordaviaslice`

This package is the **full-code upload pack** for the repository `M12-pixel1/ordaviaslice`.

## What to upload
Upload the contents of this package to the **repo root**.

This root-level overlay contains:
- `app/` — Slice 11+12 models, services, controllers, serializers
- `config/routes.rb` — Slice 12 route scaffold
- `db/` — `clinical_tests` migration and seed script
- `spec/` — factories, model/service/request specs
- `docs/` — Slice 12 docs

## Important
This package is a **code overlay**, not a verified green-CI host integration.
It gives the repo the real Slice 11+12 code files that were missing from the previous docs-only handoff.

## Also included
- `handoff/slice11/` — original Slice 11 package
- `handoff/slice12/` — original Slice 12 package

## Missing host-app files
The target repo still needs a real Rails host app to run CI end-to-end.
For convenience, this package also includes minimal bootstrap placeholders for:
- `Gemfile`
- `Rakefile`
- `config/application.rb`
- `config/boot.rb`
- `config/environment.rb`
- `config.ru`
- `app/controllers/application_controller.rb`
- `app/models/application_record.rb`
- `spec/spec_helper.rb`
- `spec/rails_helper.rb`

These bootstrap files are **scaffolding only**. They are meant to make repo structure explicit until the real ORDAVIA host app code is added.
