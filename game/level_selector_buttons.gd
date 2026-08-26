class_name LevelSelectorButton
extends Button

const UI := preload("res://game/ui/color_club_ui.gd")
const ColorPicScene: PackedScene = preload("uid://bmgl20mx1bn0g")

@onready var preview: TextureRect = %Preview
@onready var preview_panel: PanelContainer = %PreviewPanel
@onready var title_label: Label = %TitleLabel
@onready var source_label: Label = %SourceLabel

var level_data: LevelData
var preview_texture: Texture2D

var _busy := false
var _hover_tween: Tween


func _ready() -> void:
	icon = null
	text = ""
	expand_icon = false

	UI.apply_level_card(self)
	UI.apply_preview_panel(preview_panel)

	title_label.add_theme_color_override("font_color", UI.INK)
	title_label.add_theme_font_size_override("font_size", 17)

	source_label.add_theme_color_override("font_color", UI.MUTED)
	source_label.add_theme_font_size_override("font_size", 12)

	pressed.connect(_on_level_selected)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_on_hover_changed.bind(true))
	focus_exited.connect(_on_hover_changed.bind(false))

	if not Engine.is_editor_hint():
		pressed.connect(
			GlobalAudioExports.I.play_ui_sound.bind(
				GlobalAudioExports.Sound.Click
			)
		)
		mouse_entered.connect(
			GlobalAudioExports.I.play_ui_sound.bind(
				GlobalAudioExports.Sound.Hover
			)
		)

	call_deferred("_refresh_pivot")

	if level_data:
		_apply_content()


func setup(
		new_level_data: LevelData,
		new_preview_texture: Texture2D
) -> void:
	level_data = new_level_data
	preview_texture = new_preview_texture

	set_meta("level_data", level_data)

	if is_node_ready():
		_apply_content()


func _apply_content() -> void:
	if not level_data:
		return

	var display_name := level_data.get_display_name()

	title_label.text = display_name
	preview.texture = preview_texture

	if level_data.is_online:
		source_label.text = "Imported SVG"
		source_label.add_theme_color_override(
			"font_color",
			UI.SUCCESS
		)
	else:
		source_label.text = "Included"
		source_label.add_theme_color_override(
			"font_color",
			UI.MUTED
		)

	tooltip_text = display_name
	accessibility_name = display_name
	accessibility_description = (
		"Open the imported coloring picture."
		if level_data.is_online
		else
		"Open this coloring picture."
	)


func matches_query(normalized_query: String) -> bool:
	if normalized_query.is_empty():
		return true

	if not level_data:
		return false

	var haystack := "%s %s %s" % [
		level_data.get_display_name().to_lower(),
		str(level_data.id).to_lower(),
		level_data.svg_path.to_lower()
	]

	return haystack.contains(normalized_query)


func set_compact_mode(compact: bool) -> void:
	if compact:
		custom_minimum_size = Vector2(148, 202)
		preview_panel.custom_minimum_size.y = 106
		title_label.custom_minimum_size.y = 36
		title_label.add_theme_font_size_override("font_size", 14)
		source_label.add_theme_font_size_override("font_size", 11)
	else:
		custom_minimum_size = Vector2(214, 252)
		preview_panel.custom_minimum_size.y = 154
		title_label.custom_minimum_size.y = 40
		title_label.add_theme_font_size_override("font_size", 17)
		source_label.add_theme_font_size_override("font_size", 12)

	call_deferred("_refresh_pivot")


func activate() -> void:
	if _busy:
		return

	_on_level_selected()


func _on_level_selected() -> void:
	if _busy:
		return

	if not level_data:
		GameManager.log_error(
			"Level button has no level data.",
			"UI"
		)
		return

	_busy = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameManager.I.current_level = level_data

	if _hover_tween:
		_hover_tween.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.tween_callback(
		get_tree().change_scene_to_packed.bind(ColorPicScene)
	)


func _on_hover_changed(hovered: bool) -> void:
	if _busy:
		return

	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_QUAD)
	_hover_tween.tween_property(
		self,
		"scale",
		Vector2(1.025, 1.025) if hovered else Vector2.ONE,
		0.16
	)


func _refresh_pivot() -> void:
	pivot_offset = size / 2.0
