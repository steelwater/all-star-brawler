extends SceneTree

var failures: Array[String] = []
var ui_completed := false
var directory := "user://library-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
var payload := {"character_id": "prototype_fighter", "color": "ff6b6b", "weapon_id": "hammer"}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		failures.append(label)


func _write(filename: String, data: String) -> void:
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	file.store_string(data)
	file.close()


func _run() -> void:
	var store := LibraryStore.new(directory)
	_check(store.list_fighters().is_empty(), "A first-time player starts with an empty collection")
	var fighter := store.save_fighter("Ruby", payload)
	_check(not fighter.is_empty(), "A named fighter can be saved")
	if fighter.is_empty():
		quit(1)
		return
	var id: String = fighter["id"]
	_check(LibraryItem.valid_id(id), "Identity is generated independently of the name")
	var reloaded := LibraryStore.new(directory)
	var loaded := reloaded.get_fighter(id)
	var all_fields_match := loaded.size() == fighter.size()
	for key in fighter:
		all_fields_match = all_fields_match and loaded.get(key) == fighter[key]
	_check(all_fields_match, "A fresh store loads all saved fighter data")
	var changed := payload.duplicate()
	changed["color"] = "4dabf7"
	var updated := store.save_fighter("Ruby Blue", changed, id)
	_check(updated["id"] == id and store.list_fighters().size() == 1, "Re-saving updates the existing fighter")
	_check(updated["created_at"] == fighter["created_at"], "Editing preserves the creation date")
	var copy := store.duplicate_fighter(id)
	_check(copy["id"] != id and copy["display_name"] == "Ruby Blue Copy", "Copy gets its own ID and name")
	copy["payload"]["color"] = "69db7c"
	store.save_fighter(copy["display_name"], copy["payload"], copy["id"])
	_check(store.get_fighter(id)["payload"]["color"] == "4dabf7", "Editing a copy leaves the source unchanged")
	_check(store.save_fighter("  ", payload).is_empty(), "Empty names are rejected")
	_check(store.get_fighter("../outside").is_empty(), "Unsafe identities cannot access another file")
	var invalid := payload.duplicate()
	invalid["weapon_id"] = "res://unapproved.tres"
	_check(store.save_fighter("Unsafe", invalid).is_empty(), "Unrecognized resource references are rejected")
	_write("broken.json", "{invalid")
	var future := fighter.duplicate(true)
	future["id"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	future["schema_version"] = 99
	_write(future["id"] + ".json", JSON.stringify(future))
	_check(store.list_fighters().size() == 2 and store.skipped_count == 2, "Corrupt and future records do not hide healthy fighters")
	_check(store.save_fighter("Future", payload, future["id"]).is_empty(), "A newer schema cannot be overwritten")
	_check(FileAccess.get_file_as_string(directory.path_join(future["id"] + ".json")) == JSON.stringify(future), "Unsupported records are preserved byte-for-byte")
	_check(store.delete_fighter(copy["id"]) and not store.get_fighter(id).is_empty(), "Deleting a copy preserves the source")
	_check(not store.delete_fighter(copy["id"]), "Deleting a missing fighter fails cleanly")
	var bad_store := LibraryStore.new(directory.path_join(id + ".json"))
	_check(bad_store.save_fighter("No room", payload).is_empty() and not bad_store.last_error.is_empty(), "Storage failure returns a useful error")
	var slot := FighterSlotConfig.new()
	slot.control_type = FighterSlotConfig.ControlType.CPU
	slot.team_id = 3
	slot.cpu_difficulty = FighterSlotConfig.CpuDifficulty.HARD
	LibraryItem.apply_to_slot(updated, slot)
	_check(slot.team_id == 3 and slot.control_type == FighterSlotConfig.ControlType.CPU and slot.cpu_difficulty == FighterSlotConfig.CpuDifficulty.HARD, "Selecting a fighter preserves team and CPU settings")
	_check(slot.fighter_color == Color("4dabf7") and slot.starting_weapon == LibraryItem.HAMMER, "Selecting a fighter restores appearance and weapon")
	slot.fighter_color = Color.WHITE
	_check(store.get_fighter(id)["payload"]["color"] == "4dabf7", "Changing a match slot cannot modify saved identity")
	await _ui_checks(store, id)
	_check(ui_completed, "UI flow reaches its end without a script error")
	# Only this run's isolated fixtures are removed.
	for filename in DirAccess.open(directory).get_files():
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Library checks complete: %d failure(s)." % failures.size())
	quit(0 if failures.is_empty() else 1)


func _ui_checks(store: LibraryStore, id: String) -> void:
	var game = load("res://main.tscn").instantiate()
	game.library_store = store
	root.add_child(game)
	await process_frame
	var open_event := InputEventKey.new()
	open_event.physical_keycode = KEY_F3
	open_event.pressed = true
	Input.parse_input_event(open_event)
	await process_frame
	open_event.pressed = false
	Input.parse_input_event(open_event)
	var panel: LibraryPanel = game.library_panel
	await process_frame
	_check(paused and panel.visible and panel.cards.get_child_count() == 1, "Library opens a visual collection and pauses the match")
	_check(get_nodes_in_group("fighters").size() == game.fighters.size(), "Previews never join combat targeting")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	_check(panel.editor.visible and panel.name_field.has_focus(), "Controller confirm opens Create Fighter and focuses its name")
	panel.request_close()
	await process_frame
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = game.library_button.get_global_rect().get_center()
	mouse.pressed = true
	root.push_input(mouse, true)
	await process_frame
	mouse.pressed = false
	root.push_input(mouse, true)
	await process_frame
	_check(panel.visible and paused, "Mouse can open the Library from its HUD button")
	panel.edit_fighter(store.get_fighter(id))
	panel.name_field.text = "Unsaved"
	panel.request_close()
	_check(panel.visible and panel.discard_dialog.visible, "Leaving an edited fighter asks before discarding changes")
	panel.discard_dialog.hide()
	panel.name_field.text = "Ruby Updated"
	panel.weapon_choice.select(0)
	panel._save()
	_check(store.get_fighter(id)["display_name"] == "Ruby Updated" and store.get_fighter(id)["payload"]["weapon_id"] == "sword", "Editor updates the saved fighter and loadout")
	game._choose_library_fighter(id, 0)
	game.setup_rows[1]["control"].select(FighterSlotConfig.ControlType.CPU)
	game.mode_selector.select(MatchManager.MatchMode.TEAM_BATTLE)
	game._apply_setup()
	await process_frame
	_check(not paused and game.fighters[0].fighter_color == Color("4dabf7"), "A saved fighter starts in a human team slot")
	_check(game.fighters[0].controller is HumanFighterController, "Saved human fighters use the existing controller")
	game._show_library()
	game._choose_library_fighter(id, 1)
	game._apply_setup()
	await process_frame
	_check(game.fighters[1].controller is CpuFighterController and game.slot_configs[1].library_fighter_id == id, "The same fighter can also join a CPU team slot")
	_check(store.get_fighter(id)["payload"].size() == 3, "Match settings never enter the saved payload")
	game._show_library()
	panel.pending_delete = id
	# Exercise cancellation first; opening the confirmation never removes the file.
	panel.delete_dialog.popup_centered()
	panel.delete_dialog.hide()
	_check(not store.get_fighter(id).is_empty(), "Cancelling deletion keeps the fighter")
	panel._delete_confirmed()
	_check(panel.cards.get_child_count() == 0, "Confirmed deletion refreshes the empty collection")
	panel.request_close()
	game._show_setup()
	game._apply_setup()
	await process_frame
	_check(game.slot_configs[0].library_fighter_id.is_empty() and game.fighters.size() == 2, "Default matches still work after deleting a selected fighter")
	game.queue_free()
	await process_frame

	ui_completed = true
