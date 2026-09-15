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


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func _send_key(keycode: Key, pressed: bool) -> void:
	Input.parse_input_event(_key_event(keycode, pressed))


func _settle_on_floor(fighter: Fighter) -> void:
	for frame in range(30):
		await physics_frame
		if fighter.is_on_floor():
			return


func _arena_spawn_is_clear(stage: ArenaStage, fighter: Fighter, spawn: Vector2) -> bool:
	var capsule := fighter.collision_shape.shape as CapsuleShape2D
	var fighter_size := Vector2(capsule.radius * 2.0, capsule.height)
	var fighter_rect := Rect2(spawn + fighter.collision_shape.position - fighter_size * 0.5, fighter_size)
	for child in stage.get_children():
		if not child is StaticBody2D:
			continue
		for body_child in child.get_children():
			if not body_child is CollisionShape2D:
				continue
			var rectangle := body_child.shape as RectangleShape2D
			if rectangle == null:
				continue
			var platform_rect := Rect2(body_child.global_position - rectangle.size * 0.5, rectangle.size)
			if fighter_rect.intersects(platform_rect):
				return false
	return true


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
	_check(game.version_label.text == "v%s" % ProjectSettings.get_setting("application/config/version"), "the main HUD displays the centrally configured build version")
	_check(game.fighters[0].get_weapon_name() == "Sword", "fighter one keeps the sword loadout")
	_check(game.fighters[1].get_weapon_name() == "Hammer", "fighter two keeps the hammer loadout")
	var displayed_keyboard_actions := {
		"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W, "p1_crouch": KEY_S,
		"p1_attack": KEY_F, "p1_defend": KEY_G, "p1_kick": KEY_H, "p1_weapon_action": KEY_Q, "p1_taunt": KEY_E,
		"p2_left": KEY_J, "p2_right": KEY_L, "p2_jump": KEY_I, "p2_crouch": KEY_K,
		"p2_attack": KEY_O, "p2_defend": KEY_P, "p2_kick": KEY_M, "p2_weapon_action": KEY_U, "p2_taunt": KEY_N,
		"restart_round": KEY_R, "arena_stage": KEY_1, "freeway_stage": KEY_2,
		"swap_p1_weapon": KEY_T, "swap_p2_weapon": KEY_Y,
	}
	for action in displayed_keyboard_actions:
		var event := _key_event(displayed_keyboard_actions[action], true)
		_check(InputMap.event_is_action(event, action), "%s accepts its displayed physical keyboard key" % action)
	var arena: ArenaStage = game.current_stage
	for spawn in arena.get_spawn_points():
		_check(_arena_spawn_is_clear(arena, game.fighters[0], spawn), "an Arena spawn has clearance from every platform")
	await _settle_on_floor(game.fighters[0])
	var fighter_one_start_x: float = game.fighters[0].global_position.x
	_send_key(KEY_A, true)
	for frame in range(8):
		await physics_frame
	var fighter_one_moved_left: bool = game.fighters[0].velocity.x < 0.0 and game.fighters[0].global_position.x < fighter_one_start_x
	_send_key(KEY_A, false)
	await physics_frame
	_check(fighter_one_moved_left, "P1 can move immediately from the Arena start using the displayed A key")
	_send_key(KEY_TAB, true)
	await process_frame
	_send_key(KEY_TAB, false)
	await process_frame
	_check(game.setup_panel.visible and paused, "Tab opens Match Setup and pauses gameplay")
	var paused_position: Vector2 = game.fighters[0].global_position
	_send_key(KEY_A, true)
	for frame in range(4):
		await process_frame
	_send_key(KEY_A, false)
	await process_frame
	_check(game.fighters[0].global_position.is_equal_approx(paused_position), "gameplay stays paused while Match Setup is open")
	_send_key(KEY_TAB, true)
	await process_frame
	_send_key(KEY_TAB, false)
	await process_frame
	_check(not game.setup_panel.visible and not paused, "Tab closes Match Setup while paused")
	fighter_one_start_x = game.fighters[0].global_position.x
	Input.action_press("p1_right")
	for frame in range(12):
		await physics_frame
	var fighter_one_resumed_right: bool = game.fighters[0].velocity.x > 0.0
	Input.action_release("p1_right")
	await physics_frame
	_check(fighter_one_resumed_right, "keyboard movement resumes after Match Setup closes")
	var fighter_two_start_x: float = game.fighters[1].global_position.x
	_send_key(KEY_L, true)
	for frame in range(4):
		await physics_frame
	_send_key(KEY_L, false)
	await physics_frame
	_check(game.fighters[1].global_position.x > fighter_two_start_x, "P2 can move using the displayed L key")
	var first_setup_row: Dictionary = game.setup_rows[0]
	var first_control: OptionButton = first_setup_row["control"]
	var first_difficulty: OptionButton = first_setup_row["difficulty"]
	first_control.select(FighterSlotConfig.ControlType.CPU)
	game._refresh_setup_row(first_setup_row)
	_check(first_difficulty.visible, "CPU difficulty appears when a slot uses CPU control")
	first_control.select(FighterSlotConfig.ControlType.HUMAN)
	game._refresh_setup_row(first_setup_row)
	_check(not first_difficulty.visible, "CPU difficulty stays hidden for human control")
	var human_item_index := first_control.get_item_index(FighterSlotConfig.ControlType.HUMAN)
	_check(not first_control.is_item_disabled(human_item_index), "Fighter 1 keeps the Human control option")
	var second_control: OptionButton = game.setup_rows[1]["control"]
	_check(not second_control.is_item_disabled(second_control.get_item_index(FighterSlotConfig.ControlType.HUMAN)), "Fighter 2 keeps the Human control option")
	for index in range(2, MatchManager.MAX_FIGHTERS):
		var extra_control: OptionButton = game.setup_rows[index]["control"]
		_check(extra_control.is_item_disabled(extra_control.get_item_index(FighterSlotConfig.ControlType.HUMAN)), "Fighter %d cannot select an unmapped Human controller" % (index + 1))
	var third_control: OptionButton = game.setup_rows[2]["control"]
	third_control.select(third_control.get_item_index(FighterSlotConfig.ControlType.HUMAN))
	game._apply_setup()
	_check(game.setup_message.text == "Only Fighter 1 and Fighter 2 can use Human controls.", "Match Setup rejects an invalid extra Human assignment")
	third_control.select(third_control.get_item_index(FighterSlotConfig.ControlType.DISABLED))
	game.setup_message.text = ""
	_check(game.friendly_fire_toggle.text == "Hit Teammates", "the team damage option uses child-friendly wording")
	_check(not game.team_heading.visible and not first_setup_row["team"].visible and not game.friendly_fire_toggle.visible, "team fields stay hidden in Free For All")
	_check(game.setup_grid.columns == 4, "Free For All keeps the setup grid aligned without the Team column")
	game.mode_selector.select(MatchManager.MatchMode.TEAM_BATTLE)
	game._refresh_setup_mode()
	_check(game.team_heading.visible and first_setup_row["team"].visible and game.friendly_fire_toggle.visible, "Team Battle reveals its team fields")
	_check(game.setup_grid.columns == 5, "Team Battle restores the Team column")
	game.mode_selector.select(MatchManager.MatchMode.FREE_FOR_ALL)
	game._refresh_setup_mode()

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
	await _settle_on_floor(fighter_one)
	await _settle_on_floor(fighter_two)
	Input.action_press("p1_attack")
	await physics_frame
	Input.action_release("p1_attack")
	await physics_frame
	_check(fighter_two.health < Fighter.MAX_HEALTH, "human commands still drive normal weapon combat")
	_check(fighter_two.damage_flash_remaining > 0.0 and fighter_two.is_damage_blink_visible(), "taking a hit starts the recognizable damage blink")
	_check(Fighter.DAMAGE_FLASH_COLOR != game.slot_configs[1].fighter_color, "the damage red differs from the red fighter color")
	fighter_two.damage_flash_elapsed = Fighter.DAMAGE_BLINK_INTERVAL + 0.01
	_check(not fighter_two.is_damage_blink_visible(), "the damage feedback visibly alternates instead of staying solid red")
	var elapsed_before_continuous_damage := fighter_two.damage_flash_elapsed
	fighter_two.receive_environment_damage(1.0)
	_check(is_equal_approx(fighter_two.damage_flash_elapsed, elapsed_before_continuous_damage), "continuous damage extends the blink without freezing its pulse phase")
	fighter_one.weapon.attack_flash_remaining = BrawlerWeapon.ATTACK_ANIMATION_DURATION * 0.5
	fighter_one.weapon._update_attack_pose()
	var sword_thrusts_forward := fighter_one.weapon.position.x > 0.0 and is_zero_approx(fighter_one.weapon.rotation)
	_check(sword_thrusts_forward, "the sword attack animates as a forward thrust")
	fighter_one.weapon.attack_flash_remaining = 0.0
	fighter_one.weapon._update_attack_pose()
	fighter_two.weapon.attack_flash_remaining = BrawlerWeapon.ATTACK_ANIMATION_DURATION
	fighter_two.weapon._update_attack_pose()
	var hammer_start_rotation := fighter_two.weapon.rotation
	fighter_two.weapon.attack_flash_remaining = BrawlerWeapon.ATTACK_ANIMATION_DURATION * 0.25
	fighter_two.weapon._update_attack_pose()
	_check(hammer_start_rotation < -1.0 and fighter_two.weapon.rotation > hammer_start_rotation, "the hammer attack swings down from above")
	fighter_two.weapon.attack_flash_remaining = 0.0
	fighter_two.weapon._update_attack_pose()

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

	fighter_one.taunt_remaining = 0.0
	await _settle_on_floor(fighter_one)
	_check(fighter_one.is_on_floor(), "P1 is grounded before stance input checks")
	_check(fighter_one.controller is HumanFighterController, "P1 retains human input ownership before stance checks")
	Input.action_press("p1_crouch")
	await physics_frame
	var crouch_shape := fighter_one.collision_shape.shape as CapsuleShape2D
	_check(fighter_one.is_crouching, "the displayed S key activates P1 crouch")
	_check(is_equal_approx(crouch_shape.height, Fighter.CROUCHING_HEIGHT), "crouching shortens the fighter collision shape")
	_check(is_equal_approx(fighter_one.collision_shape.position.y + crouch_shape.height * 0.5, 46.0), "the crouching collision shape stays grounded")
	_check(fighter_one.weapon_mount.position.is_equal_approx(Fighter.CROUCHING_WEAPON_MOUNT), "the crouching weapon pose moves down with the fighter")
	fighter_one.kick_cooldown_remaining = 0.0
	var crouching_kick := FighterCommand.new()
	crouching_kick.crouch = true
	crouching_kick.kick = true
	fighter_one._apply_command(crouching_kick, 0.0)
	_check(fighter_one.kick_flash_remaining > 0.0 and fighter_one.is_crouching, "a grounded crouching player can kick without standing up")
	_check(is_equal_approx(absf(fighter_one.weapon_mount.rotation), PI * 0.5), "the crouching kick holds the weapon upright")
	Input.action_release("p1_crouch")
	await physics_frame
	fighter_one.kick_cooldown_remaining = 0.0
	Input.action_press("p1_kick")
	await physics_frame
	Input.action_release("p1_kick")
	_check(fighter_one.kick_flash_remaining > 0.0 and not fighter_one.is_crouching, "a standing kick uses its distinct upright pose")
	_check(is_equal_approx(absf(fighter_one.weapon_mount.rotation), PI * 0.5), "the standing kick holds the weapon upright")
	Input.action_press("p1_taunt")
	await physics_frame
	_check(fighter_one.is_taunting and not fighter_one.weapon_mount.visible, "a held taunt hides the equipped weapon")
	Input.action_release("p1_taunt")
	await physics_frame
	_check(not fighter_one.is_taunting and fighter_one.weapon_mount.visible, "releasing taunt restores the equipped weapon")
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

	var human_cpu_slots := _make_slots(2, FighterSlotConfig.ControlType.HUMAN)
	human_cpu_slots[1].control_type = FighterSlotConfig.ControlType.CPU
	game.configure_match(human_cpu_slots, MatchManager.MatchMode.FREE_FOR_ALL, false)
	await process_frame
	await physics_frame
	_check(game.fighters[0].controller is HumanFighterController and game.fighters[1].controller is CpuFighterController, "P1 human and P2 CPU keep separate input ownership")
	var cpu_human_slots := _make_slots(2, FighterSlotConfig.ControlType.HUMAN)
	cpu_human_slots[0].control_type = FighterSlotConfig.ControlType.CPU
	game.configure_match(cpu_human_slots, MatchManager.MatchMode.FREE_FOR_ALL, false)
	await process_frame
	await physics_frame
	_check(game.fighters[0].controller is CpuFighterController and game.fighters[1].controller is HumanFighterController, "P1 CPU and P2 human keep separate input ownership")
	var solo_team_slots := _make_slots(2, FighterSlotConfig.ControlType.CPU)
	game.configure_match(solo_team_slots, MatchManager.MatchMode.TEAM_BATTLE, false)
	await process_frame
	await physics_frame
	game.fighters[1].defeat()
	await process_frame
	_check(game.round_label.text.begins_with("Player 1 wins"), "a one-player-per-team battle announces the winning player")
	_check(game.reset_pending and game.round_label.text.ends_with("press any key to restart"), "a completed match waits with a clear restart prompt")
	var completed_round_generation: int = game.round_generation
	_send_key(KEY_SPACE, true)
	await process_frame
	_send_key(KEY_SPACE, false)
	await process_frame
	_check(not game.reset_pending and game.round_generation == completed_round_generation + 1, "a fresh key press restarts the completed match")

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
	_check(game.round_label.text.begins_with("Team 1 wins"), "a multi-player team battle announces the winning team")

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
	arena = game.current_stage
	for spawn in arena.get_spawn_points():
		_check(_arena_spawn_is_clear(arena, game.fighters[0], spawn), "an eight-player Arena spawn remains clear of platform collision")
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
