@tool

## Used from https://github.com/pixelriot/SVG2Godot/blob/c70cfee4a2a396a795326b567d01f977c81c42c7/SVGParser.gd

class_name SVGParser extends EditorScript

var file_path = "res://map01.svg"  #"res://assets/art/test1.svg"
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
	
	# Handle double periods in numbers (e.g., "0..5" -> "0.5")
	var double_period_regex = RegEx.new()
	double_period_regex.compile("\\.\\.")
	var matches = double_period_regex.search_all(path_data)
	for match in matches:
		var fixed_number = match.get_string().replace("..", ".")
		path_data = path_data.replace(match.get_string(), fixed_number)
	
	# Normalize path data
	for symbol in ["m", "M", "v", "V", "h", "H", "l", "L", "c", "C", "s", "S", "q", "Q", "t", "T", "a", "A", "z", "Z"]:
		path_data = path_data.replacen(symbol, " " + symbol + " ")
	path_data = path_data.replacen(",", " ")
	
	print("Processed path data:", path_data)
	
	# Split into command arrays
	var path_commands = path_data.split(" ", false)
	var command_groups = []
	var current_group : PackedStringArray
	
	# Group commands by their starting move command
	for cmd in path_commands:
		if cmd in ["m", "M"]:
			if current_group != null and current_group.size() > 0:
				command_groups.append(current_group)
			current_group = PackedStringArray()
		if cmd != "":
			current_group.append(cmd)
	
	if current_group != null and current_group.size() > 0:
		command_groups.append(current_group)
	
	print("Number of path segments:", command_groups.size())
	
	# Process each command group
	var group_index = -1
	for command_group in command_groups:
		var cursor = Vector2.ZERO
		var start_pos = Vector2.ZERO
		var points : PackedVector2Array
		var curve = Curve2D.new()
		var last_control = Vector2.ZERO
		var last_cubic_control = Vector2.ZERO
		group_index += 1
		
		process_command_group(command_group, cursor, start_pos, points, curve, last_control, last_cubic_control)
		
		# Create appropriate node based on path type
		if use_path2d and curve.get_point_count() > 1:
			create_path2d(
				element.get_named_attribute_value("id") + "_" + str(group_index),
				current_node,
				curve,
				get_svg_transform(element),
				get_svg_style(element)
			)
		elif command_group[command_group.size()-1].to_upper() == "Z":
			create_polygon2d(
				element.get_named_attribute_value("id") + "_" + str(group_index),
				current_node,
				points,
				get_svg_transform(element),
				get_svg_style(element)
			)
		else:
			create_line2d(
				element.get_named_attribute_value("id") + "_" + str(group_index),
				current_node,
				points,
				get_svg_transform(element),
				get_svg_style(element)
			)

