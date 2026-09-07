extends SceneTree

const SWORD: WeaponDefinition = preload("res://weapons/sword.tres")
const HAMMER: WeaponDefinition = preload("res://weapons/hammer.tres")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)


func _make_slots(count: int, control_type: int, team_size := 1) -> Array[FighterSlotConfig]:
	var slots: Array[FighterSlotConfig] = []
	var colors := [
		Color("4dabf7"), Color("ff6b6b"), Color("69db7c"), Color("ffd43b"),
		Color("b197fc"), Color("ff922b"), Color("38d9a9"), Color("f06595"),
	]
	for index in MatchManager.MAX_FIGHTERS:
		var slot := FighterSlotConfig.new()
		slot.slot_id = index + 1
		slot.spawn_index = index
		slot.team_id = floori(float(index) / float(team_size)) + 1
		slot.input_player = index + 1
		slot.fighter_color = colors[index]
		slot.starting_weapon = SWORD if index % 2 == 0 else HAMMER
		slot.control_type = control_type if index < count else FighterSlotConfig.ControlType.DISABLED
		slot.cpu_difficulty = FighterSlotConfig.CpuDifficulty.HARD
		slots.append(slot)
	return slots


func _run() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var game := main_scene.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame

	_check(MatchManager.MAX_FIGHTERS == 8, "the match architecture supports eight fighter slots")
	_check(game.slot_configs.size() == 8, "the default setup owns eight independently configurable slots")
	_check(game.fighters.size() == 2, "the arena preserves the two-human default match")
	_check(game.fighters[0].controller is HumanFighterController, "a human slot receives the shared human controller")
	_check(game.fighters[1].controller is HumanFighterController, "fighter two can independently use human control")
	_check(game.fighters[0].get_weapon_name() == "Sword", "fighter one keeps the sword loadout")
	_check(game.fighters[1].get_weapon_name() == "Hammer", "fighter two keeps the hammer loadout")
	var first_setup_row: Dictionary = game.setup_rows[0]
	var first_control: OptionButton = first_setup_row["control"]
	var first_difficulty: OptionButton = first_setup_row["difficulty"]
	first_control.select(FighterSlotConfig.ControlType.CPU)
	game._refresh_setup_row(first_setup_row)
	_check(first_difficulty.visible, "CPU difficulty appears when a slot uses CPU control")
	first_control.select(FighterSlotConfig.ControlType.HUMAN)
	game._refresh_setup_row(first_setup_row)
	_check(not first_difficulty.visible, "CPU difficulty stays hidden for human control")

	var easy := CpuProfile.for_difficulty(FighterSlotConfig.CpuDifficulty.EASY)
	var medium := CpuProfile.for_difficulty(FighterSlotConfig.CpuDifficulty.MEDIUM)
	var hard := CpuProfile.for_difficulty(FighterSlotConfig.CpuDifficulty.HARD)
	_check(easy.reaction_delay > medium.reaction_delay and medium.reaction_delay > hard.reaction_delay, "CPU difficulty changes reaction time through editable profiles")
	_check(easy.attack_accuracy < medium.attack_accuracy and medium.attack_accuracy < hard.attack_accuracy, "CPU difficulty changes decision quality without stat bonuses")

	var fighter_one: Fighter = game.fighters[0]
	var fighter_two: Fighter = game.fighters[1]
	fighter_one.global_position = Vector2(560, 510)
	fighter_two.global_position = Vector2(640, 510)
	fighter_one.velocity = Vector2.ZERO
	fighter_two.velocity = Vector2.ZERO
	for frame in range(3):
		await physics_frame
	Input.action_press("p1_attack")
	await physics_frame
	Input.action_release("p1_attack")
	await physics_frame
	_check(fighter_two.health < Fighter.MAX_HEALTH, "human commands still drive normal weapon combat")

	fighter_two.health = Fighter.MAX_HEALTH
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
	_check(fighter_two.health > 95.0, "shared commands preserve defensive damage reduction")

	fighter_one.is_ducking = true
	fighter_one._update_collision_shape()
	var duck_shape := fighter_one.collision_shape.shape as CapsuleShape2D
	_check(is_equal_approx(duck_shape.height, Fighter.DUCKING_HEIGHT), "ducking still shortens the fighter collision shape")
	fighter_one.is_ducking = false
	fighter_one._update_collision_shape()
	fighter_one.global_position = Vector2(560, 510)
	fighter_two.global_position = Vector2(620, 510)
	fighter_two.health = Fighter.MAX_HEALTH
	fighter_one.kick_cooldown_remaining = 0.0
	_check(fighter_one._try_kick() and fighter_two.health < Fighter.MAX_HEALTH, "kicks still use the common combat entity")

	fighter_two.global_position = Vector2(760, 510)
	fighter_two.health = Fighter.MAX_HEALTH
	fighter_one._throw_or_pickup_weapon()
	await process_frame
	var thrown_weapons := get_nodes_in_group("world_weapons")
	_check(fighter_one.get_weapon_name() == "None" and thrown_weapons.size() == 1, "throwing creates one reusable world weapon")
	if thrown_weapons.size() == 1:
		var thrown := thrown_weapons[0]
		thrown.linear_velocity = Vector2(500, 0)
		thrown.damage_available = true
		thrown._on_body_entered(fighter_two)
		_check(fighter_two.health < Fighter.MAX_HEALTH, "a thrown weapon still damages a valid opponent")
		thrown.pickup_delay_remaining = 0.0
		thrown.global_position = fighter_one.global_position
		fighter_one._throw_or_pickup_weapon()
		await process_frame
		_check(fighter_one.get_weapon_name() == "Sword", "an unarmed fighter can still pick up any weapon")

	var team_slots := _make_slots(4, FighterSlotConfig.ControlType.CPU, 2)
	game.configure_match(team_slots, MatchManager.MatchMode.TEAM_BATTLE, false)
	await process_frame
	await physics_frame
	_check(game.fighters.size() == 4, "four-fighter matches spawn reliably")
	_check(game.fighters.all(func(fighter: Fighter) -> bool: return fighter.controller is CpuFighterController), "every CPU slot uses the same fighter implementation")
	var teammate: Fighter = game.fighters[1]
	var enemy: Fighter = game.fighters[2]
	var teammate_health := teammate.health
	_check(not teammate.receive_hit(10.0, Vector2.ZERO, game.fighters[0]), "friendly fire off rejects teammate damage")
	_check(is_equal_approx(teammate.health, teammate_health), "rejected teammate attacks do not change health")
	_check(enemy.receive_hit(10.0, Vector2.ZERO, game.fighters[0]), "team-aware combat accepts opponent damage")
	game.match_manager.friendly_fire = true
	_check(teammate.receive_hit(10.0, Vector2.ZERO, game.fighters[0]), "friendly fire can be enabled independently")
	game.match_manager.friendly_fire = false
	var cpu: CpuFighterController = game.fighters[0].controller
	cpu.reaction_remaining = 0.0
	cpu.decision_remaining = 0.0
	cpu.get_command(0.2)
	_check(cpu.target != null and cpu.target.team_id != game.fighters[0].team_id, "CPU target selection ignores teammates")

	game.fighters[2].defeat()
	game.fighters[3].defeat()
	await process_frame
	_check(game.match_manager.completed, "a 2 vs 2 team match completes when one team remains")

	var six_slots := _make_slots(6, FighterSlotConfig.ControlType.CPU, 3)
	game.configure_match(six_slots, MatchManager.MatchMode.TEAM_BATTLE, false)
	await process_frame
	await physics_frame
	_check(game.fighters.size() == 6, "a 3 vs 3 match can run with six fighters")
	_check(game.match_manager.get_opponents(game.fighters[0]).size() == 3, "3 vs 3 opponent detection returns only the other team")
	for fighter_index in range(3, 6):
		game.fighters[fighter_index].defeat()
	await process_frame
	_check(game.match_manager.completed, "a six-fighter 3 vs 3 match can complete")

	var eight_slots := _make_slots(8, FighterSlotConfig.ControlType.CPU, 4)
	game.configure_match(eight_slots, MatchManager.MatchMode.TEAM_BATTLE, false)
	await process_frame
	await physics_frame
	var unique_spawns: Dictionary = {}
	for fighter in game.fighters:
		unique_spawns[fighter.global_position] = true
	_check(game.fighters.size() == 8, "an eight-CPU stress configuration spawns all fighters")
	_check(unique_spawns.size() == 8, "eight fighters receive non-overlapping authored spawn points")
	_check(game.match_manager.get_opponents(game.fighters[0]).size() == 4, "four-versus-four is structurally supported")
	game.match_manager.match_mode = MatchManager.MatchMode.FREE_FOR_ALL
	_check(game.match_manager.get_opponents(game.fighters[0]).size() == 7, "free-for-all treats every other active fighter as an opponent")

	game.load_stage(1)
	await process_frame
	await physics_frame
	unique_spawns.clear()
	for fighter in game.fighters:
		unique_spawns[fighter.global_position] = true
	_check(game.current_stage is FreewayStage and game.fighters.size() == 8, "the Freeway stage accepts an eight-fighter test match")
	_check(unique_spawns.size() == 8, "fallback spawns safely supplement a stage with fewer authored points")
	_check(game.current_stage.is_drain_zone(Vector2(640, 620)), "the Freeway road remains a health-drain zone")
	var first_car_start: Vector2 = game.current_stage.cars[0].position
	for frame in range(3):
		await physics_frame
	_check(game.current_stage.cars[0].position != first_car_start, "Freeway vehicle platforms still move")
	var road_slots := _make_slots(1, FighterSlotConfig.ControlType.HUMAN)
	game.configure_match(road_slots, MatchManager.MatchMode.FREE_FOR_ALL, false)
	await process_frame
	await physics_frame
	var freeway_fighter: Fighter = game.fighters[0]
	freeway_fighter.set_controller(FighterController.new())
	freeway_fighter.global_position = Vector2(640, 610)
	freeway_fighter.velocity = Vector2.ZERO
	var health_before_road := freeway_fighter.health
	for frame in range(25):
		await physics_frame
	_check(freeway_fighter.is_on_floor() and freeway_fighter.health < health_before_road, "a fighter lands on the Freeway road and loses health")
	freeway_fighter.health = Fighter.MAX_HEALTH
	freeway_fighter.velocity.x = 145.0
	var horizontal_velocity_before_drain := freeway_fighter.velocity.x
	freeway_fighter._apply_stage_hazard(0.25)
	_check(is_equal_approx(freeway_fighter.velocity.x, horizontal_velocity_before_drain), "Freeway road damage preserves horizontal velocity")

	var cpu_duel := _make_slots(2, FighterSlotConfig.ControlType.CPU)
	game.configure_match(cpu_duel, MatchManager.MatchMode.FREE_FOR_ALL, false)
	game.load_stage(0)
	await process_frame
	await physics_frame
	game.fighters[0].global_position = Vector2(575, 510)
	game.fighters[1].global_position = Vector2(665, 510)
	game.fighters[0].velocity = Vector2.ZERO
	game.fighters[1].velocity = Vector2.ZERO
	var combined_health_before: float = game.fighters[0].health + game.fighters[1].health
	for frame in range(180):
		await physics_frame
	var combined_health_after: float = game.fighters[0].health + game.fighters[1].health
	_check(combined_health_after < combined_health_before, "CPU vs CPU produces combat without human input")

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
