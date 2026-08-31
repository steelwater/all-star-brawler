extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _run() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var game := main_scene.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame

	_check(game.fighters.size() == 2, "the arena starts with two fighters")
	_check(game.fighters[0].get_weapon_name() == "Sword", "player one starts with the sword resource")
	_check(game.fighters[1].get_weapon_name() == "Hammer", "player two starts with the hammer resource")
	_check(
		game.fighters[0].weapon.definition.hit_sound != game.fighters[1].weapon.definition.hit_sound,
		"sword and hammer reference different hit sounds"
	)
	_check(game.fighters[0].block_sound != null, "fighters reference a distinct block sound")

	var player_one: Fighter = game.fighters[0]
	var player_two: Fighter = game.fighters[1]
	player_one.global_position = Vector2(560, 510)
	player_two.global_position = Vector2(640, 510)
	player_one.velocity = Vector2.ZERO
	player_two.velocity = Vector2.ZERO
	for frame in range(3):
		await physics_frame

	Input.action_press("p1_attack")
	await physics_frame
	Input.action_release("p1_attack")
	await physics_frame
	_check(player_two.health < Fighter.MAX_HEALTH, "a weapon attack damages an overlapping opponent")
	_check(player_two.velocity.x > 0.0, "a sword hit applies visible-direction knockback")

	player_two.health = Fighter.MAX_HEALTH
	player_two.velocity = Vector2.ZERO
	for frame in range(30):
		await physics_frame
	Input.action_press("p2_defend")
	for frame in range(2):
		await physics_frame
	Input.action_press("p1_attack")
	await physics_frame
	Input.action_release("p1_attack")
	await physics_frame
	Input.action_release("p2_defend")
	_check(player_two.health > 95.0, "defending substantially reduces incoming sword damage")

	game._swap_weapon(0)
	_check(player_one.get_weapon_name() == "Hammer", "a fighter can exchange weapon resources without changing fighter code")

	game.load_stage(1)
	await process_frame
	await physics_frame
	_check(game.current_stage is FreewayStage, "the freeway stage can replace the arena")
	_check(game.current_stage.cars.size() == 2, "the freeway stage provides two moving vehicle platforms")
	_check(game.fighters.size() == 2, "combat fighters are reused on the freeway stage")
	var first_car_start: Vector2 = game.current_stage.cars[0].position
	for frame in range(3):
		await physics_frame
	_check(game.current_stage.cars[0].position != first_car_start, "freeway vehicle platforms move during play")

	current_scene = null
	root.remove_child(game)
	game.free()
	await process_frame
	if failures.is_empty():
		print("All Star Brawler smoke test passed.")
		call_deferred("_finish", 0)
	else:
		push_error("%d smoke test assertion(s) failed." % failures.size())
		call_deferred("_finish", 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)
