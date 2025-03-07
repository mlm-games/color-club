@tool  # Allows the node to work in the editor
class_name SVGCircle
extends SVGBase

var highlighted : bool = false

# SVG Properties
@export var radius: float = 10.0:
	set(value):
		radius = value
		queue_redraw()

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()

@export var stroke_color: Color = Color.BLACK:
	set(value):
		stroke_color = value
		queue_redraw()

@export var stroke_width: float = 0.0:
	set(value):
		stroke_width = value/2
		#TODO: fix to put value instead of value/2
		queue_redraw()

@export var opacity: float = 1.0:
	set(value):
		opacity = value
		modulate.a = value

func _ready() -> void:
	gui_input.connect(_on_input_received.bind())
	_update_control_size()
	#HACK: To center it
	position -= custom_minimum_size/2

# Optional: Helper method to set all properties at once
func set_circle_properties(attributes: Dictionary) -> void:
	if "cx" in attributes:
		position.x = float(attributes["cx"])
	if "cy" in attributes:
		position.y = float(attributes["cy"])
	if "r" in attributes:
		radius = float(attributes["r"])
	if "fill" in attributes:
		fill_color = Color.html(attributes["fill"])
	if "stroke" in attributes:
		stroke_color = Color.html(attributes["stroke"])
	if "stroke-width" in attributes:
		stroke_width = float(attributes["stroke-width"])
	if "opacity" in attributes:
		opacity = float(attributes["opacity"])
	if "id" in attributes:
		name = attributes["id"]
	if "style" in attributes:
		SVGUtils.apply_css_styles_for_shape(SVGUtils.analyse_style(attributes["style"]), self)
	
	queue_redraw()


func _update_control_size() -> void:
		# Set the control size to match the circle (plus stroke)
		var total_radius := radius + stroke_width
		custom_minimum_size = Vector2(total_radius * 2, total_radius * 2)
		# Center the pivot
		pivot_offset = custom_minimum_size / 2


func _draw() -> void:
	# Draw fill if color has any opacity
	if fill_color.a > 0:
		draw_circle(custom_minimum_size/2, radius, fill_color)
	
	# Draw stroke if width is greater than 0
	if stroke_width > 0:
		# Use 32 points for smooth circle approximation
		# TAU is equivalent to 2*PI
		draw_arc(
			custom_minimum_size/2,  # Center point
			radius,        # Radius
			0,            # Start angle
			TAU,          # End angle (full circle)
			32,           # Number of points
			stroke_color, # Stroke color
			stroke_width, # Line width
			true         # Antialiasing
		)
	
	

@onready var hud : HUD = get_tree().get_first_node_in_group("HUD")
@onready var original_scale := scale
var hover_scale : Vector2 = Vector2(1.05, 1.05)
func _on_input_received(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		
		var center := custom_minimum_size / 2
		var click_pos : Vector2 = event.position
		var distance := click_pos.distance_to(center)
				
		if distance <= radius:
			var click_tween : Tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_ignore_time_scale()
			click_tween.tween_property(self, "scale", original_scale * 0.95, 0.1)
			click_tween.tween_property(self, "scale", hover_scale, 0.1)
			click_tween.tween_property(self, "scale", original_scale, 0.1)
			
			# FIXME: Play click sound
			#Sound.play_sfx("click")
			
			if highlighted:
				fill_color = hud.selected_color
				highlighted = false
				hud.colors_for_image[hud.selected_color].erase(self)
				hud.remove_color_and_its_button_if_empty()
			
			queue_redraw()
