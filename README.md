# All Star Brawler

All Star Brawler is a small Godot prototype for testing a configurable 2D brawler with interchangeable weapons, human or CPU control, free-for-all and team matches, and modular stages.

## Prototype scope

The prototype uses **Godot 4.7.2 stable** and **GDScript**. It includes:

- One shared fighter/combat implementation driven by human or CPU commands
- Eight independently configurable fighter slots
- Human, Easy CPU, Medium CPU, Hard CPU, or Disabled control per slot
- Free-for-all and multi-team battles with optional teammate hits
- Data-driven sword and hammer loadouts, weapon throwing, pickup, and thrown damage
- Movement, jumping, crouching, attacks, kicks, blocking, taunts, health, knockback, and match restart
- A local Fighters Library with names, color/weapon customization, previews, editing, duplication, and confirmed deletion
- An eight-spawn test arena and safe fallback spawns for stages with fewer authored points
- A moving Freeway stage whose road drains health

General asset importing, armor, stage creation, networking, progression, mobile controls, and production packaging remain outside this prototype.

## Run the prototype

1. Install [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/).
2. Import this repository's `project.godot` in the Godot Project Manager.
3. Run the project with **F5**.

Open **Match Setup** or press `Tab` to configure up to eight slots. Every enabled slot exposes its character, Human/CPU control type, and CPU difficulty when applicable. Team assignments and the **Hit Teammates** option appear only for Team Battle.

Only two local human input maps exist in this prototype. Match Setup restricts Fighters 3–8 to CPU or Disabled until controller/device mapping is expanded.

## Fighters Library

Click **Library (F3)** or press `F3` to open the collection. Controller Menu/Start also opens it; D-pad, confirm (bottom face button), and back (right face button) operate menus. Fighter names still use keyboard text entry. This does not add gamepad combat or additional human input maps.

Choose **Create Fighter**, enter a name, pick one of the existing eight colors and either Sword or Hammer, then **Save Fighter**. Use **Edit**, **Copy**, or **Delete** on a fighter card. Unsaved edits and deletion require confirmation.

Choose a target slot and **Use Fighter**, then set Human/CPU, difficulty and team in Match Setup before **Start Match**. Each slot also has a character selector. The same saved fighter can occupy multiple slots. Editing affects the next match selection; current matches retain their configuration. Deleting a selected record leaves a running match intact and returns its menu choice to Prototype Fighter.

Records live in Godot's `user://library/items` directory and survive game restarts. They are separate from packaged resources and Git. See [Library architecture and verification](docs/library-system.md).

## Controls

| Action | Human 1 | Human 2 |
| --- | --- | --- |
| Move | `A` / `D` | `J` / `L` |
| Jump | `W` | `I` |
| Crouch | `S` | `K` |
| Attack | `F` | `O` |
| Defend | `G` | `P` |
| Kick | `H` | `M` |
| Throw / pick up weapon | `Q` | `U` |
| Taunt | `E` | `N` |
| Swap weapon (debug) | `T` | `Y` |

Additional controls: `1` Arena, `2` Freeway, `R` restart, and `Tab` match setup. After a match ends, press any key to restart the same match.

## Multiplayer architecture

`FighterSlotConfig` describes each slot's character, loadout, control type, CPU difficulty, input player, team, spawn, and enabled state. `MatchManager` owns opponent relationships, friendly-fire rules, active fighters, and victory conditions. `HumanFighterController` and `CpuFighterController` both produce `FighterCommand` values consumed by the same `Fighter` class.

CPU difficulty comes from editable `CpuProfile` values such as reaction delay, decision interval, aggression, accuracy, preferred distance, risk, target switching, blocking, and dodging. Difficulty does not modify fighter health or damage. Weapon definitions expose attack range, preferred distance, cooldown, damage, and knockback so CPU decisions remain weapon-aware without weapon-specific AI.

## Weapon architecture

Weapon definitions live in [`weapons/`](weapons/) as `WeaponDefinition` resources. To add a weapon, duplicate an existing `.tres`, assign a unique identity and visual/gameplay metadata, and use it as a slot loadout. Fighter and CPU code do not require weapon-specific branches.

## Verification

Run the focused headless test from the repository root:

```sh
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/library_test.gd
```

It covers the legacy combat moves, shared controller path, difficulty profiles, CPU-only combat, team-aware damage and targeting, friendly fire, team victory, 4-player, 3-vs-3, and 8-player configurations, plus authored and fallback spawns.

## Status

This is a playable architecture and balancing prototype. Eight-player setup is intentionally functional rather than polished; dense matches still require human play-testing for readability, camera behavior, audio overlap, and combat congestion.

## License

No license has been selected. All rights are reserved unless a license is added later.
