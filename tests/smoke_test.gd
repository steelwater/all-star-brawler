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

	player_one.is_ducking = true
	player_one._update_collision_shape()
	_check(player_one.collision_shape.shape != player_two.collision_shape.shape, "each fighter owns an independent collision shape")
	var duck_shape := player_one.collision_shape.shape as CapsuleShape2D
	_check(is_equal_approx(duck_shape.height, Fighter.DUCKING_HEIGHT), "ducking shortens the fighter collision shape")
	player_one.is_ducking = false
	player_one._update_collision_shape()

	player_one.global_position = Vector2(560, 510)
	player_two.global_position = Vector2(620, 510)
	player_two.health = Fighter.MAX_HEALTH
	player_one.kick_cooldown_remaining = 0.0
	_check(player_one._try_kick(), "a kick connects with an opponent in front of the fighter")
	_check(player_two.health < Fighter.MAX_HEALTH, "a kick damages the opponent")

	player_two.global_position = Vector2(760, 510)
	player_two.health = Fighter.MAX_HEALTH
	player_one._throw_or_pickup_weapon()
	await process_frame
	_check(player_one.get_weapon_name() == "None", "throwing removes the equipped weapon")
	var thrown_weapons := get_nodes_in_group("world_weapons")
	_check(thrown_weapons.size() == 1, "throwing creates one reusable world weapon")
	if thrown_weapons.size() == 1:
		var thrown := thrown_weapons[0]
		thrown.linear_velocity = Vector2(500, 0)
		thrown.damage_available = true
		thrown._on_body_entered(player_two)
		_check(player_two.health < Fighter.MAX_HEALTH, "a thrown weapon damages an opponent")
		thrown.pickup_delay_remaining = 0.0
		thrown.global_position = player_one.global_position
		player_one._throw_or_pickup_weapon()
		await process_frame
		_check(player_one.get_weapon_name() == "Sword", "an unarmed fighter can pick up a nearby weapon")

	game._swap_weapon(0)
	_check(player_one.get_weapon_name() == "Hammer", "a fighter can exchange weapon resources without changing fighter code")

	_check(InputMap.has_action("p1_taunt") and InputMap.has_action("p2_taunt"), "both fighters have a taunt control")
	player_one._start_taunt()
	_check(player_one.taunt_remaining > 0.0, "the taunt starts a jumping-jack gesture")

	game.load_stage(1)
	await process_frame
	await physics_frame
	_check(game.current_stage is FreewayStage, "the freeway stage can replace the arena")
	_check(game.current_stage.cars.size() == 2, "the freeway stage provides two moving vehicle platforms")
	_check(game.fighters.size() == 2, "combat fighters are reused on the freeway stage")
	_check(game.current_stage.is_drain_zone(Vector2(640, 620)), "the freeway road is a health-drain zone")
	var first_car_start: Vector2 = game.current_stage.cars[0].position
	for frame in range(3):
		await physics_frame
	_check(game.current_stage.cars[0].position != first_car_start, "freeway vehicle platforms move during play")

	var freeway_fighter: Fighter = game.fighters[0]
	freeway_fighter.global_position = Vector2(640, 610)
	freeway_fighter.velocity = Vector2.ZERO
	var health_before_road := freeway_fighter.health
	for frame in range(25):
		await physics_frame
	_check(freeway_fighter.is_on_floor(), "a fighter who leaves a freeway car lands on the road")
	_check(freeway_fighter.health < health_before_road, "standing on the freeway road continuously drains health")

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
