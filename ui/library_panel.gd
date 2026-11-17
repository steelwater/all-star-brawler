class_name LibraryPanel
extends PanelContainer

signal closed
signal fighter_selected(id: String, slot_index: int)
signal collection_changed

var store: LibraryStore
var content: VBoxContainer
var browse: VBoxContainer
var cards: GridContainer
var editor: VBoxContainer
var editor_scroll: ScrollContainer
var message: Label
var name_field: LineEdit
var color_choice: OptionButton
var weapon_choice: OptionButton
var hair_choice: OptionButton
var sound_choice: OptionButton
var bundled: VBoxContainer
var asset_cards: GridContainer
var category_choice: OptionButton
var asset_search: LineEdit
var asset_player: AudioStreamPlayer
var preview: FighterPreview
var slot_choice: OptionButton
var editing_id := ""
var original_name := ""
var original_payload: Dictionary = {}
var colors: Array[String] = ["4dabf7", "ff6b6b", "69db7c", "ffd43b", "b197fc", "ff922b", "38d9a9", "f06595"]
var delete_dialog: ConfirmationDialog
var discard_dialog: ConfirmationDialog
var pending_delete := ""
var leave_after_discard := false
var new_button: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _ready() -> void:
	# This engine's built-in UI actions contain keyboard keys only.
	var buttons := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
		"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("182332")
	background.border_color = Color("435a75")
	background.set_border_width_all(2)
	background.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", background)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 45
	offset_top = 24
	offset_right = -45
	offset_bottom = -24
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := Label.new()
	title.text = "LIBRARY"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "Back", func() -> void: request_close())
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	browse = VBoxContainer.new()
	browse.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(browse)
	var actions := HBoxContainer.new()
	browse.add_child(actions)
	new_button = _button(actions, "Create Fighter", func() -> void: edit_fighter({}))
	_button(actions, "Bundled Assets", _show_assets)
	var slot_label := Label.new()
	slot_label.text = "Use in match as"
	actions.add_child(slot_label)
	slot_choice = OptionButton.new()
	for index in 8:
		slot_choice.add_item("Fighter %d" % (index + 1))
	actions.add_child(slot_choice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browse.add_child(scroll)
	cards = GridContainer.new()
	cards.columns = 4
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 14)
	scroll.add_child(cards)
	scroll.resized.connect(func() -> void: cards.columns = maxi(1, int(scroll.size.x / 265.0)))
	_build_editor()
	_build_assets()
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete fighter?"
	delete_dialog.ok_button_text = "Delete"
	delete_dialog.confirmed.connect(_delete_confirmed)
	add_child(delete_dialog)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Leave without saving?"
	discard_dialog.dialog_text = "Your latest changes have not been saved."
	discard_dialog.ok_button_text = "Discard changes"
	discard_dialog.confirmed.connect(func() -> void:
		if leave_after_discard:
			_finish_close()
		else:
			_show_collection())
	add_child(discard_dialog)
	hide()


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _build_editor() -> void:
	editor_scroll = ScrollContainer.new()
	editor_scroll.follow_focus = true
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(editor_scroll)
	editor = VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 10)
	editor_scroll.add_child(editor)
	preview = FighterPreview.new()
	preview.stretch = false
	editor.add_child(preview)
	var label := Label.new()
	label.text = "Name your fighter"
	editor.add_child(label)
	name_field = LineEdit.new()
	name_field.max_length = 40
	name_field.placeholder_text = "Fighter name"
	name_field.custom_minimum_size.y = 40
	editor.add_child(name_field)
	color_choice = OptionButton.new()
	var names := ["Blue", "Red", "Green", "Yellow", "Purple", "Orange", "Teal", "Pink"]
	for index in colors.size():
		color_choice.add_item(names[index])
	color_choice.custom_minimum_size.y = 40
	editor.add_child(color_choice)
	weapon_choice = OptionButton.new()
	weapon_choice.add_item("Sword")
	weapon_choice.add_item("Hammer")
	weapon_choice.custom_minimum_size.y = 40
	editor.add_child(weapon_choice)
	hair_choice = _asset_choice("Hair", "Fighter Parts", "None")
	sound_choice = _asset_choice("Hit sound", "Sounds", "Original weapon sound")
	color_choice.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	weapon_choice.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	var actions := HBoxContainer.new()
	editor.add_child(actions)
	_button(actions, "Save Fighter", _save)
	_button(actions, "Cancel", func() -> void: _leave_editor(false))


