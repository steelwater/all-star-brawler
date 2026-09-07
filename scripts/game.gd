extends Node2D

const FIGHTER_SCENE := preload("res://characters/fighter.tscn")
const ARENA_SCENE := preload("res://stages/arena.tscn")
const FREEWAY_SCENE := preload("res://stages/freeway.tscn")
const SWORD: WeaponDefinition = preload("res://weapons/sword.tres")
const HAMMER: WeaponDefinition = preload("res://weapons/hammer.tres")
const FIGHTER_COLORS := [
	Color("4dabf7"), Color("ff6b6b"), Color("69db7c"), Color("ffd43b"),
	Color("b197fc"), Color("ff922b"), Color("38d9a9"), Color("f06595"),
]

@onready var health_label: Label = $HUD/SafeArea/TopBar/Health
@onready var stage_label: Label = $HUD/SafeArea/TopBar/Stage
@onready var weapon_label: Label = $HUD/SafeArea/WeaponStatus
@onready var round_label: Label = $HUD/SafeArea/RoundStatus
@onready var setup_button: Button = $HUD/SafeArea/SetupButton

var current_stage: Node2D
var fighters: Array[Fighter] = []
var slot_configs: Array[FighterSlotConfig] = []
var match_manager: MatchManager
var stage_index := 0
var reset_pending := false
var round_generation := 0
var setup_panel: PanelContainer
var setup_rows: Array[Dictionary] = []
var mode_selector: OptionButton
var friendly_fire_toggle: CheckButton
var setup_message: Label


