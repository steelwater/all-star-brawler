class_name LibraryItem
extends RefCounted

const SCHEMA_VERSION := 1
const SWORD: WeaponDefinition = preload("res://weapons/sword.tres")
const HAMMER: WeaponDefinition = preload("res://weapons/hammer.tres")

# Only approved built-in identities are resolved; saved files never load resource paths.
static func weapon_for(id: String) -> WeaponDefinition:
	return SWORD if id == "sword" else HAMMER


static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() != 32:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func valid_payload(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("character_id") != "prototype_fighter" or not value.get("weapon_id") in ["sword", "hammer"]:
		return false
	var color: Variant = value.get("color")
	if not color is String or color.length() != 6:
		return false
	for character in color:
		if not character in "0123456789abcdef":
			return false
	return true


static func valid_record(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.get("schema_version") != SCHEMA_VERSION or value.get("type") != "fighter":
		return false
	if not valid_id(value.get("id")) or not valid_payload(value.get("payload")):
		return false
	var title: Variant = value.get("display_name")
	if not title is String or title.strip_edges().is_empty() or title.length() > 40:
		return false
	for key in ["created_at", "modified_at"]:
		var timestamp: Variant = value.get(key)
		if not (timestamp is float or timestamp is int) or not is_finite(float(timestamp)) or timestamp < 0:
			return false
	return value.get("source") is Dictionary


static func apply_to_slot(record: Dictionary, slot: FighterSlotConfig) -> void:
	# Match ownership, controller, difficulty, spawn and team remain untouched.
	var payload: Dictionary = record["payload"]
	slot.library_fighter_id = record["id"]
	slot.character_id = StringName(payload["character_id"])
	slot.fighter_color = Color(payload["color"])
	slot.starting_weapon = weapon_for(payload["weapon_id"])