func open() -> void:
	show()
	_show_collection()


func _show_collection() -> void:
	editor.hide()
	editor_scroll.hide()
	bundled.hide()
	asset_player.stop()
	browse.show()
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var records := store.list_fighters()
	message.text = "Create a fighter, keep it here, then take it into battle!" if records.is_empty() else "Choose a fighter for your next battle."
	if not store.last_error.is_empty():
		message.text = store.last_error
	elif store.skipped_count > 0:
		message.text = "Some saved items could not be opened. They have been kept safely."
	for record in records:
		var frame := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("253549")
		card_style.set_corner_radius_all(8)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 10
		frame.add_theme_stylebox_override("panel", card_style)
		cards.add_child(frame)
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 225
		frame.add_child(card)
		var thumbnail := FighterPreview.new()
		card.add_child(thumbnail)
		thumbnail.show_payload(record["payload"])
		var title := Label.new()
		title.text = record["display_name"]
		title.custom_minimum_size.x = 225
		title.clip_text = true
		title.tooltip_text = title.text
		card.add_child(title)
		_button(card, "Use Fighter", func() -> void:
			fighter_selected.emit(record["id"], slot_choice.selected))
		var actions := HBoxContainer.new()
		card.add_child(actions)
		_button(actions, "Edit", func() -> void: edit_fighter(record))
		_button(actions, "Copy", func() -> void:
			var copy := store.duplicate_fighter(record["id"])
			if copy.is_empty():
				message.text = store.last_error
			else:
				collection_changed.emit()
				_show_collection())
		_button(actions, "Delete", func() -> void:
			pending_delete = record["id"]
			delete_dialog.dialog_text = 'Delete "%s"? This cannot be undone.' % record["display_name"]
			delete_dialog.popup_centered()
			delete_dialog.get_cancel_button().grab_focus())
	new_button.grab_focus()


func edit_fighter(record: Dictionary) -> void:
	editing_id = record.get("id", "")
	original_name = record.get("display_name", "")
	original_payload = record.get("payload", {"character_id": "prototype_fighter", "color": colors[0], "weapon_id": "sword"}).duplicate(true)
	name_field.text = original_name
	var color: String = original_payload["color"]
	if not color in colors:
		colors.append(color)
		color_choice.add_item("Saved color")
	color_choice.select(colors.find(color))
	weapon_choice.select(0 if original_payload["weapon_id"] == "sword" else 1)
	browse.hide()
	bundled.hide()
	asset_player.stop()
	_select_asset(hair_choice, original_payload.get("hair_id", ""))
	_select_asset(sound_choice, original_payload.get("hit_sound_id", ""))
	editor.show()
	editor_scroll.show()
	editor_scroll.scroll_vertical = 0
	message.text = "Make this fighter yours."
	_refresh_preview()
	name_field.grab_focus()


func _payload() -> Dictionary:
	var result := {"character_id": "prototype_fighter", "color": colors[color_choice.selected],
		"weapon_id": "sword" if weapon_choice.selected == 0 else "hammer"}
	for pair in [["hair_id", hair_choice], ["hit_sound_id", sound_choice]]:
		var id: String = pair[1].get_item_metadata(pair[1].selected)
		if not id.is_empty():
			result[pair[0]] = id
	return result


func _refresh_preview() -> void:
	preview.show_payload(_payload())


func _save() -> void:
	var saved := store.save_fighter(name_field.text, _payload(), editing_id)
	if saved.is_empty():
		message.text = store.last_error
		return
	collection_changed.emit()
	_show_collection()
	message.text = 'Saved "%s"!' % saved["display_name"]


func _delete_confirmed() -> void:
	if not store.delete_fighter(pending_delete):
		message.text = store.last_error
		return
	collection_changed.emit()
	_show_collection()


func _leave_editor(close_library: bool) -> void:
	if editor.visible and (name_field.text != original_name or _payload() != original_payload):
		leave_after_discard = close_library
		discard_dialog.popup_centered()
		discard_dialog.get_cancel_button().grab_focus()
	elif close_library:
		_finish_close()
	else:
		_show_collection()


