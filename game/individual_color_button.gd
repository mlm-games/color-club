@tool
class_name HudColorButton extends Button



@onready var particle_component: ParticleComponent = $ParticleComponent

var target_color: Color:
	set(value):
		target_color = value
		set_meta("target_color", value) # Store for HUD to find
		modulate = value

func _ready() -> void:
	custom_minimum_size = Vector2(50, 50)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Remove default button appearance
	flat = true
	
	# Enable custom drawing
	clip_contents = false

	
	pressed.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Click))
	mouse_entered.connect(GlobalAudioExports.I.play_ui_sound.bind(GlobalAudioExports.Sound.Hover))


var is_selected: bool = false
var hover_tween: Tween

func _draw() -> void:
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 8
	
	# Draw shadow
	draw_circle(center + Vector2(2, 3), radius + 2, Color(0, 0, 0, 0.3))
	
	# Draw main circle
	draw_circle(center, radius, target_color)
	
	# Draw inner highlight
	var highlight_color = target_color.lightened(0.3)
	highlight_color.a = 0.5
	draw_circle(center - Vector2(radius * 0.3, radius * 0.3), radius * 0.3, highlight_color)
	
	# Draw border
	var border_color = Color.WHITE if is_selected else Color(0, 0, 0, 0.2)
	var border_width = 4.0 if is_selected else 2.0
	draw_arc(center, radius, 0, TAU, 64, border_color, border_width)
	
	# If selected, draw animated ring
	if is_selected:
		var ring_color = Color("#FFE66D")
		ring_color.a = 0.6
		draw_arc(center, radius + 6, 0, TAU, 64, ring_color, 3.0)

func _on_mouse_entered() -> void:
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_QUAD)

func _on_mouse_exited() -> void:
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()
	
	if selected:
		# Pulse animation when selected
		var pulse_tween = create_tween()
		pulse_tween.set_loops(2)
		pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
		pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
