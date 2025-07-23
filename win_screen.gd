extends Control

@onready var game_over_label: Label = $MarginContainer/GameOverLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MenuButton
@onready var stats_container: VBoxContainer = %StatsContainer

var confetti_particles: Array = []

func _ready() -> void:
	%GameOverLabel.pivot_offset = size/2
	
	# Animate the win screen entrance
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Add celebration effects
	_create_confetti()
	_animate_ui_elements()
	_show_stats()

func _animate_ui_elements() -> void:
	# Animate label with bounce
	game_over_label.scale = Vector2(0.5, 0.5)
	game_over_label.modulate.a = 0.0
	
	var label_tween = create_tween()
	label_tween.parallel().tween_property(game_over_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label_tween.parallel().tween_property(game_over_label, "modulate:a", 1.0, 0.3)
	label_tween.tween_property(game_over_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BOUNCE)
	
	# Animate buttons sliding in
	var button_delay = 0.6
	for button in [continue_button, menu_button]:
		button.position.x = -200
		button.modulate.a = 0.0
		
		var button_tween = create_tween()
		button_tween.tween_interval(button_delay)
		button_tween.parallel().tween_property(button, "position:x", 456, 0.5).set_trans(Tween.TRANS_BACK)
		button_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.3)
		
		button_delay += 0.2

func _show_stats() -> void:
	if not stats_container:
		return
		
	var time_taken := GameManager.I.get_time_taken()
	var elements_colored := GameManager.I.elements_colored
	
	@warning_ignore("integer_division")
	var stats_text = "Time: %d:%02d\nShapes Colored: %d" % [int(time_taken) / 60, int(time_taken) % 60, elements_colored]
	
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 24)
	stats_label.modulate.a = 0.0
	stats_container.add_child(stats_label)
	
	var stats_tween = create_tween()
	stats_tween.tween_interval(1.0)
	stats_tween.tween_property(stats_label, "modulate:a", 1.0, 0.5)

func _create_confetti() -> void:
	# Create particle-like confetti effect
	for i in range(50):
		var confetti = ColorRect.new()
		confetti.size = Vector2(10, 15)
		confetti.color = [Color("#FF6B6B"), Color("#4ECDC4"), Color("#FFE66D"), Color("#B8BCC8")].pick_random()
		confetti.position = Vector2(randf() * get_viewport_rect().size.x, -20)
		confetti.rotation = randf() * TAU
		add_child(confetti)
		confetti_particles.append(confetti)
		
		# Animate each confetti piece
		var fall_tween = confetti.create_tween()
		fall_tween.set_loops()
		if confetti:
			fall_tween.tween_property(confetti, "position:y", get_viewport_rect().size.y + 20, randf_range(2.0, 4.0))
			fall_tween.tween_callback(func(): confetti.position.y = -20)
			
			var spin_tween = confetti.create_tween()
			spin_tween.set_loops()
			spin_tween.tween_property(confetti, "rotation", confetti.rotation + TAU, randf_range(1.0, 3.0))

func _on_continue_button_pressed() -> void:
	# Fancy exit animation
	var exit_tween = create_tween()
	
	# Stop confetti
	for confetti in confetti_particles:
		confetti.queue_free()
	
	# Zoom and fade effect
	exit_tween.parallel().tween_property(self, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_QUAD)
	exit_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	exit_tween.tween_callback(get_tree().change_scene_to_file.bind("res://main.tscn"))

func _on_menu_button_pressed() -> void:
	_on_continue_button_pressed()
