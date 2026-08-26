extends Control

const UI := preload("res://game/ui/color_club_ui.gd")
const LevelButtonsScene := preload("uid://df6stj0kgo1jl")

const CREDITS_SCENE := "uid://bq0gelfcjnqvg"
const ONLINE_DIALOG_SCENE := preload("res://game/add_online_dialog.tscn")

@onready var safe_margin: MarginContainer = %SafeMargin
@onready var header: HBoxContainer = %Header

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

@onready var library_title: Label = %LibraryTitle
@onready var library_count: Label = %LibraryCount
@onready var search_input: LineEdit = %SearchInput

@onready var gallery_panel: PanelContainer = %GalleryPanel
@onready var empty_state: Label = %EmptyState
@onready var pic_container: GridContainer = %PicContainer

@onready var surprise_button: Button = %SurpriseButton
@onready var import_button: Button = %ImportButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

var level_buttons: Array[LevelSelectorButton] = []
var _can_quit := true


func _ready() -> void:
	_can_quit = (
		not OS.has_feature("web")
		and not OS.has_feature("android")
		and not OS.has_feature("ios")
	)

	_apply_visual_style()
	_connect_signals()
	populate_pics()

	resized.connect(_refresh_responsive_layout)

	call_deferred("_refresh_responsive_layout")
	call_deferred("_animate_entrance")


