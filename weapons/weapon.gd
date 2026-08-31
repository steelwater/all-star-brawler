class_name BrawlerWeapon
extends Node2D

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
	attack_flash_remaining = 0.12

	var connected := false
	for body in hit_area.get_overlapping_bodies():
		if body == attacker or not body is Fighter:
			continue
		var knockback := Vector2(facing * definition.knockback, -definition.knockback * 0.35)
		body.receive_hit(definition.damage, knockback)
		connected = true

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


func _draw() -> void:
	if definition == null:
		return
	var color := definition.visual_color
	if attack_flash_remaining > 0.0:
		color = color.lightened(0.35)

	if definition.visual_shape == &"hammer":
		draw_rect(Rect2(0, -3, definition.visual_size.x * 0.72, 6), Color("8b5e3c"))
		draw_rect(
			Rect2(definition.visual_size.x * 0.55, -definition.visual_size.y * 0.5, definition.visual_size.x * 0.45, definition.visual_size.y),
			color
		)
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

	if attack_flash_remaining > 0.0:
		draw_arc(Vector2.ZERO, definition.attack_offset, -0.75, 0.75, 16, Color(1, 1, 1, 0.65), 4.0)
