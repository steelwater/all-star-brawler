class_name CpuProfile
extends Resource

@export var reaction_delay := 0.25
@export var decision_interval := 0.18
@export_range(0.0, 1.0) var aggression := 0.65
@export_range(0.0, 1.0) var defensive_tendency := 0.35
@export_range(0.0, 1.0) var attack_accuracy := 0.75
@export var preferred_distance := 90.0
@export_range(1, 4) var combo_depth := 2
@export_range(0.0, 1.0) var risk_tolerance := 0.55
@export var target_switch_frequency := 1.0
@export_range(0.0, 1.0) var block_frequency := 0.3
@export_range(0.0, 1.0) var dodge_frequency := 0.2


static func for_difficulty(difficulty: int) -> CpuProfile:
	var profile := CpuProfile.new()
	match difficulty:
		FighterSlotConfig.CpuDifficulty.EASY:
			profile.reaction_delay = 0.55
			profile.decision_interval = 0.38
			profile.aggression = 0.42
			profile.defensive_tendency = 0.15
			profile.attack_accuracy = 0.5
			profile.preferred_distance = 105.0
			profile.combo_depth = 1
			profile.risk_tolerance = 0.3
			profile.target_switch_frequency = 1.8
			profile.block_frequency = 0.1
			profile.dodge_frequency = 0.05
		FighterSlotConfig.CpuDifficulty.HARD:
			profile.reaction_delay = 0.1
			profile.decision_interval = 0.1
			profile.aggression = 0.86
			profile.defensive_tendency = 0.62
			profile.attack_accuracy = 0.93
			profile.preferred_distance = 82.0
			profile.combo_depth = 3
			profile.risk_tolerance = 0.72
			profile.target_switch_frequency = 0.55
			profile.block_frequency = 0.52
			profile.dodge_frequency = 0.38
	return profile
