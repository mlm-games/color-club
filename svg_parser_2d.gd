@tool

## Used from https://github.com/pixelriot/SVG2Godot/blob/c70cfee4a2a396a795326b567d01f977c81c42c7/SVGParser.gd

class_name SVGParser extends EditorScript

var file_path = "res://assets/art/test1.svg"
var use_path2d = false #true to deploy Path2D for vector paths

var xml_data = XMLParser.new()
var root_node : Node
var current_node : Node
const MAX_WIDTH = 7.0

func _run() -> void:
	if xml_data.open(file_path) != OK:
		print("Error opening file: ", file_path)
		return
	root_node = self.get_scene()
	current_node = root_node
	
	#clear tree
	for c in root_node.get_children():
		c.queue_free()
	
	parse()

"""
Loop through all nodes and create the respective element.
"""
func parse() -> void:
	print("start parsing ...")
	
	while xml_data.read() == OK:
		if not xml_data.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
		elif xml_data.get_node_name() == "g":
			if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
				process_group(xml_data)
			elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT_END:
				current_node = current_node.get_parent()
		elif xml_data.get_node_name() == "rect":
			process_svg_rectangle(xml_data)
		elif xml_data.get_node_name() == "polygon":
			process_svg_polygon(xml_data)
		elif xml_data.get_node_name() == "path":
			process_svg_path(xml_data)
	print("... end parsing")




func process_group(element:XMLParser) -> void:
	var new_group = Node2D.new()
	new_group.name = element.get_named_attribute_value("id")
	new_group.transform = get_svg_transform(element)
	current_node.add_child(new_group)
	new_group.owner = root_node
	new_group.set_meta("_edit_group_", true)
	current_node = new_group
	print("group " + new_group.name + " created")


func process_svg_rectangle(element:XMLParser) -> void:
	var new_rect = ColorRect.new()
	new_rect.name = element.get_named_attribute_value("id")
	current_node.add_child(new_rect)
	new_rect.owner = root_node
	
	#transform
	var x = float(element.get_named_attribute_value("x"))
	var y = float(element.get_named_attribute_value("y"))
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	var transform = get_svg_transform(element)
	new_rect.position = Vector2((x), (y))
	new_rect.size = Vector2(width, height)
	new_rect.position = transform * new_rect.position
	new_rect.size.x *= transform[0][0] 
	new_rect.size.y *= transform[1][1]
	
	#style
	var style = get_svg_style(element)
	if style.has("fill"):
		new_rect.color = Color(style["fill"])
	if style.has("fill-opacity"):
		new_rect.color.a = float(style["fill-opacity"])
		
	print("-rect ", new_rect.name, " created")


func process_svg_polygon(element:XMLParser) -> void:
	var points : PackedVector2Array
	var points_split = element.get_named_attribute_value("points").split(" ", false)
	for i in points_split:
		var values = i.split_floats(",", false)
		points.append(Vector2(values[0], values[1]))
	points.append(points[0])

	#create closed line
	var new_line = Line2D.new()
	new_line.name = element.get_named_attribute_value("id")
	new_line.transform = get_svg_transform(element)
	current_node.add_child(new_line)
	new_line.owner = root_node
	new_line.points = points
	
	#style
	var style = get_svg_style(element)
	if style.has("fill"):
		new_line.default_color = Color(style["fill"])
	if style.has("stroke-width"):
		new_line.width = float(style["stroke-width"])

	print("-line ", new_line.name, " created")

func process_svg_path(element: XMLParser) -> void:
	var path_data = element.get_named_attribute_value("d")
	print("Processing path with d=", path_data)
	
	# Normalize path data
	for symbol in ["M", "L", "H", "V", "C", "S", "Q", "T", "A", "Z", 
				  "m", "l", "h", "v", "c", "s", "q", "t", "a", "z"]:
		path_data = path_data.replacen(symbol, " " + symbol + " ")
	path_data = path_data.replacen(",", " ")
	
	# Split into commands
	var commands = path_data.split(" ", false)
	var points = PackedVector2Array()
	var cursor = Vector2.ZERO
	var start_pos = Vector2.ZERO
	var is_closed = false
	
	var i = 0
	while i < commands.size():
		var cmd = commands[i]
		match cmd:
			"M", "m":
				if commands.size() > i + 2 and commands[i+1].is_valid_float():
					var point = Vector2(float(commands[i+1]), float(commands[i+2]))
					if cmd == "m":
						point += cursor
					cursor = point
					if points.is_empty():
						start_pos = cursor
						points.append(cursor)
					else:
						points.append(cursor)
					i += 3
				else:
					i += 1
			
			"L", "l":
				if commands.size() > i + 2 and commands[i+1].is_valid_float():
					var point = Vector2(float(commands[i+1]), float(commands[i+2]))
					if cmd == "l":
						point += cursor
					cursor = point
					points.append(cursor)
					i += 3
				else:
					i += 1
			
			"Z", "z":
				is_closed = true
				cursor = start_pos
				if points.size() > 0 and points[0] != points[points.size() - 1]:
					points.append(points[0])  # Close the path
				i += 1
			
			_:
				i += 1
	
	if points.size() >= 2:  # Only create if we have at least 2 points
		if is_closed:
			create_polygon2d(
				element.get_named_attribute_value("id") + "_0",
				current_node,
				points,
				get_svg_transform(element),
				get_svg_style(element)
			)
		else:
			create_line2d(
				element.get_named_attribute_value("id") + "_0",
				current_node,
				points,
				get_svg_transform(element),
				get_svg_style(element)
			)

