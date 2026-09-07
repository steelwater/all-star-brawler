class_name Fighter
extends CharacterBody2D

signal health_changed(fighter_id: int, health: float)
signal defeated_changed(fighter_id: int)
signal weapon_changed

const WEAPON_SCENE := preload("res://weapons/weapon.tscn")
const THROWN_WEAPON_SCENE := preload("res://weapons/thrown_weapon.tscn")
const MAX_HEALTH := 100.0
const MOVE_SPEED := 270.0
const JUMP_VELOCITY := -610.0
const AIR_CONTROL := 0.7
const KICK_DAMAGE := 7.0
const KICK_KNOCKBACK := 260.0
const KICK_RANGE := 74.0
const KICK_COOLDOWN := 0.45
const PICKUP_RADIUS := 84.0
const ROAD_DAMAGE_PER_SECOND := 18.0
const STANDING_HEIGHT := 96.0
const DUCKING_HEIGHT := 58.0

@export_range(1, 8) var fighter_id := 1
@export_range(1, 8) var team_id := 1
@export var fighter_color := Color("4dabf7")
@export var starting_weapon: WeaponDefinition
@export var block_sound: AudioStream

@onready var weapon_mount: Node2D = $WeaponMount
@onready var block_player: AudioStreamPlayer = $BlockPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var controller: FighterController
var match_manager: MatchManager
var health := MAX_HEALTH
var facing := 1.0
var is_defending := false
var is_ducking := false
var weapon: BrawlerWeapon
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var kick_cooldown_remaining := 0.0
var kick_flash_remaining := 0.0
var taunt_remaining := 0.0
var walk_phase := 0.0
var defeated := false


func _ready() -> void:
	add_to_group("fighters")
	block_player.stream = block_sound
	equip_weapon(starting_weapon)
	health_changed.emit(fighter_id, health)
	queue_redraw()


func set_controller(new_controller: FighterController) -> void:
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	controller = new_controller
	if controller != null:
		add_child(controller)


func _physics_process(delta: float) -> void:
	kick_cooldown_remaining = maxf(0.0, kick_cooldown_remaining - delta)
	kick_flash_remaining = maxf(0.0, kick_flash_remaining - delta)
	taunt_remaining = maxf(0.0, taunt_remaining - delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	var command := FighterCommand.new()
	if controller != null:
		command = controller.get_command(delta)
	_apply_command(command, delta)
	weapon_mount.scale.x = facing
	move_and_slide()
	_apply_stage_hazard(delta)
	queue_redraw()
	if global_position.y > 820.0 and not _is_freeway_stage():
		defeat()


func _apply_command(command: FighterCommand, delta: float) -> void:
	var can_ground_action := is_on_floor() and taunt_remaining <= 0.0
	is_ducking = command.duck and can_ground_action
	is_defending = command.defend and can_ground_action and not is_ducking
	_update_collision_shape()
	var direction := clampf(command.move_axis, -1.0, 1.0)
	if is_defending or is_ducking or taunt_remaining > 0.0:
		direction = 0.0
	if not is_zero_approx(direction):
		facing = signf(direction)
		var control := 1.0 if is_on_floor() else AIR_CONTROL
		velocity.x = move_toward(velocity.x, direction * MOVE_SPEED, MOVE_SPEED * 8.0 * control * delta)
		if is_on_floor():
			walk_phase = fmod(walk_phase + absf(velocity.x) * delta * 0.045, TAU)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 7.0 * delta)
	if command.jump and can_ground_action and not is_defending and not is_ducking:
		velocity.y = JUMP_VELOCITY
	if command.attack and not is_defending and not is_ducking and taunt_remaining <= 0.0 and weapon != null:
		weapon.try_attack(self, facing)
	if command.kick and not is_defending and not is_ducking and taunt_remaining <= 0.0:
		_try_kick()
	if command.weapon_action and not is_defending and taunt_remaining <= 0.0:
		_throw_or_pickup_weapon()
	if command.taunt and can_ground_action and not is_defending and not is_ducking:
		_start_taunt()


func equip_weapon(new_definition: WeaponDefinition) -> void:
	if new_definition == null:
		return
	if weapon == null:
		weapon = WEAPON_SCENE.instantiate()
		weapon_mount.add_child(weapon)
	weapon.configure(new_definition)
	weapon_changed.emit()


func get_weapon_name() -> String:
	if weapon == null or weapon.definition == null:
		return "None"
	return weapon.definition.display_name


func receive_hit(damage: float, knockback: Vector2, attacker: Fighter = null) -> bool:
	if defeated:
		return false
	if attacker != null and match_manager != null and not match_manager.can_damage(attacker, self):
		return false
	var final_damage := damage
	var final_knockback := knockback
	if is_defending:
		final_damage *= 0.2
		final_knockback *= 0.25
		if block_sound != null:
			block_player.play()
	velocity = final_knockback
	_apply_damage(final_damage)
	return true


