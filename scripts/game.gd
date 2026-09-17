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
const MAX_LOCAL_HUMAN_FIGHTERS := 2

@onready var health_label: Label = $HUD/SafeArea/TopBar/Health
@onready var stage_label: Label = $HUD/SafeArea/TopBar/Stage
@onready var weapon_label: Label = $HUD/SafeArea/WeaponStatus
@onready var round_label: Label = $HUD/SafeArea/RoundStatus
@onready var setup_button: Button = $HUD/SafeArea/SetupButton
@onready var version_label: Label = $HUD/SafeArea/Version

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
var setup_grid: GridContainer
var team_heading: Label
var setup_message: Label
var library_store := LibraryStore.new()
var library_panel: LibraryPanel
var library_button: Button


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	match_manager = MatchManager.new()
	match_manager.name = "MatchManager"
	add_child(match_manager)
	match_manager.match_completed.connect(_on_match_completed)
	_create_default_slots()
	_build_setup_panel()
	_build_library()
	setup_button.pressed.connect(_show_setup)
	configure_match(slot_configs, MatchManager.MatchMode.FREE_FOR_ALL, false)


func _unhandled_input(event: InputEvent) -> void:
	if library_panel != null and library_panel.visible:
		return
	var key_event := event as InputEventKey
	var is_new_key_press := key_event != null and key_event.pressed and not key_event.echo
	var menu_button: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if menu_button or (is_new_key_press and key_event.physical_keycode == KEY_F3):
		_show_library()
		get_viewport().set_input_as_handled()
		return
	if reset_pending and is_new_key_press and not setup_panel.visible:
		reset_round()
		get_viewport().set_input_as_handled()
		return
	var is_setup_toggle := is_new_key_press and key_event.physical_keycode == KEY_TAB
	if is_setup_toggle:
		_toggle_setup()
		get_viewport().set_input_as_handled()
		return
	if setup_panel != null and setup_panel.visible:
		return
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
	current_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(current_stage)
	move_child(current_stage, 0)
	var active_slots: Array[FighterSlotConfig] = []
	for slot in slot_configs:
		if slot.is_enabled():
			active_slots.append(slot)
	var spawn_points := _resolve_spawn_points(current_stage, active_slots.size())
	var used_spawn_indexes: Dictionary = {}
	for index in active_slots.size():
		var slot := active_slots[index]
		var spawn_index := clampi(slot.spawn_index, 0, spawn_points.size() - 1)
		if used_spawn_indexes.has(spawn_index):
			for candidate_index in spawn_points.size():
				if not used_spawn_indexes.has(candidate_index):
					spawn_index = candidate_index
					break
		used_spawn_indexes[spawn_index] = true
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
	fighter.process_mode = Node.PROCESS_MODE_PAUSABLE
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


