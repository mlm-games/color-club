class_name LevelCollectionResource
extends Resource

@export var levels: Dictionary[StringName, LevelData] = {}
@export var online_levels: Dictionary[StringName, LevelData] = {}

func add_online_level(id: StringName, level: LevelData) -> void:
	online_levels[id] = level
	ResourceSaver.save(self, "user://online_levels_collection.tres")

func get_all_levels() -> Dictionary:
	var all = levels.duplicate()
	all.merge(online_levels)
	return all