func request_close() -> void:
	_leave_editor(true)


func _finish_close() -> void:
	asset_player.stop()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()


func _asset_choice(label_text: String, category: String, default_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	editor.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 90
	row.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 38
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.add_item(default_text)
	choice.set_item_metadata(0, "")
	for id in AssetCatalog.ids_for(category):
		choice.add_item(AssetCatalog.ITEMS[id]["display_name"] + " · Kenney")
		choice.set_item_metadata(choice.item_count - 1, id)
	row.add_child(choice)
	choice.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	if category == "Sounds":
		_button(row, "Listen", func() -> void:
			asset_player.stream = LibraryItem.weapon_for_payload(_payload()).hit_sound
			asset_player.play())
	return choice


func _select_asset(choice: OptionButton, id: String) -> void:
	for index in choice.item_count:
		if choice.get_item_metadata(index) == id:
			choice.select(index)
			return


func _build_assets() -> void:
	asset_player = AudioStreamPlayer.new()
	asset_player.volume_db = -12.0
	add_child(asset_player)
	bundled = VBoxContainer.new()
	bundled.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bundled)
	bundled.hide()
	var filters := HBoxContainer.new()
	bundled.add_child(filters)
	_button(filters, "Fighters", _show_collection)
	category_choice = OptionButton.new()
	for category in ["All categories", "Fighter Parts", "Stage Objects", "Backgrounds", "Sounds"]:
		category_choice.add_item(category)
	filters.add_child(category_choice)
	category_choice.item_selected.connect(func(_index: int) -> void: _refresh_assets())
	asset_search = LineEdit.new()
	asset_search.placeholder_text = "Search names or tags"
	asset_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(asset_search)
	asset_search.text_changed.connect(func(_text: String) -> void: _refresh_assets())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bundled.add_child(scroll)
	asset_cards = GridContainer.new()
	asset_cards.columns = 3
	asset_cards.add_theme_constant_override("h_separation", 12)
	asset_cards.add_theme_constant_override("v_separation", 12)
	scroll.add_child(asset_cards)
	scroll.resized.connect(func() -> void: asset_cards.columns = maxi(1, int(scroll.size.x / 277.0)))


func _show_assets() -> void:
	browse.hide()
	editor.hide()
	editor_scroll.hide()
	bundled.show()
	_refresh_assets()
	category_choice.grab_focus()


func _refresh_assets() -> void:
	asset_player.stop()
	for child in asset_cards.get_children():
		asset_cards.remove_child(child)
		child.queue_free()
	for id: String in AssetCatalog.ITEMS:
		var item: Dictionary = AssetCatalog.ITEMS[id]
		if category_choice.selected > 0 and item["category"] != category_choice.get_item_text(category_choice.selected):
			continue
		var search_text: String = item["display_name"] + " " + " ".join(item["tags"])
		if not asset_search.text.strip_edges().is_empty() and not search_text.to_lower().contains(asset_search.text.strip_edges().to_lower()):
			continue
		var frame := PanelContainer.new()
		frame.custom_minimum_size.x = 265
		asset_cards.add_child(frame)
		var card := VBoxContainer.new()
		frame.add_child(card)
		if item["resource"] is Texture2D:
			var picture := TextureRect.new()
			picture.texture = item["resource"]
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = Vector2(240, 100)
			card.add_child(picture)
		var label := Label.new()
		label.text = item["display_name"] + "\n" + item["category"] + " · Kenney · CC0"
		label.tooltip_text = AssetCatalog.PACKS[item["pack"]]["source"] + "\n" + ", ".join(item["tags"])
		card.add_child(label)
		if item["category"] == "Sounds":
			_button(card, "Listen", func() -> void:
				asset_player.stream = item["resource"]
				asset_player.play())
		if item["category"] in ["Fighter Parts", "Sounds"]:
			_button(card, "Create Fighter with this", func() -> void:
				edit_fighter({})
				_select_asset(hair_choice if item["category"] == "Fighter Parts" else sound_choice, id)
				_refresh_preview())
		else:
			var note := Label.new()
			note.text = "Used in Arena scenery"
			card.add_child(note)
	message.text = "Bundled assets — use them in your creations." if asset_cards.get_child_count() > 0 else "No assets match these filters."
