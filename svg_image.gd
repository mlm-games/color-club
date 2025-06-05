@tool
class_name SVGImage
extends Panel

# Configuration
const DEFAULT_SVG_SIZE = 400
const DEBUG_WARNINGS = true

# SVG document properties
var svg_width: float = 100.0
var svg_height: float = 100.0
var viewbox: Rect2 = Rect2()
var svg_root: Control
var svg_scale_factor: float = 1.0

# Color management
var color_registry: Dictionary = {}  # Color -> Array[SVGElement]

signal svg_loaded(colors: Dictionary)
signal element_clicked(element: SVGElement)

func _ready() -> void:
	if HUD.selected_svg_path.is_empty():
		push_error("No SVG path selected")
		return
	
	# Connect element clicked signal
	connect("element_clicked", _on_element_clicked)
	
	load_svg(HUD.selected_svg_path)

func load_svg(file_path: String) -> bool:
	var parser = XMLParser.new()
	var error = parser.open(file_path)
	
	if error != OK:
		push_error("Failed to open SVG file: " + file_path)
		return false
	
	# Clear previous content
	_clear_svg_content()
	
	# Create root container
	svg_root = Control.new()
	svg_root.name = "SVGRoot"
	svg_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(svg_root)
	
	# Parse the SVG
	var success = _parse_svg_document(parser)
	
	if success:
		_finalize_svg_layout()
		_extract_colors()
		svg_loaded.emit(color_registry)
	
	return success

func _clear_svg_content() -> void:
	if svg_root:
		svg_root.queue_free()
	color_registry.clear()

func _parse_svg_document(parser: XMLParser) -> bool:
	var element_stack: Array[Control] = [svg_root]
	var transform_stack: Array[Transform2D] = [Transform2D.IDENTITY]
	var svg_found = false
	
	while parser.read() != ERR_FILE_EOF:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag_name = parser.get_node_name()
				var attributes = _extract_attributes(parser)
				
				if tag_name == "svg" and not svg_found:
					_parse_svg_root(attributes)
					svg_found = true
				elif tag_name == "g":
					var group = _create_group(attributes, transform_stack.back())
					element_stack.back().add_child(group)
					element_stack.push_back(group)
					
					# Update transform stack
					var group_transform = transform_stack.back()
					if group.has_transform:
						group_transform = group_transform * group.svg_transform
					transform_stack.push_back(group_transform)
				else:
					var element = SVGUtils.create_svg_element(tag_name, attributes)
					if element:
						# Apply accumulated transform
						if transform_stack.back() != Transform2D.IDENTITY:
							element.has_transform = true
							element.svg_transform = transform_stack.back() * element.svg_transform
						
						element_stack.back().add_child(element)
						_setup_element_interaction(element)
						
						# Apply transform after adding to tree
						element.apply_svg_transform()
			
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "g" and element_stack.size() > 1:
					element_stack.pop_back()
					transform_stack.pop_back()
	
	return svg_found

func _extract_attributes(parser: XMLParser) -> Dictionary:
	var attributes = {}
	for i in range(parser.get_attribute_count()):
		attributes[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
	return attributes

func _parse_svg_root(attributes: Dictionary) -> void:
	# Parse dimensions
	if "width" in attributes:
		svg_width = SVGUtils.parse_dimension(attributes["width"])
	if "height" in attributes:
		svg_height = SVGUtils.parse_dimension(attributes["height"])
	
	# Parse viewBox
	if "viewBox" in attributes:
		var parts = attributes["viewBox"].split(" ")
		if parts.size() >= 4:
			viewbox = Rect2(
				float(parts[0]), float(parts[1]),
				float(parts[2]), float(parts[3])
			)
			# Use viewBox dimensions if no explicit width/height
			if not "width" in attributes and not "height" in attributes:
				svg_width = viewbox.size.x
				svg_height = viewbox.size.y

func _create_group(attributes: Dictionary, parent_transform: Transform2D) -> SVGGroup:
	var group = SVGGroup.new()
	group.set_accumulated_transform(parent_transform)
	group.set_group_attributes(attributes)
	return group

func _setup_element_interaction(element: SVGElement) -> void:
	# Ensure the element can receive input
	element.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect through the parent signal system
	element.gui_input.connect(_on_element_gui_input.bind(element))

func _on_element_gui_input(event: InputEvent, element: SVGElement) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if element._has_point(mouse_event.position):
				element_clicked.emit(element)

func _on_element_clicked(element: SVGElement) -> void:
	_handle_element_click(element)

func _handle_element_click(element: SVGElement) -> void:
	# Color the element if a color is selected
	if HUD.selected_color != Color.TRANSPARENT and HUD.selected_color != Color.WHITE:
		_color_element(element, HUD.selected_color)

func _color_element(element: SVGElement, color: Color) -> void:
	var old_color = element.fill_color
	element.fill_color = color
	
	# Update color registry
	if old_color in color_registry:
		color_registry[old_color].erase(element)
		if color_registry[old_color].is_empty():
			color_registry.erase(old_color)
			HUD.remove_color_if_empty(old_color)
	
	if not color in color_registry:
		color_registry[color] = []
	color_registry[color].append(element)
	
	# Notify game manager
	if GameManager.instance:
		GameManager.instance.on_element_colored()

func _finalize_svg_layout() -> void:
	# Calculate scale to fit the panel
	var panel_size = size
	if panel_size.x <= 0 or panel_size.y <= 0:
		panel_size = Vector2(DEFAULT_SVG_SIZE, DEFAULT_SVG_SIZE)
	
	# Account for viewBox if present
	var effective_width = svg_width
	var effective_height = svg_height
	if viewbox != Rect2():
		effective_width = viewbox.size.x
		effective_height = viewbox.size.y
	
	svg_scale_factor = min(
		panel_size.x / effective_width,
		panel_size.y / effective_height
	) * 0.9  # Leave some margin
	
	svg_root.scale = Vector2(svg_scale_factor, svg_scale_factor)
	
	# Center the SVG
	var scaled_size = Vector2(effective_width, effective_height) * svg_scale_factor
	svg_root.position = (panel_size - scaled_size) * 0.5
	
	# Apply viewBox offset if needed
	if viewbox != Rect2():
		# Create a transform for the viewBox
		var viewbox_transform = Transform2D.IDENTITY
		viewbox_transform.origin = -viewbox.position
		
		# Apply to all direct children of svg_root
		for child in svg_root.get_children():
			if child is SVGElement:
				child.position -= viewbox.position * svg_scale_factor
			elif child is SVGGroup:
				child.position -= viewbox.position * svg_scale_factor

func _extract_colors() -> void:
	color_registry.clear()
	_collect_colors_recursive(svg_root)

func _collect_colors_recursive(node: Node) -> void:
	if node is SVGElement:
		var element = node as SVGElement
		var color = element.fill_color
		
		if color != Color.TRANSPARENT and color != Color.WHITE:
			if not color in color_registry:
				color_registry[color] = []
			color_registry[color].append(element)
			
			# Set to white for coloring game
			element.fill_color = Color.WHITE
	
	for child in node.get_children():
		_collect_colors_recursive(child)
