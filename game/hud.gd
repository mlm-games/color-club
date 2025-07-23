class_name HUD
extends Control

static var I: HUD

func _init() -> void:
	I = self

const ColorButtonScene = preload("uid://dhpkpl2gdud8q")
const WinScreenScene = preload("uid://cevc21alsw44h")

@onready var color_container: HBoxContainer = %ColorContainer
@onready var progress_bar: ProgressBar = %CompletionProgressBar
@onready var color_palette_panel: PanelContainer = %ColorPalettePanel
@onready var back_button: Button = %BackButton
@onready var progress_label: Label = %ProgressLabel
@onready var svg_image: SVGImage = get_node("../SVGImage")


var color_registry: Dictionary = {}
var current_selected_button: Button = null

static var selected_color: Color = Color.TRANSPARENT:
	set(value):
		if selected_color != value:
			selected_color = value
			HUD.I._on_color_selected(value)

func _ready() -> void:
	svg_image.svg_loaded.connect(_on_svg_loaded)
	
	GameManager.I.progress_updated.connect(_on_progress_updated)
	
	# Animate HUD entrance
	_animate_hud_entrance()

func register_colored_shape(shape_script: Node, old_color: Color, _new_color: Color) -> void:
	if old_color in color_registry:
		color_registry[old_color].erase(shape_script)
		if color_registry[old_color].is_empty():
			# This color is now complete
			color_registry.erase(old_color)
			_remove_color_button(old_color)
			GameManager.I.register_color_completed()
			
			if selected_color.is_equal_approx(old_color):
				selected_color = Color.TRANSPARENT
				if current_selected_button:
					current_selected_button.set_selected(false)
					current_selected_button = null

func get_total_colorable_elements() -> int:
	var count = 0
	for color in color_registry:
		count += color_registry[color].size()
	return count

func get_remaining_colors() -> int:
	return color_registry.size()

func show_win_screen() -> void:
	# Fancy transition to win screen
	var transition_tween = create_tween()
	
	# Create a white flash effect
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	transition_tween.tween_property(flash, "modulate:a", 0.8, 0.3)
	transition_tween.tween_callback(get_tree().change_scene_to_packed.bind(WinScreenScene))
	transition_tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	transition_tween.tween_callback(flash.queue_free)

func _animate_hud_entrance() -> void:
	# Animate progress bar sliding in from top
	progress_bar.position.y = -50
	var progress_tween = create_tween()
	progress_tween.tween_property(progress_bar, "position:y", 10, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animate color palette sliding in from bottom
	var original_y = color_palette_panel.position.y
	color_palette_panel.position.y = get_viewport_rect().size.y + 100
	progress_tween.tween_property(color_palette_panel, "position:y", original_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# And animate the svg node popping in
	
	#svg_image.scale = Vector2.ZERO
	svg_image.modulate = Color.TRANSPARENT
	#svg_image.pivot_offset = size / 2

	progress_tween.tween_property(svg_image, "modulate", Color.WHITE, 0.4)

func _on_progress_updated(progress: float) -> void:
	Juice.set_tweened_value(progress_bar, "value", progress * 100, 0.3)
	
	# Update progress label with percentage
	if progress_label:
		progress_label.text = "%d%%" % int(progress * 100)
	
	# Celebration effect at milestones
	if int(progress * 100) % 25 == 0 and progress > 0:
		_play_milestone_effect()

func _play_milestone_effect() -> void:
	# Create a burst effect
	var burst_tween = create_tween()
	burst_tween.tween_property(progress_bar, "scale", Vector2(1.05, 1.2), 0.2).set_trans(Tween.TRANS_QUAD)
	burst_tween.tween_property(progress_bar, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)

func _on_svg_loaded(registry: Dictionary) -> void:
	color_registry = registry
	_update_color_buttons()

	for color in color_registry:
		for shape_script in color_registry[color]:
			if not shape_script.colored.is_connected(register_colored_shape):
				shape_script.colored.connect(register_colored_shape)
				
	#HACK: Should probably fix this later
	GameManager.I.start_game()

func _update_color_buttons() -> void:
	for child in color_container.get_children():
		child.queue_free()
	
	# Add some spacing at the start
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	color_container.add_child(spacer)
	
	var sorted_colors = color_registry.keys()
	sorted_colors.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())

	var delay = 0.0
	for color in sorted_colors:
		var button = ColorButtonScene.instantiate()
		button.target_color = color
		button.modulate.a = 0.0
		color_container.add_child(button)
		button.pressed.connect(_on_color_button_pressed.bind(color, button))
		
		# Animate button appearance
		var appear_tween = create_tween()
		appear_tween.tween_interval(delay)
		appear_tween.tween_property(button, "modulate:a", 1.0, 0.3)
		appear_tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.3).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK)
		delay += 0.05
	
	# Add end spacer
	var end_spacer = Control.new()
	end_spacer.custom_minimum_size.x = 10
	color_container.add_child(end_spacer)

func _on_color_selected(color: Color) -> void:
	_clear_all_highlights()
	
	if color in color_registry:
		for shape_script in color_registry[color]:
			if is_instance_valid(shape_script):
				shape_script.highlight = true

func _on_color_button_pressed(color: Color, button: Button) -> void:
	# Deselect previous button
	if current_selected_button and current_selected_button.has_method("set_selected"):
		current_selected_button.set_selected(false)
	
	current_selected_button = button
	if button.has_method("set_selected"):
		button.set_selected(true)
	
	selected_color = color
	
	button.particle_component.emit_selection_particles(color)
	
	# Visual feedback
	var feedback_tween = create_tween()
	feedback_tween.tween_property(progress_bar, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	feedback_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.1)

func _clear_all_highlights() -> void:
	for color in color_registry:
		for shape_script in color_registry[color]:
			if is_instance_valid(shape_script):
				shape_script.highlight = false

func _remove_color_button(color: Color) -> void:
	for child in color_container.get_children():
		if child is Button and child.has_meta("target_color") and child.get_meta("target_color").is_equal_approx(color):
			# Animate removal
			var remove_tween = create_tween()
			remove_tween.parallel().tween_property(child, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK)
			remove_tween.parallel().tween_property(child, "modulate:a", 0.0, 0.2)
			remove_tween.tween_callback(child.queue_free)
			break
