extends RigidBody2D

const THROW_SPEED := 720.0
const THROW_LIFT := -180.0
const PICKUP_DELAY := 0.35
const MINIMUM_DAMAGE_SPEED := 180.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: BrawlerWeapon = $Visual
@onready var hit_player: AudioStreamPlayer2D = $HitPlayer

var definition: WeaponDefinition
var thrower_number := 0
var pickup_delay_remaining := PICKUP_DELAY
var damage_available := true


func _ready() -> void:
	add_to_group("world_weapons")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	pickup_delay_remaining = maxf(0.0, pickup_delay_remaining - delta)
	if linear_velocity.length() < MINIMUM_DAMAGE_SPEED:
		damage_available = false


func configure(new_definition: WeaponDefinition, new_thrower_number: int, facing: float) -> void:
	definition = new_definition
	thrower_number = new_thrower_number
	visual.configure(definition)
	visual.hit_area.monitoring = false
	hit_player.stream = definition.hit_sound
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(maxf(28.0, definition.visual_size.x), maxf(16.0, definition.visual_size.y))
	collision_shape.shape = rectangle
	linear_velocity = Vector2(facing * THROW_SPEED, THROW_LIFT)
	angular_velocity = facing * 9.0


func is_available_to(player: Node2D) -> bool:
	return pickup_delay_remaining <= 0.0 and global_position.distance_to(player.global_position) <= Fighter.PICKUP_RADIUS


func _on_body_entered(body: Node) -> void:
	if not damage_available or not body is Fighter:
		return
	if body.player_number == thrower_number and pickup_delay_remaining > 0.0:
		return
	var direction := signf(linear_velocity.x)
	if is_zero_approx(direction):
		direction = 1.0
	body.receive_hit(definition.damage * 0.6, Vector2(direction * definition.knockback * 0.7, -definition.knockback * 0.2))
	if definition.hit_sound != null:
		hit_player.play()
	damage_available = false
