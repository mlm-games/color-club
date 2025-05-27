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

# Color management
var color_registry: Dictionary = {}  # Color -> Array[SVGElement]

signal svg_loaded(colors: Dictionary)
signal element_clicked(element: SVGElement)

func _ready() -> void:
	if HUD.selected_svg_path.is_empty():
		push_error("No SVG path selected")
		return
	
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
					var group = _create_group(attributes)
					element_stack.back().add_child(group)
					element_stack.push_back(group)
				else:
					var element = SVGUtils.create_svg_element(tag_name, attributes)
					if element:
						element_stack.back().add_child(element)
						_setup_element_interaction(element)
			
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "g" and element_stack.size() > 1:
					element_stack.pop_back()
	
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
			if svg_width == 100.0 and svg_height == 100.0:
				svg_width = viewbox.size.x
				svg_height = viewbox.size.y

func _create_group(attributes: Dictionary) -> SVGGroup:
	var group = SVGGroup.new()
	group.set_group_attributes(attributes)
	return group

func _setup_element_interaction(element: SVGElement) -> void:
	# Make sure the element can receive input
	element.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect the element's input signal
	if not element.gui_input.is_connected(_on_element_input):
		element.gui_input.connect(_on_element_input.bind(element))

func _on_element_input(event: InputEvent, element: SVGElement) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			print("Element clicked: ", element.name, " at position: ", mouse_event.position)
			element_clicked.emit(element)
			_handle_element_click(element)

func _handle_element_click(element: SVGElement) -> void:
	print("Handling click for element: ", element.name)
	print("Current fill color: ", element.fill_color)
	print("Selected color: ", HUD.selected_color)
	
	# Color the element if a color is selected
	if HUD.selected_color != Color.TRANSPARENT and HUD.selected_color != Color.WHITE:
		print("Coloring element with: ", HUD.selected_color)
		_color_element(element, HUD.selected_color)
	else:
		print("No valid color selected")

func _color_element(element: SVGElement, color: Color) -> void:
	var old_color = element.fill_color
	print("Changing color from ", old_color, " to ", color)
	
	element.fill_color = color
	
	# Update color registry
	if old_color in color_registry:
		color_registry[old_color].erase(element)
		if color_registry[old_color].is_empty():
			color_registry.erase(old_color)
			print("Removed empty color entry: ", old_color)
	
	if not color in color_registry:
		color_registry[color] = []
	color_registry[color].append(element)
	
	# Notify HUD of color change
	HUD.colors_for_image = color_registry
	print("Updated color registry: ", color_registry.keys())

func _finalize_svg_layout() -> void:
	# Calculate scale to fit the panel
	var panel_size = size
	if panel_size.x <= 0 or panel_size.y <= 0:
		panel_size = Vector2(DEFAULT_SVG_SIZE, DEFAULT_SVG_SIZE)
	
	var scale_factor = min(
		panel_size.x / svg_width,
		panel_size.y / svg_height
	) * 0.9  # Leave some margin
	
	svg_root.scale = Vector2(scale_factor, scale_factor)
	
	# Center the SVG
	var scaled_size = Vector2(svg_width, svg_height) * scale_factor
	svg_root.position = (panel_size - scaled_size) * 0.5
	
	# Apply viewBox offset if needed
	if viewbox != Rect2():
		svg_root.position -= viewbox.position * scale_factor

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
