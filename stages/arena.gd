class_name ArenaStage
extends Node2D


func _ready() -> void:
	_add_platform(Vector2(640, 600), Vector2(900, 72), Color("364152"))
	_add_platform(Vector2(195, 470), Vector2(220, 30), Color("48566a"))
	_add_platform(Vector2(1085, 470), Vector2(220, 30), Color("48566a"))
	queue_redraw()


func get_spawn_points() -> Array[Vector2]:
	return [Vector2(430, 510), Vector2(850, 510)]


func _add_platform(platform_position: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = platform_position
	body.collision_layer = 1
	body.collision_mask = 2

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	visual.color = color
	body.add_child(visual)
	add_child(body)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("121a2b"))
	draw_circle(Vector2(1040, 140), 76.0, Color("f4d47c"))
	for index in range(12):
		var width := 70.0 + float((index * 37) % 90)
		var height := 90.0 + float((index * 53) % 170)
		var x := float(index) * 118.0 - 30.0
		draw_rect(Rect2(x, 360.0 - height, width, height + 250.0), Color("1f2b41"))
	draw_string(ThemeDB.fallback_font, Vector2(48, 96), "ARENA TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.72))
