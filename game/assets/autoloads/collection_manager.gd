class_name CollectionManager
extends Node

static var I: CollectionManager

const COLLECTION_PATH = "res://game/resources/level_collection.tres"
const USER_COLLECTION_PATH = "user://online_levels_collection.tres"

var collection: LevelCollectionResource
var user_collection: LevelCollectionResource

func _init() -> void:
	I = self

func _ready() -> void:
	collection = load(COLLECTION_PATH) as LevelCollectionResource
	if not collection:
		push_error("Failed to load level collection!")
		collection = LevelCollectionResource.new()
	
	if ResourceLoader.exists(USER_COLLECTION_PATH):
		user_collection = load(USER_COLLECTION_PATH) as LevelCollectionResource
	else:
		user_collection = LevelCollectionResource.new()
		
	if OS.has_feature("editor"):
		_update_collection_in_editor()

func _update_collection_in_editor() -> void:
	var svg_files = _scan_directory("res://game/assets/art", "svg")
	var updated = false
	
	for file_path in svg_files:
		var id = file_path.get_file().get_basename()
		if not id in collection.levels:
			var level = LevelData.new()
			level.id = id
			level.name = id.capitalize().replace("_", " ")
			level.svg_path = file_path
			level.is_online = false
			collection.levels[id] = level
			updated = true
	
	if updated:
		ResourceSaver.save(collection, COLLECTION_PATH)
		print("Updated level collection with %d levels" % collection.levels.size())

func _scan_directory(path: String, extension: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path + "/" + file_name
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_scan_directory(full_path, extension))
			elif file_name.ends_with("." + extension):
				files.append(full_path)
			file_name = dir.get_next()
	return files

func get_all_levels() -> Array[LevelData]:
	var all_levels: Array[LevelData] = []
	all_levels.append_array(collection.levels.values())
	all_levels.append_array(user_collection.online_levels.values())
	return all_levels

func get_level(id: StringName) -> LevelData:
	if id in collection.levels:
		return collection.levels[id]
	elif id in user_collection.online_levels:
		return user_collection.online_levels[id]
	return null

func add_online_level(url: String, svg_content: String, custom_name: String = "") -> LevelData:
	var level_id = custom_name.to_snake_case() if custom_name else url.get_file().get_basename()
	
	# Save SVG content to user directory
	var dir_path = "user://online_svgs/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + level_id + ".svg"
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(svg_content)
		file.close()
	
	var level = LevelData.new()
	level.id = level_id
	level.name = custom_name if custom_name else level_id.capitalize()
	level.svg_path = file_path
	level.is_online = true
	level.online_url = url
	
	user_collection.add_online_level(level_id, level)
	
	return level
