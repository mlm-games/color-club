class_name LevelData
extends Resource

@export var id: StringName = ""
@export var name: String = ""
@export var svg_path: String = ""
@export var is_online: bool = false
@export var online_url: String = ""

# Don't save the content in the resource, load it when needed to prevent stutters and uneccessary rws?
var cached_svg_content: String = ""

func get_display_name() -> String:
	return name if name else id.capitalize()

func load_content() -> String:
	if cached_svg_content:
		return cached_svg_content
		
	if is_online:
		var user_path = "user://online_svgs/" + id + ".svg"
		if FileAccess.file_exists(user_path):
			var file = FileAccess.open(user_path, FileAccess.READ)
			cached_svg_content = file.get_as_text()
			file.close()
	else:
		if ResourceLoader.exists(svg_path):
			#var file = FileAccess.open(svg_path, FileAccess.READ)
			cached_svg_content = (load(svg_path) as SVGTexture).get_source()
			#file.close()
	
	return cached_svg_content
