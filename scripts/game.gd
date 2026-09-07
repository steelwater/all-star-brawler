extends Node2D

const FIGHTER_SCENE := preload("res://characters/fighter.tscn")
const ARENA_SCENE := preload("res://stages/arena.tscn")
const FREEWAY_SCENE := preload("res://stages/freeway.tscn")
const SWORD: WeaponDefinition = preload("res://weapons/sword.tres")
const HAMMER: WeaponDefinition = preload("res://weapons/hammer.tres")

@onready var p1_health_label: Label = $HUD/SafeArea/TopBar/P1Health
@onready var p2_health_label: Label = $HUD/SafeArea/TopBar/P2Health
@onready var stage_label: Label = $HUD/SafeArea/TopBar/Stage
@onready var weapon_label: Label = $HUD/SafeArea/WeaponStatus
@onready var round_label: Label = $HUD/SafeArea/RoundStatus

var current_stage: Node2D
var fighters: Array[Fighter] = []
var stage_index := 0
var reset_pending := false


func _ready() -> void:
	load_stage(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_round"):
		reset_round()
	elif event.is_action_pressed("arena_stage"):
		load_stage(0)
	elif event.is_action_pressed("freeway_stage"):
		load_stage(1)
	elif event.is_action_pressed("swap_p1_weapon"):
		_swap_weapon(0)
	elif event.is_action_pressed("swap_p2_weapon"):
		_swap_weapon(1)


func load_stage(new_stage_index: int) -> void:
	stage_index = clampi(new_stage_index, 0, 1)
	reset_pending = false
	round_label.text = ""

	for fighter in fighters:
		fighter.queue_free()
	fighters.clear()
	for world_weapon in get_tree().get_nodes_in_group("world_weapons"):
		world_weapon.queue_free()
	if current_stage != null:
		current_stage.queue_free()

	current_stage = (ARENA_SCENE if stage_index == 0 else FREEWAY_SCENE).instantiate()
	add_child(current_stage)
	move_child(current_stage, 0)
	var spawn_points: Array[Vector2] = current_stage.get_spawn_points()

	_spawn_fighter(1, Color("4dabf7"), SWORD, spawn_points[0])
	_spawn_fighter(2, Color("ff6b6b"), HAMMER, spawn_points[1])
	stage_label.text = "Stage: %s" % ("Arena" if stage_index == 0 else "Freeway")
	_refresh_weapon_status()


func reset_round() -> void:
	load_stage(stage_index)


func _spawn_fighter(number: int, color: Color, starting_weapon: WeaponDefinition, spawn_position: Vector2) -> void:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.player_number = number
	fighter.fighter_color = color
	fighter.starting_weapon = starting_weapon
	fighter.health_changed.connect(_on_health_changed)
	fighter.fell_out.connect(_on_fighter_fell)
	fighter.weapon_changed.connect(_refresh_weapon_status)
	add_child(fighter)
	fighter.global_position = spawn_position
	if number == 2:
		fighter.facing = -1.0
	fighters.append(fighter)


func _swap_weapon(fighter_index: int) -> void:
	if fighter_index >= fighters.size():
		return
	var fighter := fighters[fighter_index]
	var next_weapon: WeaponDefinition
	if fighter.weapon == null or fighter.weapon.definition == null:
		next_weapon = SWORD if fighter_index == 0 else HAMMER
	else:
		next_weapon = HAMMER if fighter.weapon.definition.id == SWORD.id else SWORD
	fighter.equip_weapon(next_weapon)


func _refresh_weapon_status() -> void:
	if fighters.size() < 2:
		return
	weapon_label.text = "Weapons  •  P1 [T]: %s    P2 [Y]: %s" % [fighters[0].get_weapon_name(), fighters[1].get_weapon_name()]


func _on_health_changed(player_number: int, health: float) -> void:
	var label := p1_health_label if player_number == 1 else p2_health_label
	label.text = "P%d Health: %d" % [player_number, ceili(health)]


func _on_fighter_fell(player_number: int) -> void:
	if reset_pending:
		return
	reset_pending = true
	round_label.text = "Player %d wins — restarting..." % (2 if player_number == 1 else 1)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(reset_round)
