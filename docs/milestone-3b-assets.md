# All Star Brawler — Milestone 3B asset integration

Date: 5 October 2026. Owner: Dan. Branch: `feature/milestone-3b-itch-asset-sourcing`.
Status: Testing / final review in [PR #5](https://github.com/steelwater/all-star-brawler/pull/5). Dan completed local playtesting without issues on 17 November 2026. No merge or release.

Authority: [Milestone 3B Crew Brief](https://docs.google.com/document/d/1YgUONKqPHaWhjw0nWHumdzkbQ7sR5G262O36nuyazcg/edit), [Project Roadmap](https://docs.google.com/document/d/1QNaO7_r-jq0iHNmX0NvAtFn4yTtqDza7BmroskLLtSE/edit). Dan approved the recommended small Kenney selection on 5 October 2026.

## Decision and scope

Context: the existing Library saved color/weapon fighter configurations but contained no bundled third-party content. The purchase list includes many top-down, 3D and restricted-use packs that do not directly serve this side-view creator game.

Decision: import seven unmodified files from three official, individually downloadable Kenney CC0 packs. Use a fighter customization rather than inventing weapon art: two hairstyles, two weapon impact sounds, one background and two decorative props. Kenney Game Assets 1 was the preferred purchased source; individual official free downloads are the approved acquisition route used here. This does not establish that every selected file belongs to that older purchased bundle.

Alternatives considered: Shackhal and Eder Muniz for separate pixel-art arenas; modular full-body replacement; rendering 3D vehicles into sprites. Deferred to keep the content set coherent and avoid new animation/conversion pipelines. Platformer Pack Medieval was downloaded and inspected but contributes no files: scenery overlaps this small sample and it contains no weapon sprites.

Consequences: a small working Library sample with permissive redistribution, preserved combat balance, and optional backward-compatible fighter fields. No Stage Builder, armor system, new weapon behaviors, Sound Studio, general import UI, dependency, account, or network runtime is added.

## Included manifest

The authoritative machine-readable manifest is [`scripts/asset_catalog.gd`](../scripts/asset_catalog.gd). It records each original filename, SHA-256, dimensions/format, category, tags, modifications and pack reference; packs record archive SHA-256, creator, public source URL, CC0 terms, original license path, acquisition and review date. Private purchase download keys are not copied into project files.

| Library item | Category | Source pack / original file | Runtime use |
| --- | --- | --- | --- |
| Short sweep | Fighter Parts | Modular Characters / `PNG/Hair/Black/blackMan1.png` | Selectable hair, 40×30 draw rectangle anchored to head |
| Long sweep | Fighter Parts | Modular Characters / `PNG/Hair/Brown 1/brown1Woman1.png` | Selectable hair, 40×72 draw rectangle anchored to head |
| Rolling hills | Backgrounds | Background Elements / `PNG/Flat/hills1.png` | Muted arena backdrop |
| Autumn tree | Stage Objects | Background Elements / `PNG/tree01.png` | Decorative arena prop |
| Grey castle | Stage Objects | Background Elements / `PNG/castle_grey.png` | Decorative arena prop |
| Metal impact | Sounds | Impact Sounds / `Audio/impactMetal_medium_000.ogg` | Selectable weapon hit sound |
| Wood impact | Sounds | Impact Sounds / `Audio/impactWood_medium_000.ogg` | Selectable weapon hit sound |

Original PNG/OGG bytes are unchanged; files were renamed. Scaling, mirroring, scenery tint and playback volume happen at runtime. Audio previews use -12 dB; customized weapon impacts use -8 dB. No whole pack or ZIP is included. Original license files are preserved alongside each selected group. CC0 allows commercial use, modification and redistribution; attribution is optional (Kenney / kenney.nl). Acknowledgment remains visible in the Library and manifest.

Official sources: [Modular Characters](https://kenney.nl/assets/modular-characters), [Background Elements](https://kenney.nl/assets/background-elements), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

## Purchased-pack review outcomes

The assessment used public product pages and published terms; only the four downloaded Kenney packs received archive inspection. This is not a claim that all purchased archives were inspected.

| Pack | Outcome and reason |
| --- | --- |
| [Kenney Game Assets 1](https://kenney.itch.io/kenney-game-assets-1) | Preferred family; CC0. Used official individual packs instead of the full purchased bundle. |
| [Multi Platformer Tileset](https://shackhal.itch.io/multi-platformer-tileset) | Strong future pixel-art arena candidate; page lists CC0. Deferred to avoid mixing visual styles. |
| [Infinite Runner](https://edermunizz.itch.io/infinite-runner) | Strong layered-background candidate. [Current terms](https://edermunizlicense.carrd.co/) allow commercial use and open-source use with credit/license; asset redistribution remains restricted. Deferred. |
| [HUGE pixelart](https://samvieten.itch.io/huge-pixelart-asset-pack) | Candidate props/vehicles; small pixel grid and unresolved source/tool redistribution make it unnecessary for this set. |
| [CanariPack 8BIT TopDown](https://canarigames.itch.io/canaripack-8bit-topdown) | Potential icons/audio; top-down art and raw-file redistribution restrictions. Deferred. |
| [Tiny Adventure Pack Plus](https://vryell.itch.io/tiny-adventure-pack-plus) | Potential icons/props; perspective and redistribution restrictions. Deferred. |
| [Raou Interior](https://raou.itch.io/top-down-interior-tileset) | Top-down perspective; creator specifies protection of raw files in editor use. Deferred. |
| [Heroic Overworld](https://iknowkingrabbit.itch.io/heroic-overworld) | Strategy/RPG map perspective, attribution and hosting restrictions; little direct benefit. Deferred. |
| [Low Poly Auto Racing](https://devilsworkshop.itch.io/low-poly-auto-racing-car-pack) | 3D-to-2D conversion would add work; detailed redistribution terms still need inspection. Deferred. |
| [Low Poly City Builder](https://devilsworkshop.itch.io/low-poly-3d-city-builder-devilsworkshop) | 3D conversion plus restrictions on source/tool redistribution. Deferred. |
| [HPS Cartography](https://natetreme.itch.io/cartographykit) | Excluded: completed maps allowed with credit but individual tiles cannot be distributed; poor Library fit. |
| [Spaceland](https://cone.itch.io/spaceland) | Excluded: noncommercial hex-map art and individual-asset distribution restrictions. |
| [CleanCutGames Fantasy Characters](https://cleancutgames.itch.io/pixelart-fantasy-characters) | Held: itch listing inaccessible during assessment; other-store terms do not establish this purchase's license. |

## Verification

Godot 4.7.2 stable on macOS:

- Asset import and script parsing succeeded.
- Existing combat smoke suite: 136 assertions passed.
- Existing Library suite: 34 assertions passed after the UI change.
- New bundled-asset suite: 54 assertions passed. Covers original-byte hashes/licenses, transparency/audio decode, invalid IDs/categories/types, fresh-store save/load, duplicate/edit/clear choices, isolated sound overrides, browser filters/empty results, card-to-Creator flow, previews, actual match configuration, head pose positions, throw/pickup, audio playback initiation and CPU combat reaching a winner.
- Rendered Library, Creator and Arena inspected at 1280×720; Creator and catalog also inspected at 960×540 and 1600×900. Hair scaling, transparency, scenery layering and control visibility checked. Creator content is scrollable when needed.
- Final source diff and whitespace reviewed. Original source artwork and unrelated pre-existing UID sidecars preserved.

Commands:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/library_test.gd
godot --headless --path . --script res://tests/asset_test.gd --fixed-fps 60
```

Optional rendered evidence: create a destination directory and run `godot --path . --script res://tests/asset_test.gd --fixed-fps 60 -- --capture=/absolute/output/directory`. Evidence is generated outside Git. The test uses an isolated randomized user-data directory and removes only its fixtures. A short shutdown delay allows audio playback cleanup when fixed-FPS simulation outruns the mixer.

## Remaining acceptance and rollback

Dan completed the general local playtest without issues (PR comment/screenshots, 17 November 2026). Focused follow-up navigation and sound regressions are checked separately. Reproduction flow: F3 → Bundled Assets → select hair → name fighter → choose sound and Listen → Save → Use Fighter → Start Match. Verify keyboard/physical-controller navigation, subjective sound quality/volume and game feel, reload the game, then edit/duplicate the fighter. Audio decoding/playback initiation and rendered inspection do not establish subjective listening quality or physical-controller usability.

No separate lint/typecheck script, production export preset or configured CI workflow exists in this checkout. Godot import/script execution provides language validation; no production export, merge or release was performed. PR #5 is open; no GitHub Actions checks are configured. Uplink and required CI evaluation remain later work. Keep Milestone 3/3B open until review, merge and Captain playtesting meet the brief.

The feature branch is based on main `51731bf`. Implementation is committed and pushed on PR #5; follow-up fixes remain on the same branch. No save migration, deletion or reset occurred. Returning to the previous code leaves saves in place, but re-saving a customized fighter with old code would drop its new optional hair/sound fields; preserve saves before testing a rollback. Temporary complete archives remain in `/private/tmp/all-star-brawler-3b` only; selected licensed source files are the durable project content.

## Prepared PR description

Title: Milestone 3B: Integrate curated Kenney assets into the Library

The Library now browses seven licensed Kenney assets and lets players save hairstyles and weapon hit sounds with a fighter, preview them and use them in matches. A small non-colliding Arena scenery sample exercises the stage categories. Existing fighter records, combat values and source artwork are preserved.

Uses original CC0 PNG/OGG files from three official packs, with original notices and a central source/hash manifest. Other purchased candidates and their deferral reasons are recorded above. Verification: 136 combat, 34 Library and 54 asset assertions; rendered desktop inspection. Remaining limits: Captain listening/controller/game-feel acceptance, no production export or remote CI run. No new dependencies or general creator subsystems.


## Review follow-up — 17 November 2026

Creator scrolling follows keyboard/controller focus. Original weapon sounds preserve scene playback levels: melee -5 dB, thrown -4 dB. Kenney overrides remain -8 dB. Added regression coverage and CHANGELOG.md.

Roadmap direction approved 17 November 2026: each purchased/imported pack may define its own coherent arena/playset theme. Visual consistency is required within an arena, not across the entire game. Top-down/map art may be composed as background/foreground scenery rather than literal side-view collision geometry. Heroic Overworld → Highland Overlook is the reference: battle on a high mountain ridge with a fantasy country visible below. Earlier perspective/style deferrals above describe this initial seven-file selection, not permanent exclusions. Reassess those packs under this direction after license review. Full Stage Builder remains Milestone 4; 3B remains license-safe sourcing, metadata, Library integration and representative use.

Follow-up verification: Godot 4.7.2 combat 136, Library 34, expanded assets 67 assertions passed. Focus regression constrains the Creator viewport and exercises Tab/down actions; Save/Cancel visibility and original/custom melee/thrown volumes are covered. Rendered focused suite also runs at 960×540. Physical controller and subjective listening were not repeated; Dan’s earlier playtest remains recorded.
