class_name LibraryStore
extends RefCounted

const DEFAULT_DIRECTORY := "user://library/items"
const MAX_RECORD_BYTES := 65536
var directory: String
var last_error := ""
var skipped_count := 0


func _init(storage_directory: String = DEFAULT_DIRECTORY) -> void:
	directory = storage_directory


func list_fighters() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	skipped_count = 0
	last_error = ""
	if not DirAccess.dir_exists_absolute(directory):
		return records
	var folder := DirAccess.open(directory)
	if folder == null:
		last_error = "Your collection could not be opened. Please try again."
		return records
	for filename in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var record := _read(directory.path_join(filename))
		if not LibraryItem.valid_record(record) or filename != str(record.get("id", "")) + ".json":
			skipped_count += 1
			continue
		records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["display_name"].naturalnocasecmp_to(b["display_name"]) < 0)
	return records


func get_fighter(id: String) -> Dictionary:
	last_error = ""
	if not LibraryItem.valid_id(id):
		last_error = "This fighter could not be found."
		return {}
	var record := _read(_path(id))
	if not LibraryItem.valid_record(record) or record["id"] != id:
		last_error = "This fighter could not be opened. Its saved file has been kept."
		return {}
	return record


func save_fighter(title: String, payload: Dictionary, id: String = "") -> Dictionary:
	last_error = ""
	title = title.strip_edges()
	if title.is_empty() or title.length() > 40 or not LibraryItem.valid_payload(payload):
		last_error = "Choose a name (1–40 letters), color and weapon before saving."
		return {}
	var record: Dictionary
	if id.is_empty():
		id = Crypto.new().generate_random_bytes(16).hex_encode()
		while FileAccess.file_exists(_path(id)):
			id = Crypto.new().generate_random_bytes(16).hex_encode()
		record = {"schema_version": LibraryItem.SCHEMA_VERSION, "id": id, "type": "fighter",
			"created_at": int(Time.get_unix_time_from_system()), "source": {"kind": "player_created"}}
	else:
		record = get_fighter(id)
		if record.is_empty():
			return {}
	record["display_name"] = title
	record["modified_at"] = int(Time.get_unix_time_from_system())
	# Explicit fighter fields keep match settings out of persistent identity.
	record["payload"] = {"character_id": payload["character_id"], "color": payload["color"], "weapon_id": payload["weapon_id"]}
	if FileAccess.file_exists(directory) or DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "There is no room to save here. Please check your storage and try again."
		return {}
	var temporary_path := _path(id) + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not save this fighter. Please check your storage and try again."
		return {}
	file.store_string(JSON.stringify(record, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary_path, _path(id)) != OK:
		last_error = "Saving did not finish. Your previous saved fighter has been kept."
		return {}
	return record.duplicate(true)


func duplicate_fighter(id: String) -> Dictionary:
	var source := get_fighter(id)
	if source.is_empty():
		return {}
	return save_fighter(str(source["display_name"]).left(35) + " Copy", source["payload"])


func delete_fighter(id: String) -> bool:
	if get_fighter(id).is_empty():
		return false
	if DirAccess.remove_absolute(_path(id)) != OK:
		last_error = "This fighter could not be deleted. Please try again."
		return false
	return true


func _path(id: String) -> String:
	return directory.path_join(id + ".json")


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_RECORD_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
