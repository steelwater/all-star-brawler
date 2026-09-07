class_name CpuFighterController
extends FighterController

var fighter: Fighter
var match_manager: MatchManager
var profile: CpuProfile
var target: Fighter
var reaction_remaining := 0.0
var decision_remaining := 0.0
var target_switch_remaining := 0.0
var desired_move := 0.0
var wants_defend := false
var pending_attack := false
var pending_jump := false
var pending_kick := false
var pending_weapon_action := false
var random := RandomNumberGenerator.new()


func configure(new_fighter: Fighter, new_match_manager: MatchManager, difficulty: int) -> void:
	fighter = new_fighter
	match_manager = new_match_manager
	profile = CpuProfile.for_difficulty(difficulty)
	reaction_remaining = profile.reaction_delay
	random.seed = 7103 + fighter.fighter_id * 977


func get_command(delta: float) -> FighterCommand:
	var command := FighterCommand.new()
	if fighter == null or fighter.defeated or profile == null:
		return command

	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	decision_remaining -= delta
	target_switch_remaining -= delta
	if reaction_remaining <= 0.0 and decision_remaining <= 0.0:
		_make_decision()
		decision_remaining = profile.decision_interval

	command.move_axis = desired_move
	command.defend = wants_defend
	command.attack = pending_attack
	command.jump = pending_jump
	command.kick = pending_kick
	command.weapon_action = pending_weapon_action
	pending_attack = false
	pending_jump = false
	pending_kick = false
	pending_weapon_action = false
	return command


func _make_decision() -> void:
	if not _target_is_valid() or target_switch_remaining <= 0.0:
		target = _select_target()
		target_switch_remaining = profile.target_switch_frequency

	desired_move = 0.0
	wants_defend = false
	if target == null:
		return

	var offset := target.global_position - fighter.global_position
	var distance := offset.length()
	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = fighter.facing

	var preferred := profile.preferred_distance
	if fighter.weapon != null and fighter.weapon.definition != null:
		preferred = fighter.weapon.definition.preferred_distance
	if distance > preferred + 24.0:
		desired_move = direction
	elif distance < preferred * 0.48 and random.randf() > profile.risk_tolerance:
		desired_move = -direction

	if offset.y < -95.0 and random.randf() < profile.dodge_frequency:
		pending_jump = true

	var attack_range := Fighter.KICK_RANGE
	if fighter.weapon != null and fighter.weapon.definition != null:
		attack_range = fighter.weapon.definition.attack_range
	var in_attack_range := absf(offset.y) < 78.0 and distance <= attack_range
	if in_attack_range and random.randf() <= profile.attack_accuracy:
		fighter.facing = direction
		if fighter.weapon != null:
			var combo_bonus := 0.04 * float(profile.combo_depth - 1)
			pending_attack = random.randf() <= minf(1.0, profile.aggression + combo_bonus)
		else:
			pending_kick = true
	elif distance < attack_range * 1.35 and random.randf() < maxf(profile.block_frequency, profile.defensive_tendency * 0.5):
		wants_defend = true

	if fighter.weapon == null and _has_available_weapon():
		pending_weapon_action = true


func _select_target() -> Fighter:
	var best: Fighter
	var best_score := INF
	for candidate in match_manager.get_opponents(fighter):
		var score := fighter.global_position.distance_squared_to(candidate.global_position)
		if candidate.health < Fighter.MAX_HEALTH * 0.35:
			score *= 0.75
		if score < best_score:
			best = candidate
			best_score = score
	return best


func _target_is_valid() -> bool:
	return is_instance_valid(target) and match_manager.is_opponent(fighter, target)


func _has_available_weapon() -> bool:
	for candidate in get_tree().get_nodes_in_group("world_weapons"):
		if candidate.has_method("is_available_to") and candidate.is_available_to(fighter):
			return true
	return false
