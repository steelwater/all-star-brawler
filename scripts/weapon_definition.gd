class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var visual_shape: StringName = &"blade"
@export var visual_color: Color = Color.WHITE
@export var visual_size: Vector2 = Vector2(56, 12)
@export var damage: float = 10.0
@export var knockback: float = 360.0
@export var hit_sound: AudioStream
@export var attack_size: Vector2 = Vector2(80, 72)
@export var attack_offset: float = 62.0
@export var cooldown: float = 0.45