func _connect_signals() -> void:
	search_input.text_changed.connect(_filter_levels)
	surprise_button.pressed.connect(_on_surprise_pressed)
	import_button.pressed.connect(_on_import_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(get_tree().quit)


func _apply_visual_style() -> void:
	UI.apply_panel(gallery_panel)

	UI.apply_button(surprise_button, &"primary")
	UI.apply_button(import_button, &"secondary")
	UI.apply_button(credits_button, &"ghost")
	UI.apply_button(quit_button, &"danger")

	UI.apply_input(search_input)

	title_label.add_theme_color_override("font_color", UI.INK)
	title_label.add_theme_font_size_override("font_size", 46)

	subtitle_label.add_theme_color_override("font_color", UI.MUTED)
	subtitle_label.add_theme_font_size_override("font_size", 17)

	library_title.add_theme_color_override("font_color", UI.INK)
	library_title.add_theme_font_size_override("font_size", 27)

	library_count.add_theme_color_override("font_color", UI.MUTED)
	library_count.add_theme_font_size_override("font_size", 14)

	empty_state.add_theme_color_override("font_color", UI.MUTED)
	empty_state.add_theme_font_size_override("font_size", 18)


func populate_pics() -> void:
	for child in pic_container.get_children():
		child.queue_free()

	level_buttons.clear()

	var all_levels = CollectionManager.I.get_all_levels()

	for level in all_levels:
		create_level_button(level)

	_filter_levels(search_input.text)
	call_deferred("_animate_cards")


func create_level_button(level: LevelData) -> void:
	var pic_button := LevelButtonsScene.instantiate() as LevelSelectorButton
	pic_container.add_child(pic_button)

	var preview_texture: Texture2D = null

	if not level.is_online:
		preview_texture = load(level.svg_path) as Texture2D
	else:
		var content: String = level.load_content()

		if not content.is_empty():
			var svg_texture := SVGTexture.new()
			svg_texture.set_source(content)
			svg_texture.base_scale = 0.5
			preview_texture = svg_texture

	pic_button.setup(level, preview_texture)
	level_buttons.append(pic_button)

	_refresh_responsive_layout()


func _filter_levels(query: String) -> void:
	var normalized_query := query.strip_edges().to_lower()
	var visible_count := 0

	for button in level_buttons:
		if not is_instance_valid(button):
			continue

		var matches := button.matches_query(normalized_query)
		button.visible = matches

		if matches:
			visible_count += 1

	empty_state.visible = visible_count == 0
	_update_library_count(visible_count)


func _update_library_count(visible_count: int) -> void:
	if search_input.text.strip_edges().is_empty():
		library_count.text = "%d pictures available" % level_buttons.size()
	else:
		library_count.text = "%d of %d pictures" % [
			visible_count,
			level_buttons.size()
		]


func _refresh_responsive_layout() -> void:
	if not is_node_ready():
		return

	var compact := size.x < 720.0

	safe_margin.add_theme_constant_override(
		"margin_left",
		14 if compact else 28
	)
	safe_margin.add_theme_constant_override(
		"margin_right",
		14 if compact else 28
	)
	safe_margin.add_theme_constant_override(
		"margin_top",
		14 if compact else 24
	)
	safe_margin.add_theme_constant_override(
		"margin_bottom",
		14 if compact else 24
	)

	title_label.add_theme_font_size_override(
		"font_size",
		34 if compact else 46
	)
	library_title.add_theme_font_size_override(
		"font_size",
		22 if compact else 27
	)

	subtitle_label.visible = not compact
	credits_button.visible = not compact
	quit_button.visible = not compact and _can_quit

	surprise_button.text = "Random" if compact else "Surprise me"
	import_button.text = "Import" if compact else "Import SVG"

	UI.apply_button(surprise_button, &"primary", compact)
	UI.apply_button(import_button, &"secondary", compact)
	UI.apply_button(credits_button, &"ghost", compact)
	UI.apply_button(quit_button, &"danger", compact)

	search_input.custom_minimum_size.x = 150.0 if compact else 260.0

	var card_width := 148.0 if compact else 214.0
	var gap := 14.0 if compact else 16.0
	var outer_space := 32.0 if compact else 96.0
	var available_width := maxf(card_width, size.x - outer_space)

	pic_container.columns = clampi(
		int(floor((available_width + gap) / (card_width + gap))),
		1,
		6
	)

	pic_container.add_theme_constant_override(
		"h_separation",
		int(gap)
	)
	pic_container.add_theme_constant_override(
		"v_separation",
		int(gap)
	)

	for button in level_buttons:
		if is_instance_valid(button):
			button.set_compact_mode(compact)


func _animate_entrance() -> void:
	header.modulate.a = 0.0
	gallery_panel.modulate.a = 0.0
	gallery_panel.scale = Vector2(0.985, 0.985)
	gallery_panel.pivot_offset = gallery_panel.size / 2.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(header, "modulate:a", 1.0, 0.32)

	tween.tween_property(
		gallery_panel,
		"modulate:a",
		1.0,
		0.32
	)
	tween.parallel().tween_property(
		gallery_panel,
		"scale",
		Vector2.ONE,
		0.38
	)


func _animate_cards() -> void:
	var index := 0

	for button in level_buttons:
		if not is_instance_valid(button):
			continue

		button.modulate.a = 0.0
		button.scale = Vector2(0.94, 0.94)

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)

		tween.tween_interval(index * 0.035)
		tween.tween_property(button, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(
			button,
			"scale",
			Vector2.ONE,
			0.28
		)

		index += 1


func _on_surprise_pressed() -> void:
	var candidates: Array[LevelSelectorButton] = []

	for button in level_buttons:
		if is_instance_valid(button) and button.visible:
			candidates.append(button)

	if candidates.is_empty():
		return

	candidates.pick_random().activate()


func _on_import_pressed() -> void:
	var dialog = ONLINE_DIALOG_SCENE.instantiate()
	add_child(dialog)

	dialog.svg_added.connect(_on_online_svg_added)

	var viewport_size := get_viewport_rect().size
	var dialog_size := Vector2i(
		maxi(320, mini(560, int(viewport_size.x) - 24)),
		maxi(360, mini(620, int(viewport_size.y) - 24))
	)

	dialog.popup_centered(dialog_size)


func _on_online_svg_added(
		url: String,
		svg_content: String,
		level_name: String
) -> void:
	var level = CollectionManager.I.add_online_level(
		url,
		svg_content,
		level_name
	)

	if not level:
		return

	create_level_button(level)
	_filter_levels(search_input.text)

	var new_button := level_buttons.back() as LevelSelectorButton

	if not new_button:
		return

	new_button.modulate.a = 0.0
	new_button.scale = Vector2(0.9, 0.9)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(
		new_button,
		"modulate:a",
		1.0,
		0.25
	)
	tween.parallel().tween_property(
		new_button,
		"scale",
		Vector2.ONE,
		0.32
	)


func _on_credits_pressed() -> void:
	STransitions.change_scene_with_transition(CREDITS_SCENE)