func process_command_group(command_group: PackedStringArray, cursor: Vector2, start_pos: Vector2, 
						 points: PackedVector2Array, curve: Curve2D, 
						 last_control: Vector2, last_cubic_control: Vector2) -> void:
	var i := 0
	while i < command_group.size():
		match command_group[i]:
			"m", "M":
				if command_group.size() > i + 2 and command_group[i+1].is_valid_float():
					var point = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					if command_group[i] == "m":
						point += cursor
					cursor = point
					if points.is_empty():
						start_pos = cursor
						points.append(cursor)
						curve.add_point(cursor)
					else:
						points.append(cursor)
						curve.add_point(cursor)
					i += 3
				else:
					i += 1

			"l", "L":
				if command_group.size() > i + 2 and command_group[i+1].is_valid_float():
					var point = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					if command_group[i] == "l":
						point += cursor
					cursor = point
					points.append(cursor)
					curve.add_point(cursor)
					i += 3
				else:
					i += 1

			"h", "H":
				if command_group.size() > i + 1 and command_group[i+1].is_valid_float():
					var x = float(command_group[i+1])
					if command_group[i] == "h":
						cursor.x += x
					else:
						cursor.x = x
					points.append(cursor)
					curve.add_point(cursor)
					i += 2
				else:
					i += 1

			"v", "V":
				if command_group.size() > i + 1 and command_group[i+1].is_valid_float():
					var y = float(command_group[i+1])
					if command_group[i] == "v":
						cursor.y += y
					else:
						cursor.y = y
					points.append(cursor)
					curve.add_point(cursor)
					i += 2
				else:
					i += 1

			"c", "C":
				if command_group.size() > i + 6 and command_group[i+1].is_valid_float():
					var control1 = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					var control2 = Vector2(float(command_group[i+3]), float(command_group[i+4]))
					var end = Vector2(float(command_group[i+5]), float(command_group[i+6]))
					
					if command_group[i] == "c":
						control1 += cursor
						control2 += cursor
						end += cursor
					
					curve.add_point(end, control1 - end, control2 - end)
					points.append(end)
					last_cubic_control = control2
					cursor = end
					i += 7
				else:
					i += 1

			"s", "S":
				if command_group.size() > i + 4 and command_group[i+1].is_valid_float():
					var control2 = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					var end = Vector2(float(command_group[i+3]), float(command_group[i+4]))
					var control1 = cursor + (cursor - last_cubic_control)
					
					if command_group[i] == "s":
						control2 += cursor
						end += cursor
					
					curve.add_point(end, control1 - end, control2 - end)
					points.append(end)
					last_cubic_control = control2
					cursor = end
					i += 5
				else:
					i += 1
			
			"q", "Q":
				if command_group.size() > i + 4 and command_group[i+1].is_valid_float():
					var control = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					var end = Vector2(float(command_group[i+3]), float(command_group[i+4]))
					
					if command_group[i] == "q":
						control += cursor
						end += cursor
					
					# Convert quadratic to cubic Bezier for Curve2D
					var cubic_control1 = cursor + (control - cursor) * (2.0/3.0)
					var cubic_control2 = end + (control - end) * (2.0/3.0)
					
					curve.add_point(end, cubic_control1 - end, cubic_control2 - end)
					points.append(end)
					last_control = control
					cursor = end
					i += 5
				else:
					i += 1

			"t", "T":
				if command_group.size() > i + 2 and command_group[i+1].is_valid_float():
					var end = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					if command_group[i] == "t":
						end += cursor
					
					# Reflect previous control point
					var control = cursor + (cursor - last_control)
					
					# Convert quadratic to cubic Bezier
					var cubic_control1 = cursor + (control - cursor) * (2.0/3.0)
					var cubic_control2 = end + (control - end) * (2.0/3.0)
					
					curve.add_point(end, cubic_control1 - end, cubic_control2 - end)
					points.append(end)
					last_control = control
					cursor = end
					i += 3
				else:
					i += 1

			"a", "A":
				if command_group.size() > i + 7 and command_group[i+1].is_valid_float():
					var radius = Vector2(float(command_group[i+1]), float(command_group[i+2]))
					var angle = deg_to_rad(float(command_group[i+3]))
					var large_arc = bool(int(command_group[i+4]))
					var sweep = bool(int(command_group[i+5]))
					var end = Vector2(float(command_group[i+6]), float(command_group[i+7]))
					
					if command_group[i] == "a":
						end += cursor
					
					# Convert arc to cubic bezier approximation
					var arc_points = approximate_arc_to_bezier(
						cursor,
						end,
						radius,
						angle,
						large_arc,
						sweep
					)
					
					for p in arc_points:
						points.append(p.point)
						if p.has("control1") and p.has("control2"):
							curve.add_point(p.point, p.control1, p.control2)
						else:
							curve.add_point(p.point)
					
					cursor = end
					i += 8
				else:
					i += 1

			"z", "Z":
				if points.size() > 0:
					points.append(start_pos)
					curve.add_point(start_pos)
				cursor = start_pos
				i += 1
			
			_:
				i += 1

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

func create_path2d(	name:String, 
					parent:Node, 
					curve:Curve2D, 
					transform:Transform2D, 
					style:Dictionary) -> void:
	var new_path = Path2D.new()
	new_path.name = name
	new_path.transform = transform
	parent.add_child(new_path)
	new_path.owner = root_node
	new_path.curve = curve
	
	#style
	if style.has("stroke"):
		new_path.modulate = Color(style["stroke"])
#	if style.has("stroke-width"):
#		new_path.width = float(style["stroke-width"])


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


func create_polygon2d(	name:String, 
						parent:Node, 
						points:PackedVector2Array, 
						transform:Transform2D, 
						style:Dictionary) -> void:
	var new_poly
	#style
	if style.has("fill") and style["fill"] != "none":
		#create base
		new_poly = Polygon2D.new()
		new_poly.name = name
		parent.add_child(new_poly)
		new_poly.owner = root_node
		new_poly.transform = transform
		new_poly.polygon = points
		new_poly.color = Color(style["fill"])
	
	if style.has("stroke") and style["stroke"] != "none":
		#create outline
		var new_outline = Line2D.new()
		new_outline.name = name + "_stroke"
		if new_poly:
			new_poly.add_child(new_outline)
		else:
			parent.add_child(new_outline)
			new_outline.transform = transform
		new_outline.owner = root_node
		points.append(points[0])
		new_outline.points = points
		
		new_outline.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			new_outline.width = float(style["stroke-width"])


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
