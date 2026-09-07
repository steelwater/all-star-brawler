class_name MatchManager
extends Node

signal match_completed(winning_team_id: int, winning_fighter_ids: Array[int])

const MAX_FIGHTERS := 8

enum MatchMode {
	FREE_FOR_ALL,
	TEAM_BATTLE,
}

var match_mode := MatchMode.FREE_FOR_ALL
var friendly_fire := false
var fighter_slots: Array[FighterSlotConfig] = []
var fighters: Array[Fighter] = []
var completed := false


func configure(slots: Array[FighterSlotConfig], new_match_mode: int, new_friendly_fire: bool) -> void:
	fighter_slots = slots.slice(0, MAX_FIGHTERS)
	match_mode = new_match_mode
	friendly_fire = new_friendly_fire
	completed = false


func register_fighter(fighter: Fighter) -> void:
	if not fighters.has(fighter):
		fighters.append(fighter)


func clear_fighters() -> void:
	fighters.clear()
	completed = false


func is_opponent(attacker: Fighter, candidate: Fighter) -> bool:
	if attacker == null or candidate == null or attacker == candidate or candidate.defeated:
		return false
	if match_mode == MatchMode.FREE_FOR_ALL:
		return true
	return attacker.team_id != candidate.team_id


func can_damage(attacker: Fighter, candidate: Fighter) -> bool:
	return is_opponent(attacker, candidate) or (
		friendly_fire
		and attacker != null
		and candidate != null
		and attacker != candidate
		and not candidate.defeated
	)


func get_opponents(fighter: Fighter) -> Array[Fighter]:
	var opponents: Array[Fighter] = []
	for candidate in fighters:
		if is_instance_valid(candidate) and is_opponent(fighter, candidate):
			opponents.append(candidate)
	return opponents


func record_defeat(_fighter: Fighter) -> bool:
	if completed:
		return true
	var survivors: Array[Fighter] = []
	for fighter in fighters:
		if is_instance_valid(fighter) and not fighter.defeated:
			survivors.append(fighter)

	if match_mode == MatchMode.FREE_FOR_ALL:
		if survivors.size() <= 1:
			completed = true
			var winner_ids: Array[int] = []
			var winning_team := 0
			if survivors.size() == 1:
				winner_ids.append(survivors[0].fighter_id)
				winning_team = survivors[0].team_id
			match_completed.emit(winning_team, winner_ids)
	else:
		var remaining_teams: Dictionary = {}
		for survivor in survivors:
			remaining_teams[survivor.team_id] = true
		if remaining_teams.size() <= 1:
			completed = true
			var winner_ids: Array[int] = []
			for survivor in survivors:
				winner_ids.append(survivor.fighter_id)
			var winning_team := survivors[0].team_id if not survivors.is_empty() else 0
			match_completed.emit(winning_team, winner_ids)
	return completed