func _ready() -> void:
	match_manager = MatchManager.new()
	match_manager.name = "MatchManager"
	add_child(match_manager)
	match_manager.match_completed.connect(_on_match_completed)
	_create_default_slots()
	_build_setup_panel()
	setup_button.pressed.connect(_show_setup)
	configure_match(slot_configs, MatchManager.MatchMode.FREE_FOR_ALL, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_round"):
		reset_round()
	elif event.is_action_pressed("arena_stage"):
		load_stage(0)
	elif event.is_action_pressed("freeway_stage"):
		load_stage(1)
	elif event.is_action_pressed("swap_p1_weapon"):
		_swap_weapon(0)
	elif event.is_action_pressed("swap_p2_weapon"):
		_swap_weapon(1)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB:
		_show_setup()


func configure_match(slots: Array[FighterSlotConfig], match_mode: int, friendly_fire: bool) -> void:
	slot_configs = slots.slice(0, MatchManager.MAX_FIGHTERS)
	match_manager.configure(slot_configs, match_mode, friendly_fire)
	load_stage(stage_index)


func load_stage(new_stage_index: int) -> void:
	round_generation += 1
	stage_index = clampi(new_stage_index, 0, 1)
	reset_pending = false
	round_label.text = ""
	for fighter in fighters:
		fighter.queue_free()
	fighters.clear()
	match_manager.clear_fighters()
	for world_weapon in get_tree().get_nodes_in_group("world_weapons"):
		world_weapon.queue_free()
	if current_stage != null:
		current_stage.queue_free()
	current_stage = (ARENA_SCENE if stage_index == 0 else FREEWAY_SCENE).instantiate()
	add_child(current_stage)
	move_child(current_stage, 0)
	var active_slots: Array[FighterSlotConfig] = []
	for slot in slot_configs:
		if slot.is_enabled():
			active_slots.append(slot)
	var spawn_points := _resolve_spawn_points(current_stage.get_spawn_points(), active_slots.size())
	for index in active_slots.size():
		var slot := active_slots[index]
		var spawn_index := clampi(slot.spawn_index, 0, spawn_points.size() - 1)
		if spawn_index >= active_slots.size():
			spawn_index = index
		_spawn_fighter(slot, spawn_points[spawn_index])
	stage_label.text = "%s  •  %s" % [
		"Arena" if stage_index == 0 else "Freeway",
		"Free For All" if match_manager.match_mode == MatchManager.MatchMode.FREE_FOR_ALL else "Team Battle",
	]
	_refresh_status()


func reset_round() -> void:
	load_stage(stage_index)


func _spawn_fighter(slot: FighterSlotConfig, spawn_position: Vector2) -> void:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.fighter_id = slot.slot_id
	fighter.team_id = slot.team_id
	fighter.fighter_color = slot.fighter_color
	fighter.starting_weapon = slot.starting_weapon
	fighter.match_manager = match_manager
	fighter.health_changed.connect(_on_health_changed)
	fighter.defeated_changed.connect(_on_fighter_defeated.bind(fighter))
	fighter.weapon_changed.connect(_refresh_status)
	add_child(fighter)
	fighter.global_position = spawn_position
	fighter.facing = 1.0 if spawn_position.x < 640.0 else -1.0
	match_manager.register_fighter(fighter)
	if slot.control_type == FighterSlotConfig.ControlType.HUMAN:
		var human := HumanFighterController.new()
		human.configure(slot.input_player)
		fighter.set_controller(human)
	else:
		var cpu := CpuFighterController.new()
		cpu.configure(fighter, match_manager, slot.cpu_difficulty)
		fighter.set_controller(cpu)
	fighters.append(fighter)


func _resolve_spawn_points(authored_points: Array[Vector2], count: int) -> Array[Vector2]:
	var result := authored_points.duplicate()
	for index in range(result.size(), count):
		var denominator := maxi(1, count - 1)
		var x := lerpf(160.0, 1120.0, float(index) / float(denominator))
		var y := 500.0 - float(index % 2) * 75.0
		result.append(Vector2(x, y))
	return result


func _swap_weapon(fighter_index: int) -> void:
	if fighter_index >= fighters.size():
		return
	var fighter := fighters[fighter_index]
	var next_weapon: WeaponDefinition
	if fighter.weapon == null or fighter.weapon.definition == null:
		next_weapon = SWORD if fighter_index == 0 else HAMMER
	else:
		next_weapon = HAMMER if fighter.weapon.definition.id == SWORD.id else SWORD
	fighter.equip_weapon(next_weapon)


func _refresh_status() -> void:
	var health_parts: Array[String] = []
	var weapon_parts: Array[String] = []
	for fighter in fighters:
		health_parts.append("F%d T%d: %d" % [fighter.fighter_id, fighter.team_id, ceili(fighter.health)])
		weapon_parts.append("F%d %s" % [fighter.fighter_id, fighter.get_weapon_name()])
	health_label.text = "  •  ".join(health_parts)
	weapon_label.text = "Weapons  •  %s" % "    ".join(weapon_parts)


func _on_health_changed(_fighter_id: int, _health: float) -> void:
	_refresh_status()


func _on_fighter_defeated(_fighter_id: int, fighter: Fighter) -> void:
	_refresh_status()
	match_manager.record_defeat(fighter)


func _on_match_completed(winning_team_id: int, winning_fighter_ids: Array[int]) -> void:
	if reset_pending:
		return
	reset_pending = true
	if winning_fighter_ids.is_empty():
		round_label.text = "Draw — restarting..."
	elif match_manager.match_mode == MatchManager.MatchMode.TEAM_BATTLE:
		round_label.text = "Team %d wins — restarting..." % winning_team_id
	else:
		round_label.text = "Fighter %d wins — restarting..." % winning_fighter_ids[0]
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_restart_if_current.bind(round_generation))


func _restart_if_current(generation: int) -> void:
	if generation == round_generation:
		reset_round()


func _create_default_slots() -> void:
	for index in MatchManager.MAX_FIGHTERS:
		var slot := FighterSlotConfig.new()
		slot.slot_id = index + 1
		slot.spawn_index = index
		slot.team_id = index + 1
		slot.input_player = index + 1
		slot.fighter_color = FIGHTER_COLORS[index]
		slot.starting_weapon = SWORD if index % 2 == 0 else HAMMER
		slot.control_type = FighterSlotConfig.ControlType.HUMAN if index < 2 else FighterSlotConfig.ControlType.DISABLED
		slot_configs.append(slot)


