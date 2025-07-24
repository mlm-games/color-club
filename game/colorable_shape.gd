# colorable_shape.gd
# This script is a component attached to a Polygon2D or Line2D
# to make it interactive for the coloring game.
class_name ColorableShape
extends Node

var original_color: Color
var is_colored: bool = false

var highlight: bool = false:
	set(value):
		if highlight != value:
			highlight = value
			get_parent().queue_redraw()

signal colored(shape_script: Node, old_color: Color, new_color: Color)

func _ready() -> void:
	var parent : CanvasItem = get_parent()
	if not parent is CanvasItem:
		push_error("ColorableShape must be a child of a CanvasItem.")
		return
		
	# Enable input processing for this node
	set_process_unhandled_input(true)
	
	# Connect to parent's draw signal to add our custom drawing
	if not parent.draw.is_connected(_on_parent_draw):
		parent.draw.connect(_on_parent_draw)

func _on_parent_draw() -> void:
	# This function is called by the parent's drawing process
	if highlight and not is_colored:
		var parent : CanvasItem = get_parent()
		var highlight_color = Color.DARK_GOLDENROD
		highlight_color.a = 0.5
		
		if parent is Polygon2D and parent.polygon.size() > 2:
			# Make sure the polygon is closed by adding the first point at the end
			var closed_polygon = parent.polygon.duplicate()
			if not closed_polygon[0].is_equal_approx(closed_polygon[-1]):
				closed_polygon.append(closed_polygon[0])
			parent.draw_polyline(closed_polygon, highlight_color, 1.0, true)
		elif parent is Line2D and parent.points.size() > 1:
			# For Line2D, check if it should be closed
			if parent.closed:
				var closed_points = parent.points.duplicate()
				if not closed_points[0].is_equal_approx(closed_points[-1]):
					closed_points.append(closed_points[0])
				parent.draw_polyline(closed_points, highlight_color)
			else:
				parent.draw_polyline(parent.points, highlight_color, parent.width + 1.0, false)
		


func _input(event: InputEvent) -> void:
	if is_colored:
		return
	
	var parent = get_parent()
	if not is_instance_valid(parent):
		return
	
	# Get the global transform of the parent to convert mouse position
	var parent_global_transform = parent.get_global_transform()
	
	# Handle mouse motion for hover highlighting
	if event is InputEventMouseMotion and HUD.selected_color.a > 0:
		var global_pos = event.position
		var local_pos = parent_global_transform.affine_inverse() * global_pos
		var is_hovering = false
		
		# Check if mouse is over this shape
		if parent is Polygon2D:
			is_hovering = Geometry2D.is_point_in_polygon(local_pos, parent.polygon)
		elif parent is Line2D:
			var threshold = parent.width / 2.0 + 5.0
			for i in range(parent.points.size() - 1):
				if Geometry2D.get_closest_point_to_segment(local_pos, parent.points[i], parent.points[i + 1]).distance_to(local_pos) < threshold:
					is_hovering = true
					break
		
		# Only highlight if this shape matches the selected color
		if is_hovering and original_color.is_equal_approx(HUD.selected_color):
			highlight = true
		else:
			highlight = false

	# Handle mouse click for coloring
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = event.position
		var local_pos = parent_global_transform.affine_inverse() * global_pos
		var click_is_inside = false
		
		# Use precise collision for polygons
		if parent is Polygon2D:
			if Geometry2D.is_point_in_polygon(local_pos, parent.polygon):
				click_is_inside = true
		# Use distance check for lines
		elif parent is Line2D:
			var threshold = parent.width / 2.0 + 5.0 # Add a 5px buffer for easier clicking
			for i in range(parent.points.size() - 1):
				if Geometry2D.get_closest_point_to_segment(local_pos, parent.points[i], parent.points[i + 1]).distance_to(local_pos) < threshold:
					click_is_inside = true
					break
		
		if click_is_inside:
			GameManager.log_info("Click detected on shape. Selected color: %s, Original color: %s" % [HUD.selected_color, original_color], "ColorableShape")
			
			if HUD.selected_color.a > 0 and original_color.is_equal_approx(HUD.selected_color):
				apply_color(HUD.selected_color)
				get_viewport().set_input_as_handled()

func set_original_color(color: Color) -> void:
	original_color = color
	var parent = get_parent()
	if parent and parent.modulate.a < 1.0:
		original_color.a *= parent.modulate.a
	revert_to_uncolored()

func apply_color(new_color: Color) -> void:
	var parent = get_parent()
	
	new_color.a = original_color.a
	
	if parent is Polygon2D:
		parent.color = new_color
	elif parent is Line2D:
		parent.default_color = new_color
	
	is_colored = true
	highlight = false
	colored.emit(self, original_color, new_color)
	GameManager.I.register_element_colored()

func revert_to_uncolored() -> void:
	var parent = get_parent()
	var uncolored = Color.WHITE
	uncolored.a = original_color.a
	
	if parent is Polygon2D:
		parent.color = uncolored
	elif parent is Line2D:
		parent.default_color = uncolored

	is_colored = false
	parent.queue_redraw()
