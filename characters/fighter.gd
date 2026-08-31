class_name Fighter
extends CharacterBody2D

signal health_changed(player_number: int, health: float)
signal fell_out(player_number: int)

const WEAPON_SCENE := preload("res://weapons/weapon.tscn")
const MAX_HEALTH := 100.0
const MOVE_SPEED := 270.0
const JUMP_VELOCITY := -610.0
const AIR_CONTROL := 0.7

@export_range(1, 2) var player_number := 1
@export var fighter_color := Color("4dabf7")
@export var starting_weapon: WeaponDefinition
@export var block_sound: AudioStream

@onready var weapon_mount: Node2D = $WeaponMount
@onready var block_player: AudioStreamPlayer = $BlockPlayer

var health := MAX_HEALTH
var facing := 1.0
var is_defending := false
var weapon: BrawlerWeapon
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	block_player.stream = block_sound
	equip_weapon(starting_weapon)
	health_changed.emit(player_number, health)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	is_defending = Input.is_action_pressed(_action("defend")) and is_on_floor()
	var direction := Input.get_axis(_action("left"), _action("right"))
	if is_defending:
		direction = 0.0

	if not is_zero_approx(direction):
		facing = signf(direction)
		var control := 1.0 if is_on_floor() else AIR_CONTROL
		velocity.x = move_toward(velocity.x, direction * MOVE_SPEED, MOVE_SPEED * 8.0 * control * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 7.0 * delta)

	if Input.is_action_just_pressed(_action("jump")) and is_on_floor() and not is_defending:
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed(_action("attack")) and not is_defending and weapon != null:
		weapon.try_attack(self, facing)

	weapon_mount.scale.x = facing
	move_and_slide()
	queue_redraw()

	if global_position.y > 820.0:
		fell_out.emit(player_number)
		set_physics_process(false)


func equip_weapon(new_definition: WeaponDefinition) -> void:
	if new_definition == null:
		return
	if weapon == null:
		weapon = WEAPON_SCENE.instantiate()
		weapon_mount.add_child(weapon)
	weapon.configure(new_definition)


func get_weapon_name() -> String:
	if weapon == null or weapon.definition == null:
		return "None"
	return weapon.definition.display_name


func receive_hit(damage: float, knockback: Vector2) -> void:
	var final_damage := damage
	var final_knockback := knockback
	if is_defending:
		final_damage *= 0.2
		final_knockback *= 0.25
		if block_sound != null:
			block_player.play()

	health = maxf(0.0, health - final_damage)
	velocity = final_knockback
	health_changed.emit(player_number, health)
	queue_redraw()

	if health <= 0.0:
		fell_out.emit(player_number)
		set_physics_process(false)


func _action(suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_number, suffix])


func _draw() -> void:
	var body_color := fighter_color.darkened(0.4) if is_defending else fighter_color
	draw_circle(Vector2(0, -54), 18.0, body_color.lightened(0.18))
	draw_rect(Rect2(-22, -38, 44, 58), body_color)
	draw_rect(Rect2(-18, 20, 14, 28), body_color.darkened(0.15))
	draw_rect(Rect2(4, 20, 14, 28), body_color.darkened(0.15))
	draw_line(Vector2(-14, -24), Vector2(-32, 4), body_color, 10.0)
	if is_defending:
		draw_arc(Vector2(facing * 32, -18), 31.0, -1.35, 1.35, 18, Color("d9f0ff"), 7.0)
