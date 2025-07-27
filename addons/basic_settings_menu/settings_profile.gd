class_name SettingsProfile extends Resource

#@export_group("Accessibility")
@export var accessibility: Dictionary = {
	current_locale = "en",
}
#@export_group("Gameplay")
@export var gameplay: Dictionary = {
	auto_color_strokes = false,
	color_strokes = true,
	stroke_color = Color.BLACK,
	ignore_background_parts_hack = false,
	min_shape_area_in_px = 50,
	min_shape_dimension_in_px = 5,
	max_fps = 60,
}
#@export_group("Video")
@export var video: Dictionary = {
	fullscreen = true,
	borderless = false,
	resolution = Vector2i(1920, 1080),
}
#@export_group("Audio")
@export var audio: Dictionary = {
	Master = 0.8,
	Music = 0.8,
	Sfx = 0.8,
}
