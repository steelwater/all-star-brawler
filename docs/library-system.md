# Milestone 2: Fighters Library

Authority: [Milestone 2 Crew Brief](https://docs.google.com/document/d/1eNs8ujXtus0vJUQg-FMZHwi1QyI5dmRC73KTi_WYbMY/edit). Implementation date: 17 September 2026. Owner: Dan. Branch: `feature/library-system`.

## Storage and boundaries

`LibraryStore` owns filesystem operations. Each item is an independent JSON file under `user://library/items/<id>.json`, with a cryptographically generated 128-bit hexadecimal ID unrelated to its display name. Saves write and flush a temporary sibling before renaming it over the destination. Failed writes leave the previous record in place; leftover `.tmp` files are ignored. This is a single-process local store; simultaneous writers are not supported.

The version 1 envelope contains `schema_version`, `id`, `type`, `display_name`, integer Unix `created_at`/`modified_at` timestamps, `source`, and `payload`. Source is currently `{ "kind": "player_created" }`. Only `type = fighter` is implemented. Unknown types/versions are skipped and preserved rather than migrated or reset. Add explicit type validation and migration when Milestone 3 defines its payloads; keep the envelope and existing IDs.

`LibraryItem` validates records and maps the fighter payload to a match slot. Current payload fields are `character_id` (prototype fighter), `color` (six-digit RGB), and `weapon_id` (sword or hammer). Resource paths from disk are never loaded; built-in weapons resolve through an allowlist. Reads are bounded to 64 KiB per record. Invalid entries are isolated and reported in the Library. Updates and deletion refuse invalid/unsupported records.

`FighterSlotConfig.library_fighter_id` is a match reference. Applying a record copies its configuration into the slot while preserving controller, difficulty, team, input ownership and spawn. A running round uses this snapshot. Menu selection re-reads the record before starting, so unavailable records cannot partially apply a setup. Selecting Prototype Fighter restores that slot's built-in color and weapon.

`LibraryPanel` owns browsing, editing and confirmations. `FighterPreview` uses the actual fighter scene in an isolated viewport, disables simulation and removes it from the fighters group. Previews are rendered only while visible and are rebuilt from saved values, so no thumbnail files or shared assets need deletion.

## Verification performed

Godot 4.7.2 stable on macOS:

- Existing headless combat suite: **136 assertions passed**, with no engine warnings/errors in the final run.
- Library suite: **34 assertions passed**, both headless and in a rendered window. Covers create, load, update, duplicate independence, delete, empty/invalid/future records, failure to write, slot identity separation, human/CPU team selection, confirmations, input events and default gameplay.
- Separate Godot write/read processes restored a saved fighter's name, color and weapon, using an isolated fixture.
- Rendered Library, editor and Match Setup inspected at 1280 × 720. Cards show the actual saved color and weapon; an opaque panel improves readability over the arena. Card columns adapt to the available scroll width.
- Keyboard F3, mouse activation and simulated controller confirmation exercised through input events. Tests use unique temporary storage and remove only their fixtures.
- Source diff and whitespace reviewed. No additional dependency or imported asset was introduced.

Run from the repository root:

```sh
godot --headless --path . --script res://tests/library_test.gd
godot --headless --path . --script res://tests/smoke_test.gd
```

## Remaining acceptance checks

Dan should perform the Crew Brief's full interactive create/save/restart/select/battle/edit/copy/delete loop, including human and CPU team matches and navigation with a physical controller. Automated input events and rendered inspection do not establish physical-device usability. Verify smaller/larger window readability during that playtest. No production export/build was produced; this repository has no export preset or separate lint/typecheck command. Godot script loading and executable tests provide language validation.

Milestone 3 imports, weapons/armor authoring, tagging/search, stage building, cloud services and packaging remain excluded. Existing untracked source artwork is untouched and excluded from the review. Editor-generated UID sidecars for unrelated pre-existing scripts are also excluded.

## Review and rollback

Work is isolated on the feature branch. No merge, deployment, release or user-save migration is performed. The base `main` remains the rollback point. Returning to the base code leaves Library records in `user://` untouched for later use. Keep the PR draft until the remaining playtest acceptance checks are complete.
