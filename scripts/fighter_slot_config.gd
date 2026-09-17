class_name FighterSlotConfig
extends Resource

enum ControlType {
	HUMAN,
	CPU,
	DISABLED,
}

enum CpuDifficulty {
	EASY,
	MEDIUM,
	HARD,
}

@export_range(1, 8) var slot_id := 1
@export var character_id: StringName = &"prototype_fighter"
@export var starting_weapon: WeaponDefinition
@export var control_type := ControlType.DISABLED
@export var cpu_difficulty := CpuDifficulty.MEDIUM
@export_range(1, 8) var input_player := 1
@export_range(1, 8) var team_id := 1
@export_range(0, 7) var spawn_index := 0
@export var fighter_color := Color.WHITE


func is_enabled() -> bool:
	return control_type != ControlType.DISABLED
