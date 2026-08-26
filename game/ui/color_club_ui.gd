class_name ColorClubUI
extends RefCounted

const BACKGROUND := Color("#F5F3FA")
const SURFACE := Color("#FFFFFF")
const SURFACE_ALT := Color("#F7F6FB")
const INK := Color("#25283D")
const MUTED := Color("#70768D")
const BORDER := Color("#E3E1EC")

const PRIMARY := Color("#6D5DE7")
const PRIMARY_HOVER := Color("#7D6FEC")
const PRIMARY_PRESSED := Color("#594BCB")

const ACCENT := Color("#E96582")
const SUCCESS := Color("#47AE9B")


static func make_box(
		background: Color,
		radius: int = 16,
		border_width: int = 0,
		border_color: Color = Color.TRANSPARENT,
		shadow_size: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()

	box.bg_color = background

	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius

	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color

	if shadow_size > 0:
		box.shadow_size = shadow_size
		box.shadow_offset = Vector2(0, maxf(2.0, shadow_size * 0.45))
		box.shadow_color = Color(0.12, 0.13, 0.22, 0.13)

	return box


static func set_padding(
		box: StyleBoxFlat,
		horizontal: float,
		vertical: float
) -> StyleBoxFlat:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	return box


static func apply_panel(
		panel: Control,
		background: Color = SURFACE,
		elevated: bool = true
) -> void:
	var style := make_box(
		background,
		22,
		1,
		BORDER,
		10 if elevated else 0
	)

	panel.add_theme_stylebox_override("panel", style)


static func apply_button(
		button: Button,
		variant: StringName = &"secondary",
		compact: bool = false
) -> void:
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat

	var font_color := INK

	match variant:
		&"primary":
			normal = make_box(PRIMARY, 14, 0, Color.TRANSPARENT, 5)
			hover = make_box(PRIMARY_HOVER, 14, 0, Color.TRANSPARENT, 7)
			pressed = make_box(PRIMARY_PRESSED, 14)
			font_color = Color.WHITE

		&"danger":
			normal = make_box(Color("#FFF1F3"), 14, 1, Color("#F6C8D0"))
			hover = make_box(Color("#FFE3E8"), 14, 1, ACCENT)
			pressed = make_box(Color("#FAD2DA"), 14, 1, ACCENT)
			font_color = Color("#A63F54")

		&"ghost":
			normal = make_box(Color(1, 1, 1, 0.0), 14)
			hover = make_box(Color(1, 1, 1, 0.7), 14, 1, BORDER)
			pressed = make_box(SURFACE_ALT, 14, 1, BORDER)

		_:
			normal = make_box(SURFACE, 14, 1, BORDER, 3)
			hover = make_box(Color("#F1EEFC"), 14, 1, PRIMARY)
			pressed = make_box(Color("#E7E2F8"), 14, 1, PRIMARY)

	var horizontal_padding := 14.0 if compact else 18.0
	var vertical_padding := 9.0 if compact else 11.0

	set_padding(normal, horizontal_padding, vertical_padding)
	set_padding(hover, horizontal_padding, vertical_padding)
	set_padding(pressed, horizontal_padding, vertical_padding)

	var focus := make_box(Color.TRANSPARENT, 15, 3, PRIMARY)
	focus.draw_center = false

	var disabled := make_box(Color("#EBEAF0"), 14, 1, BORDER)
	set_padding(disabled, horizontal_padding, vertical_padding)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", MUTED)

	button.add_theme_font_size_override("font_size", 14 if compact else 16)

	var minimum := button.custom_minimum_size
	minimum.y = maxf(minimum.y, 42.0 if compact else 48.0)
	button.custom_minimum_size = minimum

	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_input(line_edit: LineEdit) -> void:
	var normal := make_box(SURFACE, 14, 1, BORDER, 3)
	var focus := make_box(SURFACE, 14, 2, PRIMARY, 4)

	set_padding(normal, 16, 11)
	set_padding(focus, 15, 10)

	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", focus)
	line_edit.add_theme_stylebox_override(
		"read_only",
		make_box(SURFACE_ALT, 14, 1, BORDER)
	)

	line_edit.add_theme_color_override("font_color", INK)
	line_edit.add_theme_color_override("font_placeholder_color", MUTED)
	line_edit.add_theme_color_override("caret_color", PRIMARY)
	line_edit.add_theme_color_override(
		"selection_color",
		Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.25)
	)

	line_edit.add_theme_font_size_override("font_size", 16)


static func apply_level_card(button: Button) -> void:
	var normal := make_box(SURFACE, 20, 1, BORDER, 7)
	var hover := make_box(SURFACE, 20, 2, PRIMARY, 12)
	var pressed := make_box(Color("#F2EFFB"), 20, 2, PRIMARY, 4)
	var focus := make_box(Color.TRANSPARENT, 21, 3, PRIMARY)

	focus.draw_center = false

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)

	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_preview_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		make_box(SURFACE_ALT, 14, 1, BORDER)
	)