func _resolve_spawn_points(stage: Node2D, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = stage.get_spawn_points().duplicate()
	if stage.has_method("get_fallback_spawn_points"):
		var safe_fallbacks: Array[Vector2] = stage.get_fallback_spawn_points()
		for fallback in safe_fallbacks:
			if result.size() >= count:
				break
			result.append(fallback)
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
		round_label.text = "Draw — press any key to restart"
	elif match_manager.match_mode == MatchManager.MatchMode.TEAM_BATTLE:
		if match_manager.teams_have_one_fighter_each():
			round_label.text = "Player %d wins — press any key to restart" % winning_fighter_ids[0]
		else:
			round_label.text = "Team %d wins — press any key to restart" % winning_team_id
	else:
		round_label.text = "Fighter %d wins — press any key to restart" % winning_fighter_ids[0]


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
	friendly_fire_toggle.text = "Hit Teammates"
	rules.add_child(friendly_fire_toggle)
	setup_grid = GridContainer.new()
	setup_grid.columns = 5
	setup_grid.add_theme_constant_override("h_separation", 12)
	setup_grid.add_theme_constant_override("v_separation", 5)
	content.add_child(setup_grid)
	for heading in ["Slot", "Character", "Control", "CPU Difficulty", "Team"]:
		var heading_label := Label.new()
		heading_label.text = heading
		setup_grid.add_child(heading_label)
		if heading == "Team":
			team_heading = heading_label
	for index in MatchManager.MAX_FIGHTERS:
		var slot_label := Label.new()
		slot_label.text = "Fighter %d" % (index + 1)
		setup_grid.add_child(slot_label)
		var character := OptionButton.new()
		character.custom_minimum_size.x = 180.0
		character.fit_to_longest_item = false
		character.clip_text = true
		setup_grid.add_child(character)
		var control := OptionButton.new()
		control.custom_minimum_size.x = 130.0
		control.add_item("Human", FighterSlotConfig.ControlType.HUMAN)
		control.add_item("CPU", FighterSlotConfig.ControlType.CPU)
		control.add_item("Disabled", FighterSlotConfig.ControlType.DISABLED)
		var human_item_index := control.get_item_index(FighterSlotConfig.ControlType.HUMAN)
		if index >= MAX_LOCAL_HUMAN_FIGHTERS:
			control.set_item_disabled(human_item_index, true)
			control.set_item_tooltip(human_item_index, "Only Fighter 1 and Fighter 2 have keyboard controls.")
		control.select(slot_configs[index].control_type)
		setup_grid.add_child(control)
		var difficulty := OptionButton.new()
		difficulty.custom_minimum_size.x = 130.0
		difficulty.add_item("Easy", FighterSlotConfig.CpuDifficulty.EASY)
		difficulty.add_item("Medium", FighterSlotConfig.CpuDifficulty.MEDIUM)
		difficulty.add_item("Hard", FighterSlotConfig.CpuDifficulty.HARD)
		difficulty.select(slot_configs[index].cpu_difficulty)
		var difficulty_cell := HBoxContainer.new()
		difficulty_cell.custom_minimum_size.x = 130.0
		difficulty_cell.add_child(difficulty)
		setup_grid.add_child(difficulty_cell)
		var team := SpinBox.new()
		team.custom_minimum_size.x = 80.0
		team.min_value = 1
		team.max_value = 8
		team.value = slot_configs[index].team_id
		setup_grid.add_child(team)
		var row := {"character": character, "control": control, "difficulty": difficulty, "team": team}
		setup_rows.append(row)
		control.item_selected.connect(func(_selected: int) -> void: _refresh_setup_row(row))
		_refresh_setup_row(row)
	mode_selector.item_selected.connect(func(_selected: int) -> void: _refresh_setup_mode())
	_refresh_setup_mode()
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


func _refresh_setup_mode() -> void:
	var uses_teams := mode_selector.get_selected_id() == MatchManager.MatchMode.TEAM_BATTLE
	friendly_fire_toggle.visible = uses_teams
	team_heading.visible = uses_teams
	setup_grid.columns = 5 if uses_teams else 4
	for row in setup_rows:
		var team: SpinBox = row["team"]
		team.visible = uses_teams


func _show_setup() -> void:
	if library_panel != null and library_panel.visible:
		return
	setup_message.text = ""
	_refresh_character_choices()
	_refresh_setup_mode()
	setup_panel.show()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for world_weapon in get_tree().get_nodes_in_group("world_weapons"):
		world_weapon.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true


func _hide_setup() -> void:
	setup_panel.hide()
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	get_viewport().gui_release_focus()


func _toggle_setup() -> void:
	if setup_panel.visible:
		_hide_setup()
	else:
		_show_setup()


func _apply_setup() -> void:
	var pending_controls: Array[int] = []
	var pending_difficulties: Array[int] = []
	var pending_teams: Array[int] = []
	var enabled_count := 0
	var teams: Dictionary = {}
	for index in setup_rows.size():
		var row := setup_rows[index]
		var control: OptionButton = row["control"]
		var difficulty: OptionButton = row["difficulty"]
		var team: SpinBox = row["team"]
		var selected_control := control.get_selected_id()
		var selected_team := int(team.value)
		if index >= MAX_LOCAL_HUMAN_FIGHTERS and selected_control == FighterSlotConfig.ControlType.HUMAN:
			setup_message.text = "Only Fighter 1 and Fighter 2 can use Human controls."
			return
		pending_controls.append(selected_control)
		pending_difficulties.append(difficulty.get_selected_id())
		pending_teams.append(selected_team)
		if selected_control != FighterSlotConfig.ControlType.DISABLED:
			enabled_count += 1
			teams[selected_team] = true
	if enabled_count < 2:
		setup_message.text = "Enable at least two fighters."
		return
	var selected_mode := mode_selector.get_selected_id()
	if selected_mode == MatchManager.MatchMode.TEAM_BATTLE and teams.size() < 2:
		setup_message.text = "Team Battle needs at least two teams."
		return
	var pending_fighters: Array[Dictionary] = []
	for row in setup_rows:
		var character: OptionButton = row["character"]
		var id: String = character.get_item_metadata(character.selected)
		var record := {} if id.is_empty() else library_store.get_fighter(id)
		if not id.is_empty() and record.is_empty():
			setup_message.text = "A selected fighter is no longer available. Choose another fighter."
			return
		pending_fighters.append(record)
	for index in setup_rows.size():
		if pending_fighters[index].is_empty():
			slot_configs[index].library_fighter_id = ""
			slot_configs[index].character_id = &"prototype_fighter"
			slot_configs[index].fighter_color = FIGHTER_COLORS[index]
			slot_configs[index].starting_weapon = SWORD if index % 2 == 0 else HAMMER
		else:
			LibraryItem.apply_to_slot(pending_fighters[index], slot_configs[index])
		slot_configs[index].control_type = pending_controls[index]
		slot_configs[index].cpu_difficulty = pending_difficulties[index]
		slot_configs[index].team_id = pending_teams[index]
	_hide_setup()
	var allow_team_hits := selected_mode == MatchManager.MatchMode.TEAM_BATTLE and friendly_fire_toggle.button_pressed
	configure_match(slot_configs, selected_mode, allow_team_hits)


func _build_library() -> void:
	library_panel = LibraryPanel.new()
	library_panel.store = library_store
	$HUD.add_child(library_panel)
	library_panel.closed.connect(_close_library)
	library_panel.fighter_selected.connect(_choose_library_fighter)
	library_panel.collection_changed.connect(_refresh_character_choices)
	library_button = Button.new()
	library_button.text = "Library (F3)"
	library_button.position = Vector2(24, 145)
	library_button.custom_minimum_size = Vector2(140, 42)
	library_button.pressed.connect(_show_library)
	$HUD/SafeArea.add_child(library_button)
	_refresh_character_choices()


func _refresh_character_choices() -> void:
	var records := library_store.list_fighters()
	for index in setup_rows.size():
		var choice: OptionButton = setup_rows[index]["character"]
		var selected_id := slot_configs[index].library_fighter_id
		if choice.item_count > 0:
			selected_id = choice.get_item_metadata(choice.selected)
		choice.clear()
		choice.add_item("Prototype Fighter")
		choice.set_item_metadata(0, "")
		for record in records:
			choice.add_item(record["display_name"])
			choice.set_item_metadata(choice.item_count - 1, record["id"])
			if record["id"] == selected_id:
				choice.select(choice.item_count - 1)


func _show_library() -> void:
	if library_panel.visible:
		return
	setup_panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for world_weapon in get_tree().get_nodes_in_group("world_weapons"):
		world_weapon.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	setup_button.focus_mode = Control.FOCUS_NONE
	library_button.focus_mode = Control.FOCUS_NONE
	library_panel.open()


func _close_library() -> void:
	setup_button.focus_mode = Control.FOCUS_ALL
	library_button.focus_mode = Control.FOCUS_ALL
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	get_viewport().gui_release_focus()


func _choose_library_fighter(id: String, slot_index: int) -> void:
	library_panel.hide()
	setup_button.focus_mode = Control.FOCUS_ALL
	library_button.focus_mode = Control.FOCUS_ALL
	_show_setup()
	var choice: OptionButton = setup_rows[slot_index]["character"]
	for index in choice.item_count:
		if choice.get_item_metadata(index) == id:
			choice.select(index)
	choice.grab_focus()
	setup_message.text = "Fighter selected. Choose control and team, then Start Match."