func create_polygon2d(name: String, parent: Node, points: PackedVector2Array, transform: Transform2D, style: Dictionary) -> void:
	var new_poly = Polygon2D.new()
	new_poly.name = name
	new_poly.transform = transform
	parent.add_child(new_poly)
	new_poly.owner = root_node
	new_poly.polygon = points
	
	if style.has("fill"):
		new_poly.color = Color(style["fill"])
	
	if style.has("stroke") and style["stroke"] != "none":
		var outline = Line2D.new()
		outline.name = name + "_stroke"
		new_poly.add_child(outline)
		outline.owner = root_node
		
		# Make sure the outline follows the polygon shape
		var outline_points = points.duplicate()
		if outline_points.size() > 0 and outline_points[0] != outline_points[outline_points.size() - 1]:
			outline_points.append(outline_points[0])
		outline.points = outline_points
		
		outline.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			outline.width = float(style["stroke-width"])

func approximate_arc_to_bezier(start: Vector2, end: Vector2, radius: Vector2, 
							 angle: float, large_arc: bool, sweep: bool) -> Array:
	var points = []
	
	# Transform to unit circle coordinates
	var cos_angle = cos(angle)
	var sin_angle = sin(angle)
	
	# Transform start and end points
	var transformed_start = Vector2(
		(start.x * cos_angle + start.y * sin_angle) / radius.x,
		(-start.x * sin_angle + start.y * cos_angle) / radius.y
	)
	var transformed_end = Vector2(
		(end.x * cos_angle + end.y * sin_angle) / radius.x,
		(-end.x * sin_angle + end.y * cos_angle) / radius.y
	)
	
	# Calculate center and angles
	var mid_point = (transformed_start - transformed_end) * 0.5
	var center_factor = sqrt(
		max(0, 1.0 / mid_point.length_squared() - 0.25)
	)
	if large_arc == sweep:
		center_factor = -center_factor
		
	var center = Vector2(
		mid_point.y * center_factor,
		-mid_point.x * center_factor
	) + (transformed_start + transformed_end) * 0.5
	
	var start_angle = atan2(
		transformed_start.y - center.y,
		transformed_start.x - center.x
	)
	var sweep_angle = atan2(
		transformed_end.y - center.y,
		transformed_end.x - center.x
	) - start_angle
	
	if !sweep and sweep_angle > 0:
		sweep_angle -= 2 * PI
	elif sweep and sweep_angle < 0:
		sweep_angle += 2 * PI
	
	# Convert back to original coordinate system and approximate with cubic beziers
	var segments = int(ceil(abs(sweep_angle) / (PI * 0.5)))
	var angle_step = sweep_angle / segments
	
	for i in range(segments):
		var angle1 = start_angle + i * angle_step
		var angle2 = start_angle + (i + 1) * angle_step
		
		var t = 4.0/3.0 * tan(angle_step * 0.25)
		
		var p0 = Vector2(cos(angle1), sin(angle1))
		var p1 = Vector2(cos(angle1) - t * sin(angle1), sin(angle1) + t * cos(angle1))
		var p2 = Vector2(cos(angle2) + t * sin(angle2), sin(angle2) - t * cos(angle2))
		var p3 = Vector2(cos(angle2), sin(angle2))
		
		# Transform back
		var transform = Transform2D(angle, radius)
		p0 = transform.basis_xform(p0)
		p1 = transform.basis_xform(p1)
		p2 = transform.basis_xform(p2)
		p3 = transform.basis_xform(p3)
		
		points.append({
			"point": p3,
			"control1": p1 - p3,
			"control2": p2 - p3
		})
	
	return points