func _build_setup_panel() -> void:
	setup_panel = PanelContainer.new()
	setup_panel.name = "MatchSetup"
	setup_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	setup_panel.set_anchors_preset(Control.PRESET_CENTER)
	setup_panel.offset_left = -470.0
	setup_panel.offset_top = -315.0
	setup_panel.offset_right = 470.0
	setup_panel.offset_bottom = 315.0
	$HUD.add_child(setup_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	setup_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title := Label.new()
	title.text = "MATCH SETUP — UP TO 8 FIGHTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var rules := HBoxContainer.new()
	rules.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(rules)
	var mode_label := Label.new()
	mode_label.text = "Mode"
	rules.add_child(mode_label)
	mode_selector = OptionButton.new()
	mode_selector.add_item("Free For All", MatchManager.MatchMode.FREE_FOR_ALL)
	mode_selector.add_item("Team Battle", MatchManager.MatchMode.TEAM_BATTLE)
	rules.add_child(mode_selector)
	friendly_fire_toggle = CheckButton.new()
	friendly_fire_toggle.text = "Friendly Fire"
	rules.add_child(friendly_fire_toggle)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	content.add_child(grid)
	for heading in ["Slot", "Character", "Control", "CPU Difficulty", "Team"]:
		var heading_label := Label.new()
		heading_label.text = heading
		grid.add_child(heading_label)
	for index in MatchManager.MAX_FIGHTERS:
		var slot_label := Label.new()
		slot_label.text = "Fighter %d" % (index + 1)
		grid.add_child(slot_label)
		var character_label := Label.new()
		character_label.text = "Prototype Fighter"
		character_label.custom_minimum_size.x = 145.0
		grid.add_child(character_label)
		var control := OptionButton.new()
		control.custom_minimum_size.x = 130.0
		control.add_item("Human", FighterSlotConfig.ControlType.HUMAN)
		control.add_item("CPU", FighterSlotConfig.ControlType.CPU)
		control.add_item("Disabled", FighterSlotConfig.ControlType.DISABLED)
		control.select(slot_configs[index].control_type)
		grid.add_child(control)
		var difficulty := OptionButton.new()
		difficulty.custom_minimum_size.x = 130.0
		difficulty.add_item("Easy", FighterSlotConfig.CpuDifficulty.EASY)
		difficulty.add_item("Medium", FighterSlotConfig.CpuDifficulty.MEDIUM)
		difficulty.add_item("Hard", FighterSlotConfig.CpuDifficulty.HARD)
		difficulty.select(slot_configs[index].cpu_difficulty)
		var difficulty_cell := HBoxContainer.new()
		difficulty_cell.custom_minimum_size.x = 130.0
		difficulty_cell.add_child(difficulty)
		grid.add_child(difficulty_cell)
		var team := SpinBox.new()
		team.custom_minimum_size.x = 80.0
		team.min_value = 1
		team.max_value = 8
		team.value = slot_configs[index].team_id
		grid.add_child(team)
		var row := {"control": control, "difficulty": difficulty, "team": team}
		setup_rows.append(row)
		control.item_selected.connect(func(_selected: int) -> void: _refresh_setup_row(row))
		_refresh_setup_row(row)
	setup_message = Label.new()
	setup_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_message.add_theme_color_override("font_color", Color("ff8787"))
	content.add_child(setup_message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_hide_setup)
	buttons.add_child(cancel)
	var start := Button.new()
	start.text = "Start Match"
	start.pressed.connect(_apply_setup)
	buttons.add_child(start)
	setup_panel.hide()


func _refresh_setup_row(row: Dictionary) -> void:
	var control: OptionButton = row["control"]
	var difficulty: OptionButton = row["difficulty"]
	difficulty.visible = control.get_selected_id() == FighterSlotConfig.ControlType.CPU


func _show_setup() -> void:
	setup_message.text = ""
	setup_panel.show()
	get_tree().paused = true


func _hide_setup() -> void:
	setup_panel.hide()
	get_tree().paused = false


func _apply_setup() -> void:
	var enabled_count := 0
	var teams: Dictionary = {}
	for index in setup_rows.size():
		var row := setup_rows[index]
		var control: OptionButton = row["control"]
		var difficulty: OptionButton = row["difficulty"]
		var team: SpinBox = row["team"]
		slot_configs[index].control_type = control.get_selected_id()
		slot_configs[index].cpu_difficulty = difficulty.get_selected_id()
		slot_configs[index].team_id = int(team.value)
		if slot_configs[index].is_enabled():
			enabled_count += 1
			teams[slot_configs[index].team_id] = true
	if enabled_count < 2:
		setup_message.text = "Enable at least two fighters."
		return
	var selected_mode := mode_selector.get_selected_id()
	if selected_mode == MatchManager.MatchMode.TEAM_BATTLE and teams.size() < 2:
		setup_message.text = "Team Battle needs at least two teams."
		return
	_hide_setup()
	configure_match(slot_configs, selected_mode, friendly_fire_toggle.button_pressed)
