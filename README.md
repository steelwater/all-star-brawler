# All Star Brawler

All Star Brawler is a small Godot prototype for testing a simple 2D brawler with interchangeable weapons and modular stages.

The MVP is intended to answer three questions:

1. Is the basic brawler fun?
2. Does interchangeable weapon gear work cleanly?
3. Is fighting on moving freeway vehicles fun enough to pursue?

## Prototype scope

The planned prototype uses **Godot 4.7.2 stable** and **GDScript**. Its intentionally narrow scope includes:

- Two fighters with movement, jumping, attacking, defending, health, knockback, and round restart behavior
- A data-driven weapon slot with at least a sword and hammer
- Weapon-specific hit sounds and a distinct block sound
- A basic test arena
- A moving-freeway stage with vehicle-roof platforms
- Minimal health, restart, stage-selection, and weapon-test UI

Creator tools, imported assets, armor, save files, networking, progression, mobile controls, and production packaging are outside this prototype.

## Run the prototype

1. Install [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/).
2. Import this repository's `project.godot` file in the Godot Project Manager.
3. Run the project with **F5** or the editor's Run Project button.

The project uses only GDScript, built-in Godot nodes, generated placeholder sounds, and code-drawn placeholder visuals. No additional runtime dependencies are required.

## Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | `A` / `D` | `J` / `L` |
| Jump | `W` | `I` |
| Attack | `F` | `O` |
| Defend | `G` | `P` |
| Swap weapon | `T` | `Y` |

Additional test controls:

- `1`: Load the arena
- `2`: Load the freeway stage
- `R`: Restart the round

Falling from a stage or reaching zero health restarts the round automatically.

## Weapon architecture

Weapon definitions live in [`weapons/`](weapons/) as custom `WeaponDefinition` resources:

- [`sword.tres`](weapons/sword.tres)
- [`hammer.tres`](weapons/hammer.tres)

Each definition owns its identity, display name, placeholder visual configuration, damage, knockback, hit sound, hit-area dimensions, and cooldown. [`weapon.gd`](weapons/weapon.gd) applies that definition and handles attacks. [`fighter.gd`](characters/fighter.gd) only equips and uses the reusable weapon scene; it contains no sword- or hammer-specific combat logic.

### Add a third weapon

1. Duplicate `weapons/sword.tres` or `weapons/hammer.tres`.
2. Give the resource a unique `id` and `display_name`.
3. Set its visual values, damage, knockback, attack area, cooldown, and `hit_sound`.
4. Assign or preload that resource wherever the prototype should equip it.

No fighter code changes are required. Adding the new weapon to the debug weapon-cycle control would only require updating the prototype-level selection list in `scripts/game.gd`.

## Verification

Run the focused gameplay smoke test from the repository root:

```sh
godot --headless --path . --script res://tests/smoke_test.gd
```

It verifies fighter creation, default equipment, damage, knockback, defense, weapon exchange, stage switching, and the two moving freeway platforms.

## Status

The MVP prototype is playable. Visuals and sounds are deliberately temporary and exist only to test combat, modular weapons, and the freeway-stage concept.

## License

No license has been selected. All rights are reserved unless a license is added later.
