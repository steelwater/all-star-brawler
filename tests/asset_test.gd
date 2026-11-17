extends SceneTree

var failures: Array[String] = []
var directory := "user://asset-test-" + Crypto.new().generate_random_bytes(8).hex_encode()
var capture := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture = arg.trim_prefix("--capture=")
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		failures.append(label)


func _picture(label: String) -> void:
	if capture.is_empty():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture.path_join(label + ".png"))


func _run() -> void:
	var store := LibraryStore.new(directory)
	var payload := {"character_id": "prototype_fighter", "color": "4dabf7", "weapon_id": "sword",
		"hair_id": "kenney_hair_long", "hit_sound_id": "kenney_metal_hit"}
	for id: String in AssetCatalog.ITEMS:
		var item: Dictionary = AssetCatalog.ITEMS[id]
		var pack: Dictionary = AssetCatalog.PACKS[item["pack"]]
		_check(FileAccess.get_sha256(item["resource"].resource_path) == item["sha256"], id + " matches its licensed original")
		_check(pack["license"] == "CC0-1.0" and FileAccess.file_exists(pack["license_file"]), id + " has a preserved source license")
		if item["resource"] is Texture2D:
			_check(item["resource"].get_image().detect_alpha() != Image.ALPHA_NONE, id + " preserves transparency")
		else:
			_check(item["resource"].get_length() > 0, id + " decodes as playable audio")
	for key in ["hair_id", "hit_sound_id"]:
		for invalid_value in ["res://untrusted.png", "missing", 7, null, "kenney_castle"]:
			var bad := payload.duplicate()
			bad[key] = invalid_value
			_check(store.save_fighter("Invalid", bad).is_empty(), "Invalid " + key + " choice is rejected: " + str(invalid_value))
	var saved := store.save_fighter("Kenney fighter", payload)
	var loaded := LibraryStore.new(directory).get_fighter(saved["id"])
	_check(loaded["payload"] == payload, "Hair and sound survive loading from a fresh store")
	var copy := store.duplicate_fighter(saved["id"])
	_check(copy["payload"] == payload and copy["id"] != saved["id"], "Duplicating keeps bundled choices with a new fighter identity")
	for base in [LibraryItem.SWORD, LibraryItem.HAMMER]:
		var visual = load("res://weapons/weapon.tscn").instantiate()
		root.add_child(visual)
		visual.configure(base)
		_check(is_equal_approx(visual.hit_player.volume_db, -5.0), "Original melee sound preserves -5 dB")
		var custom_payload := payload.duplicate()
		custom_payload["weapon_id"] = base.id
		visual.configure(LibraryItem.weapon_for_payload(custom_payload))
		_check(is_equal_approx(visual.hit_player.volume_db, -8.0), "Custom melee sound uses -8 dB")
		visual.configure(base)
		_check(is_equal_approx(visual.hit_player.volume_db, -5.0), "Returning to original sound restores scene volume")
		var original_thrown = load("res://weapons/thrown_weapon.tscn").instantiate()
		root.add_child(original_thrown)
		original_thrown.configure(base, null, 1.0)
		_check(is_equal_approx(original_thrown.hit_player.volume_db, -4.0), "Original thrown sound preserves -4 dB")
		original_thrown.queue_free()
		visual.queue_free()
	var original_sound := LibraryItem.SWORD.hit_sound
	var weapon := LibraryItem.weapon_for_payload(payload)
	_check(weapon.hit_sound == AssetCatalog.ITEMS["kenney_metal_hit"]["resource"] and LibraryItem.SWORD.hit_sound == original_sound, "A custom sound does not change other fighters' weapons")
	_check(weapon.damage == LibraryItem.SWORD.damage and weapon.cooldown == LibraryItem.SWORD.cooldown, "Imported content leaves combat balance unchanged")
	var game = load("res://main.tscn").instantiate()
	game.library_store = store
	root.add_child(game)
	await process_frame
	game._show_library()
	var panel: LibraryPanel = game.library_panel
	_check(panel.editor_scroll.follow_focus, "Creator follows keyboard and controller focus")
	panel._show_assets()
	_check(panel.asset_cards.get_child_count() == 7, "All seven bundled assets appear in the Library")
	await _picture("catalog")
	panel.category_choice.select(4)
	panel._refresh_assets()
	_check(panel.asset_cards.get_child_count() == 2, "Sounds category contains both auditionable impacts")
	panel.asset_search.text = "missing"
	panel._refresh_assets()
	_check(panel.asset_cards.get_child_count() == 0 and panel.message.text.begins_with("No assets"), "An empty search explains why no cards appear")
	panel.category_choice.select(0)
	panel.asset_search.text = "fighter"
	panel._refresh_assets()
	_check(panel.asset_cards.get_child_count() == 2, "Tag search finds both fighter parts")
	# Activate the real card button, not just the editor method.
	var card: VBoxContainer = panel.asset_cards.get_child(0).get_child(0)
	(card.get_child(card.get_child_count() - 1) as Button).pressed.emit()
	_check(panel.editor.visible and panel._payload().get("hair_id") == "kenney_hair_short", "A bundled card starts a fighter with its selected hair")
	panel.edit_fighter(loaded)
	panel.editor_scroll.custom_minimum_size.y = 0
	panel.editor_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.editor_scroll.custom_minimum_size.y = 200
	await process_frame
	for action in ["ui_focus_next", "ui_down"]:
		panel.name_field.grab_focus()
		for step in 18:
			var focused := root.gui_get_focus_owner()
			if focused is Button and focused.text in ["Save Fighter", "Cancel"]:
				await process_frame
				await process_frame
				_check(panel.editor_scroll.get_global_rect().encloses(focused.get_global_rect()), action + " reveals " + focused.text)
				if focused.text == "Cancel":
					break
			var event := InputEventAction.new()
			event.action = action
			event.pressed = true
			root.push_input(event)
			await process_frame
	panel.editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.editor_scroll.custom_minimum_size.y = 0
	_check(panel.preview.fighter.hair_id == payload["hair_id"], "The Creator preview shows saved imported hair")
	_check(panel.preview.fighter.weapon.definition.hit_sound == weapon.hit_sound, "The Creator preview resolves the selected hit sound")
	await _picture("creator")
	panel._select_asset(panel.hair_choice, "kenney_hair_short")
	panel._select_asset(panel.sound_choice, "kenney_wood_hit")
	panel._refresh_preview()
	panel._save()
	var edited := store.get_fighter(saved["id"])
	_check(edited["payload"]["hair_id"] == "kenney_hair_short" and edited["payload"]["hit_sound_id"] == "kenney_wood_hit", "Editing and saving replaces both imported choices")
	game._choose_library_fighter(saved["id"], 0)
	game.setup_rows[0]["control"].select(FighterSlotConfig.ControlType.CPU)
	game.setup_rows[1]["control"].select(FighterSlotConfig.ControlType.CPU)
	game._apply_setup()
	await process_frame
	var fighter: Fighter = game.fighters[0]
	_check(fighter.hair_id == "kenney_hair_short" and fighter.weapon.definition.hit_sound == AssetCatalog.ITEMS["kenney_wood_hit"]["resource"], "Creator selections enter an actual match")
	_check(game.current_stage.get_spawn_points().size() == 8, "Decorative scenery preserves all eight arena spawn points")
	paused = true
	await _picture("arena")
	fighter.is_crouching = true
	_check(fighter.hair_head_position() == Vector2(0, 8), "Hair follows the crouched head")
	fighter.kick_flash_remaining = 0.1
	fighter.facing = -1
	_check(fighter.hair_head_position() == Vector2(8, 7), "Hair follows a left-facing crouching kick")
	fighter.is_crouching = false
	_check(fighter.hair_head_position() == Vector2(18, -52), "Hair follows a left-facing standing kick")
	fighter.kick_flash_remaining = 0
	fighter.queue_redraw()
	await _picture("facing_left")
	fighter._throw_or_pickup_weapon()
	await process_frame
	var thrown = get_nodes_in_group("world_weapons")[0]
	_check(is_equal_approx(thrown.hit_player.volume_db, -8.0), "Custom thrown sound uses -8 dB")
	_check(thrown.definition.hit_sound == AssetCatalog.ITEMS["kenney_wood_hit"]["resource"], "Throwing preserves the chosen hit sound")
	thrown.pickup_delay_remaining = 0
	thrown.global_position = fighter.global_position
	fighter._throw_or_pickup_weapon()
	_check(fighter.weapon != null and fighter.weapon.definition.hit_sound == AssetCatalog.ITEMS["kenney_wood_hit"]["resource"], "Picking up restores the chosen hit sound")
	paused = false
	for id in AssetCatalog.ids_for("Sounds"):
		panel.asset_player.stream = AssetCatalog.ITEMS[id]["resource"]
		panel.asset_player.play()
		await process_frame
		_check(panel.asset_player.playing, id + " can start playback through the Library audio player")
		panel.asset_player.stop()
	# Let actual CPU combat run to victory, bounded for regression safety.
	for frame in 3600:
		if game.match_manager.completed:
			break
		await physics_frame
	_check(game.match_manager.completed, "A CPU match using imported content reaches a winner")
	game._show_library()
	panel.edit_fighter(store.get_fighter(saved["id"]))
	panel._select_asset(panel.hair_choice, "")
	panel._select_asset(panel.sound_choice, "")
	panel._save()
	_check(store.get_fighter(saved["id"])["payload"].size() == 3, "Clearing customization restores the original three-field fighter")
	panel.request_close()
	game.queue_free()
	await process_frame
	for filename in DirAccess.open(directory).get_files():
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	# Let the audio mixer retire stopped playback before the test process exits.
	OS.delay_msec(300)
	await process_frame
	print("Bundled asset checks complete: %d failure(s)." % failures.size())
	quit(0 if failures.is_empty() else 1)