func receive_environment_damage(damage: float) -> void:
	_apply_damage(damage)


func defeat() -> void:
	if defeated:
		return
	defeated = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	visible = false
	defeated_changed.emit(fighter_id)


func _apply_damage(damage: float) -> void:
	if defeated:
		return
	health = maxf(0.0, health - damage)
	health_changed.emit(fighter_id, health)
	queue_redraw()
	if health <= 0.0:
		defeat()


func _try_kick() -> bool:
	if kick_cooldown_remaining > 0.0:
		return false
	kick_cooldown_remaining = KICK_COOLDOWN
	kick_flash_remaining = 0.16
	var connected := false
	for candidate in get_tree().get_nodes_in_group("fighters"):
		if candidate == self or not candidate is Fighter:
			continue
		var offset: Vector2 = candidate.global_position - global_position
		if absf(offset.y) <= 62.0 and offset.x * facing > 0.0 and offset.length() <= KICK_RANGE:
			connected = candidate.receive_hit(KICK_DAMAGE, Vector2(facing * KICK_KNOCKBACK, -KICK_KNOCKBACK * 0.22), self) or connected
	return connected


func _start_taunt() -> void:
	taunt_remaining = 0.75
	queue_redraw()


func _throw_or_pickup_weapon() -> void:
	if weapon != null and weapon.definition != null:
		var thrown := THROWN_WEAPON_SCENE.instantiate()
		get_parent().add_child(thrown)
		thrown.global_position = global_position + Vector2(facing * 44.0, -30.0)
		thrown.configure(weapon.definition, self, facing)
		weapon.queue_free()
		weapon = null
		weapon_changed.emit()
		return
	var nearest: Node2D
	var nearest_distance := PICKUP_RADIUS
	for candidate in get_tree().get_nodes_in_group("world_weapons"):
		if not candidate.has_method("is_available_to") or not candidate.is_available_to(self):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != null:
		var picked_up_definition: WeaponDefinition = nearest.definition
		nearest.queue_free()
		equip_weapon(picked_up_definition)


func _update_collision_shape() -> void:
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule == null:
		return
	var wanted_height := DUCKING_HEIGHT if is_ducking else STANDING_HEIGHT
	if not is_equal_approx(capsule.height, wanted_height):
		capsule.height = wanted_height
		collision_shape.position.y = 17.0 if is_ducking else -2.0


func _apply_stage_hazard(delta: float) -> void:
	var stage := _get_current_stage()
	if stage != null and stage.has_method("is_drain_zone") and stage.is_drain_zone(global_position) and is_on_floor():
		receive_environment_damage(ROAD_DAMAGE_PER_SECOND * delta)


func _get_current_stage() -> Node:
	var game := get_parent()
	if game != null and "current_stage" in game:
		return game.current_stage
	return null


func _is_freeway_stage() -> bool:
	return _get_current_stage() is FreewayStage


func _draw() -> void:
	var body_color := fighter_color.darkened(0.4) if is_defending else fighter_color
	var duck_offset := 19.0 if is_ducking else 0.0
	var leg_swing := sin(walk_phase) * 15.0 if is_on_floor() and absf(velocity.x) > 12.0 else 0.0
	var taunt_amount := sin((0.75 - taunt_remaining) * TAU * 3.0) if taunt_remaining > 0.0 else 0.0
	var jack_spread := absf(taunt_amount) * 16.0
	draw_circle(Vector2(0, -54 + duck_offset), 18.0, body_color.lightened(0.18))
	draw_rect(Rect2(-22, -38 + duck_offset, 44, 58 - duck_offset), body_color)
	if not is_ducking:
		draw_line(Vector2(-11, 20), Vector2(-11 - jack_spread + leg_swing, 48), body_color.darkened(0.15), 13.0)
		draw_line(Vector2(11, 20), Vector2(11 + jack_spread - leg_swing, 48), body_color.darkened(0.15), 13.0)
	var left_hand := Vector2(-34, -12 - taunt_amount * 30.0)
	var right_hand := Vector2(34, -12 - taunt_amount * 30.0)
	if taunt_remaining > 0.0:
		draw_line(Vector2(-14, -24), left_hand, body_color, 10.0)
		draw_line(Vector2(14, -24), right_hand, body_color, 10.0)
	else:
		draw_line(Vector2(-14, -24 + duck_offset), Vector2(-32, 4 + duck_offset), body_color, 10.0)
	if kick_flash_remaining > 0.0:
		draw_line(Vector2(facing * 10, 18), Vector2(facing * 52, 8), body_color.lightened(0.12), 14.0)
	if is_defending:
		draw_arc(Vector2(facing * 32, -18), 31.0, -1.35, 1.35, 18, Color("d9f0ff"), 7.0)
