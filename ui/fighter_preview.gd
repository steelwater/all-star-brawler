class_name FighterPreview
extends SubViewportContainer

const SCENE := preload("res://characters/fighter.tscn")
var fighter: Fighter


func _init() -> void:
	custom_minimum_size = Vector2(180, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(180, 160)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.gui_disable_input = true
	add_child(viewport)
	fighter = SCENE.instantiate()
	fighter.process_mode = Node.PROCESS_MODE_DISABLED
	fighter.position = Vector2(70, 90)
	fighter.collision_layer = 0
	fighter.collision_mask = 0
	viewport.add_child(fighter)


func _ready() -> void:
	# Preview fighters are neither opponents nor match participants.
	fighter.remove_from_group("fighters")


func show_payload(payload: Dictionary) -> void:
	fighter.fighter_color = Color(payload["color"])
	fighter.equip_weapon(LibraryItem.weapon_for(payload["weapon_id"]))
	fighter.queue_redraw()