func create_path2d(name: String, parent: Node, curve: Curve2D, transform: Transform2D, style: Dictionary) -> void:
	var new_path = Path2D.new()
	new_path.name = name
	
	# Apply transform correctly
	new_path.transform = transform
	
	# Adjust curve points if needed
	var adjusted_curve = Curve2D.new()
	for i in curve.get_point_count():
		var pos = curve.get_point_position(i)
		var in_control = curve.get_point_in(i)
		var out_control = curve.get_point_out(i)
		adjusted_curve.add_point(pos, in_control, out_control)
	
	new_path.curve = adjusted_curve
	parent.add_child(new_path)
	new_path.owner = root_node

	# Handle style properly
	if style.has("stroke"):
		new_path.modulate = Color(style["stroke"])
	if style.has("stroke-width"):
		# Create a Line2D as child for stroke visualization
		var line = Line2D.new()
		line.width = float(style["stroke-width"])
		line.default_color = Color.WHITE
		new_path.add_child(line)
		
		# Sample points along curve
		var points = PackedVector2Array()
		var length = curve.get_baked_length()
		var step = length / 100.0  # Adjust sampling density as needed
		for i in range(101):
			points.append(curve.sample_baked(i * step))
		line.points = points


func create_line2d(	name:String, 
					parent:Node, 
					points:PackedVector2Array, 
					transform:Transform2D, 
					style:Dictionary) -> void:
	var new_line = Line2D.new()
	new_line.name = name
	new_line.transform = transform
	parent.add_child(new_line)
	new_line.owner = root_node
	new_line.points = points
	
	#style
	if style.has("stroke"):
		new_line.default_color = Color(style["stroke"])
	if style.has("stroke-width"):
		#var line = Line2D.new() 
		new_line.width = float(style["stroke-width"])
		#new_path.add_child(line)
		#
		## Sample points along curve
		#var curve_points = []
		#var step = 0.1
		#for i in range(0, 1.0, step):
			#points.append(curve.interpolate(i))
		#line.points = points



static func get_svg_transform(element: XMLParser) -> Transform2D:
	var transform = Transform2D.IDENTITY
	
	if !element.has_attribute("transform"):
		return transform
		
	var svg_transform = element.get_named_attribute_value("transform")
	
	# Split multiple transformations if present
	var transforms = svg_transform.split(")")
	
	for t in transforms:
		t = t.strip_edges()
		if t.is_empty():
			continue
			
		if t.begins_with("translate"):
			var values = _get_transform_values(t)
			if values.size() == 1:
				transform *= Transform2D.IDENTITY.translated(Vector2(values[0], 0))
			elif values.size() == 2:
				transform *= Transform2D.IDENTITY.translated(Vector2(values[0], values[1]))
				
		elif t.begins_with("scale"):
			var values = _get_transform_values(t)
			if values.size() == 1:
				transform *= Transform2D.IDENTITY.scaled(Vector2(values[0], values[0]))
			elif values.size() == 2:
				transform *= Transform2D.IDENTITY.scaled(Vector2(values[0], values[1]))
				
		elif t.begins_with("rotate"):
			var values = _get_transform_values(t)
			if values.size() >= 1:
				var angle = values[0] * (PI / 180.0)
				if values.size() == 3:
					var pivot = Vector2(values[1], values[2])
					transform *= Transform2D().translated(-pivot).rotated(angle).translated(pivot)
				else:
					transform *= Transform2D().rotated(angle)
					
		elif t.begins_with("matrix"):
			var values = _get_transform_values(t)
			if values.size() == 6:
				transform *= Transform2D(Vector2(values[0], values[1]),
									  Vector2(values[2], values[3]),
									  Vector2(values[4], values[5]))
									  
	return transform

static func _get_transform_values(transform_str: String) -> Array:
	var value_str = transform_str.split("(")[1].strip_edges()
	return value_str.split(",", false)


static func get_svg_style(element:XMLParser) -> Dictionary:
	var style : Dictionary = {}
	var style_flags : Array[StringName] = ["fill", "stroke", "stroke-width", "stop-color", "fill-opacity", "stroke-opacity", "stop-opacity", "stroke-miterlimit", "stroke-linejoin", "stroke-linecap"]
	# Check direct attributes first
	for attribute in style_flags:
		if element.has_attribute(attribute):
			style[attribute] = element.get_named_attribute_value_safe(attribute)
		
	if element.has_attribute("style"):
		var svg_style = element.get_named_attribute_value("style")
		svg_style = svg_style.replacen(":", "\":\"")
		svg_style = svg_style.replacen(";", "\",\"")
		svg_style = "{\"" + svg_style + "\"}"
		style = JSON.parse_string(svg_style)
	return style
