class_name FreewayStage
extends Node2D

var elapsed := 0.0
var scroll_offset := 0.0
var cars: Array[AnimatableBody2D] = []
var car_origins: Array[Vector2] = []


func _ready() -> void:
	_create_car(Vector2(350, 550), Vector2(330, 64), Color("d9475f"))
	_create_car(Vector2(900, 550), Vector2(350, 64), Color("3d86d8"))
	queue_redraw()


func _physics_process(delta: float) -> void:
	elapsed += delta
	scroll_offset = fmod(scroll_offset + 360.0 * delta, 210.0)
	for index in cars.size():
		var phase := elapsed * (0.85 + float(index) * 0.12) + float(index) * 2.1
		cars[index].position = car_origins[index] + Vector2(sin(phase) * 24.0, sin(phase * 1.7) * 5.0)
	queue_redraw()


func get_spawn_points() -> Array[Vector2]:
	return [Vector2(350, 450), Vector2(900, 450)]


func _create_car(car_position: Vector2, size: Vector2, color: Color) -> void:
	var body := AnimatableBody2D.new()
	body.position = car_position
	body.collision_layer = 1
	body.collision_mask = 2
	body.sync_to_physics = true

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)

	var body_visual := Polygon2D.new()
	body_visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.43, size.y * 0.65),
		Vector2(-size.x * 0.43, size.y * 0.65),
	])
	body_visual.color = color
	body.add_child(body_visual)

	var window_visual := Polygon2D.new()
	window_visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.18, -size.y * 0.5),
		Vector2(size.x * 0.18, -size.y * 0.5),
		Vector2(size.x * 0.12, -size.y * 1.05),
		Vector2(-size.x * 0.1, -size.y * 1.05),
	])
	window_visual.color = Color("bde3f7")
	body.add_child(window_visual)

	for wheel_x in [-size.x * 0.32, size.x * 0.32]:
		var wheel := Polygon2D.new()
		var points := PackedVector2Array()
		for step in range(16):
			var angle := TAU * float(step) / 16.0
			points.append(Vector2(wheel_x, size.y * 0.63) + Vector2(cos(angle), sin(angle)) * 21.0)
		wheel.polygon = points
		wheel.color = Color("171a20")
		body.add_child(wheel)

	add_child(body)
	cars.append(body)
	car_origins.append(car_position)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("89c7e8"))
	for index in range(10):
		var x := fmod(float(index) * 175.0 - scroll_offset * 0.3 + 1400.0, 1575.0) - 140.0
		var height := 95.0 + float((index * 47) % 120)
		draw_rect(Rect2(x, 350.0 - height, 115, height), Color("7097ae"))
	draw_rect(Rect2(0, 360, 1280, 360), Color("303742"))
	for lane in [465.0, 650.0]:
		for stripe in range(9):
			var x := fmod(float(stripe) * 210.0 - scroll_offset + 1470.0, 1680.0) - 210.0
			draw_rect(Rect2(x, lane, 112, 12), Color("f3e5a3"))
	for streak in range(8):
		var y := 390.0 + float(streak) * 39.0
		draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.035), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(48, 96), "FREEWAY TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("203443"))
