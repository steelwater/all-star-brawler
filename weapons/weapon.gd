class_name BrawlerWeapon
extends Node2D

const ATTACK_ANIMATION_DURATION := 0.24
const SWORD_THRUST_DISTANCE := 32.0
const HAMMER_SWING_START := -1.45
const HAMMER_SWING_END := 0.45

@export var definition: WeaponDefinition

@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var hit_player: AudioStreamPlayer = $HitPlayer

var cooldown_remaining := 0.0
var attack_flash_remaining := 0.0


func _ready() -> void:
	_apply_definition()
	queue_redraw()


func _process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	attack_flash_remaining = maxf(0.0, attack_flash_remaining - delta)
	_update_attack_pose()
	queue_redraw()


func configure(new_definition: WeaponDefinition) -> void:
	definition = new_definition
	if is_node_ready():
		_apply_definition()
		queue_redraw()


func try_attack(attacker: Fighter, facing: float) -> bool:
	if definition == null or cooldown_remaining > 0.0:
		return false
	cooldown_remaining = definition.cooldown
	attack_flash_remaining = ATTACK_ANIMATION_DURATION
	_update_attack_pose()
	var connected := false
	for body in hit_area.get_overlapping_bodies():
		if body == attacker or not body is Fighter:
			continue
		var knockback := Vector2(facing * definition.knockback, -definition.knockback * 0.35)
		connected = body.receive_hit(definition.damage, knockback, attacker) or connected
	if connected and definition.hit_sound != null:
		hit_player.stream = definition.hit_sound
		hit_player.play()
	return true


func _apply_definition() -> void:
	if definition == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = definition.attack_size
	hit_shape.shape = rectangle
	hit_area.position.x = definition.attack_offset
	hit_player.stream = definition.hit_sound


func _update_attack_pose() -> void:
	position = Vector2.ZERO
	rotation = 0.0
	if definition == null or attack_flash_remaining <= 0.0:
		return
	var progress := 1.0 - attack_flash_remaining / ATTACK_ANIMATION_DURATION
	if definition.visual_shape == &"hammer":
		rotation = lerpf(HAMMER_SWING_START, HAMMER_SWING_END, smoothstep(0.0, 1.0, progress))
		position.y = -10.0 * sin(progress * PI)
	else:
		position.x = SWORD_THRUST_DISTANCE * sin(progress * PI)


func _draw() -> void:
	if definition == null:
		return
	var color := definition.visual_color
	if attack_flash_remaining > 0.0:
		color = color.lightened(0.35)
	if definition.visual_shape == &"hammer":
		draw_rect(Rect2(0, -3, definition.visual_size.x * 0.72, 6), Color("8b5e3c"))
		draw_rect(Rect2(definition.visual_size.x * 0.55, -definition.visual_size.y * 0.5, definition.visual_size.x * 0.45, definition.visual_size.y), color)
	else:
		draw_rect(Rect2(0, -3, definition.visual_size.x * 0.3, 6), Color("8b5e3c"))
		var blade := PackedVector2Array([
			Vector2(definition.visual_size.x * 0.25, -definition.visual_size.y * 0.5),
			Vector2(definition.visual_size.x * 0.88, -definition.visual_size.y * 0.5),
			Vector2(definition.visual_size.x, 0),
			Vector2(definition.visual_size.x * 0.88, definition.visual_size.y * 0.5),
			Vector2(definition.visual_size.x * 0.25, definition.visual_size.y * 0.5),
		])
		draw_colored_polygon(blade, color)
