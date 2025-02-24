extends Node2D

signal rescale(File:String, OutTexture:ImageTexture, LastRes:Vector2, LastScale:Vector2)

var SVGTracker: Dictionary = {}
var ShapeSprites: Dictionary = {}  # Track individual shape sprites
var ShapeData: Dictionary = {}     # Store shape attributes

@onready var MainWindow: Window = get_window()
@onready var DevelopmentResolution: Vector2 = Vector2(MainWindow.content_scale_size)
@onready var ActiveResolution: Vector2 = Vector2(MainWindow.size)
var LastScale: Vector2
var Bitmap: Image = Image.new()

func _ready() -> void:
	get_tree().get_root().connect("size_changed", window_size_changed)

func parse_svg_shapes(file: String) -> Dictionary:
	var parser := XMLParser.new()
	var error := parser.open(file)
	if error != OK:
		print("Error opening SVG file: ", error)
		return {}

	var shapes := {}
	var shape_id := 0
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name in ["path", "rect", "circle", "ellipse", "polygon", "polyline"]:
				var attributes := {}
				for idx in range(parser.get_attribute_count()):
					attributes[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
				
				# Store shape data with unique ID
				shapes[str(shape_id)] = {
					"type": node_name,
					"attributes": attributes,
					"original_file": file
				}
				shape_id += 1
	
	return shapes

func create_shape_sprite(shape_id: String, shape_data: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Shape_" + shape_id
	
	# Create texture based on shape type
	var texture := create_shape_texture(shape_data)
	sprite.texture = texture
	
	# Apply position and other attributes
	apply_shape_attributes(sprite, shape_data)
	
	return sprite

func create_shape_texture(shape_data: Dictionary) -> Texture2D:
	var type = shape_data["type"]
	var attributes = shape_data["attributes"]
	
	match type:
		"circle":
			return create_circle_texture(attributes)
		"rect":
			return create_rect_texture(attributes)
		"path":
			return create_path_texture(attributes)
		"ellipse":
			return create_ellipse_texture(attributes)
		"polygon":
			return create_polygon_texture(attributes)
		"polyline":
			return create_polyline_texture(attributes)
	
	return null

func create_circle_texture(attributes: Dictionary) -> Texture2D:
	var cx := float(attributes.get("cx", "0"))
	var cy := float(attributes.get("cy", "0"))
	var r := float(attributes.get("r", "0"))
	
	# Create image with appropriate size
	var size := int(r * 2 + 10)  # Add padding
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Parse fill color
	var fill_color := parse_color(attributes.get("fill", "#FFFFFF"))
	
	# Draw circle
	image.fill(Color.TRANSPARENT)
	image.draw_circle(Vector2(size/2, size/2), r, fill_color)
	
	# Handle stroke if present
	if attributes.has("style"):
		var stroke := parse_style(attributes["style"])
		if stroke.has("stroke"):
			var stroke_color := parse_color(stroke["stroke"])
			var stroke_width := float(stroke.get("stroke-width", "1.0"))
			image.draw_circle(Vector2(size/2, size/2), r, stroke_color, false, stroke_width)
	
	return ImageTexture.create_from_image(image)

func create_rect_texture(attributes: Dictionary) -> Texture2D:
	var x := float(attributes.get("x", "0"))
	var y := float(attributes.get("y", "0"))
	var width := float(attributes.get("width", "0"))
	var height := float(attributes.get("height", "0"))
	
	var image := Image.create(int(width + 10), int(height + 10), false, Image.FORMAT_RGBA8)
	var fill_color := parse_color(attributes.get("fill", "#FFFFFF"))
	
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2(5, 5, width, height), fill_color)
	
	# Handle stroke
	if attributes.has("style"):
		var stroke := parse_style(attributes["style"])
		if stroke.has("stroke"):
			var stroke_color := parse_color(stroke["stroke"])
			var stroke_width := float(stroke.get("stroke-width", "1.0"))
			image.draw_rect(Rect2(5, 5, width, height), stroke_color, false, stroke_width)
	
	return ImageTexture.create_from_image(image)

func parse_color(color_str: String) -> Color:
	if color_str.begins_with("#"):
		return Color.html(color_str)
	# Add more color format parsing as needed
	return Color.WHITE

func parse_style(style_str: String) -> Dictionary:
	var style_dict := {}
	var styles := style_str.split(";")
	for style in styles:
		var parts := style.split(":")
		if parts.size() == 2:
			style_dict[parts[0].strip_edges()] = parts[1].strip_edges()
	return style_dict

func window_size_changed() -> void:
	LastScale = ActiveResolution / DevelopmentResolution
	ActiveResolution = MainWindow.size
	
	# Update all shape sprites
	for shape_id in ShapeSprites:
		var sprite = ShapeSprites[shape_id]
		var shape_data = ShapeData[shape_id]
		var new_texture := create_shape_texture(shape_data)
		sprite.texture = new_texture
		apply_shape_attributes(sprite, shape_data)

func add_svg(file: String) -> void:
	if !SVGTracker.has(file):
		SVGTracker[file] = [FileAccess.get_file_as_bytes(file), get_import_scale(file)]
		
		# Parse shapes and create sprites
		var shapes := parse_svg_shapes(file)
		for shape_id in shapes:
			ShapeData[shape_id] = shapes[shape_id]
			var sprite := create_shape_sprite(shape_id, shapes[shape_id])
			ShapeSprites[shape_id] = sprite
			add_child(sprite)

func remove_svg(file: String, node: Object) -> void:
	SVGTracker[file].remove_at(SVGTracker[file].find(node, 2))
	if SVGTracker[file].size() < 3:
		SVGTracker.erase(file)
		
		# Remove associated shape sprites
		for shape_id in ShapeData.keys():
			if ShapeData[shape_id]["original_file"] == file:
				if ShapeSprites.has(shape_id):
					ShapeSprites[shape_id].queue_free()
					ShapeSprites.erase(shape_id)
				ShapeData.erase(shape_id)

func apply_shape_attributes(sprite: Sprite2D, shape_data: Dictionary):
	var type = shape_data["type"]
	var attributes = shape_data["attributes"]
	
	# Apply position based on shape type
	match type:
		"circle":
			var cx := float(attributes.get("cx", "0"))
			var cy := float(attributes.get("cy", "0"))
			sprite.position = Vector2(cx, cy)
		"rect":
			var x := float(attributes.get("x", "0"))
			var y := float(attributes.get("y", "0"))
			sprite.position = Vector2(x, y)

func get_import_scale(file: String) -> float:
	var ImportSettings: ConfigFile = ConfigFile.new()
	ImportSettings.load(file + ".import")
	return ImportSettings.get_value("params", "svg/scale")

# Placeholder functions for other shape types
func create_path_texture(attributes: Dictionary) -> Texture2D:
	var d = attributes.get("d", "")
	if d.is_empty():
		return null
	
	# Parse path commands
	var points := []
	var current_pos := Vector2.ZERO
	var commands = parse_path_data(d)
	
	# Calculate bounds for image size
	var bounds := Rect2()
	for cmd in commands:
		match cmd.type:
			"M", "L":
				bounds = bounds.expand(cmd.points[0])
			"C":
				for point in cmd.points:
					bounds = bounds.expand(point)
	
	# Add padding and create image
	bounds = bounds.grow(10)
	var image = Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Parse fill and stroke
	var fill_color = parse_color(attributes.get("fill", "#FFFFFF"))
	var stroke_color = Color.TRANSPARENT
	var stroke_width = 1.0
	
	if attributes.has("style"):
		var stroke = parse_style(attributes["style"])
		if stroke.has("stroke"):
			stroke_color = parse_color(stroke["stroke"])
			stroke_width = float(stroke.get("stroke-width", "1.0"))
	
	# Draw path
	var polyline_points := []
	for cmd in commands:
		match cmd.type:
			"M":
				current_pos = cmd.points[0] - bounds.position
				polyline_points = [current_pos]
			"L":
				current_pos = cmd.points[0] - bounds.position
				polyline_points.append(current_pos)
			"C":
				# Approximate cubic bezier with line segments
				var p0 = polyline_points[-1]
				var p1 = cmd.points[0] - bounds.position
				var p2 = cmd.points[1] - bounds.position
				var p3 = cmd.points[2] - bounds.position
				
				for t in range(0, 11):
					var t_float = t / 10.0
					var point = cubic_bezier(p0, p1, p2, p3, t_float)
					polyline_points.append(point)
				current_pos = p3
			"Z":
				polyline_points.append(polyline_points[0])
	
	# Draw filled polygon if fill is specified
	if fill_color.a > 0:
		image.fill_polyline(PackedVector2Array(polyline_points), fill_color)
	
	# Draw stroke if specified
	if stroke_color.a > 0:
		for i in range(len(polyline_points) - 1):
			image.draw_line(polyline_points[i], polyline_points[i + 1], stroke_color, stroke_width)
	
	return ImageTexture.create_from_image(image)

func create_ellipse_texture(attributes: Dictionary) -> Texture2D:
	var cx = float(attributes.get("cx", "0"))
	var cy = float(attributes.get("cy", "0"))
	var rx = float(attributes.get("rx", "0"))
	var ry = float(attributes.get("ry", "0"))
	
	# Create image with appropriate size (with padding)
	var size_x = int(rx * 2 + 10)
	var size_y = int(ry * 2 + 10)
	var image = Image.create(size_x, size_y, false, Image.FORMAT_RGBA8)
	
	# Parse fill and stroke
	var fill_color = parse_color(attributes.get("fill", "#FFFFFF"))
	var stroke_color = Color.TRANSPARENT
	var stroke_width = 1.0
	
	if attributes.has("style"):
		var stroke = parse_style(attributes["style"])
		if stroke.has("stroke"):
			stroke_color = parse_color(stroke["stroke"])
			stroke_width = float(stroke.get("stroke-width", "1.0"))
	
	image.fill(Color.TRANSPARENT)
	
	# Draw ellipse (approximated with polyline)
	var points := []
	var segments = 32  # Number of segments for approximation
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var x = rx * cos(angle) + size_x/2
		var y = ry * sin(angle) + size_y/2
		points.append(Vector2(x, y))
	
	if fill_color.a > 0:
		image.fill_polyline(PackedVector2Array(points), fill_color)
	
	if stroke_color.a > 0:
		for i in range(len(points) - 1):
			image.draw_line(points[i], points[i + 1], stroke_color, stroke_width)
		image.draw_line(points[-1], points[0], stroke_color, stroke_width)
	
	return ImageTexture.create_from_image(image)

func create_polygon_texture(attributes: Dictionary) -> Texture2D:
	var points_str = attributes.get("points", "")
	if points_str.is_empty():
		return null
	
	# Parse points
	var point_strings = points_str.split(" ", false)
	var points := []
	for point_str in point_strings:
		var coords = point_str.split(",")
		if coords.size() == 2:
			points.append(Vector2(float(coords[0]), float(coords[1])))
	
	if points.size() < 3:
		return null
	
	# Calculate bounds for image size
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	
	bounds = bounds.grow(10)
	var image = Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	
	# Parse fill and stroke
	var fill_color = parse_color(attributes.get("fill", "#FFFFFF"))
	var stroke_color = Color.TRANSPARENT
	var stroke_width = 1.0
	
	if attributes.has("style"):
		var stroke = parse_style(attributes["style"])
		if stroke.has("stroke"):
			stroke_color = parse_color(stroke["stroke"])
			stroke_width = float(stroke.get("stroke-width", "1.0"))
	
	image.fill(Color.TRANSPARENT)
	
	# Transform points to image coordinates
	var transformed_points := []
	for point in points:
		transformed_points.append(point - bounds.position)
	
	if fill_color.a > 0:
		image.fill_polyline(PackedVector2Array(transformed_points), fill_color)
	
	if stroke_color.a > 0:
		for i in range(len(transformed_points) - 1):
			image.draw_line(transformed_points[i], transformed_points[i + 1], stroke_color, stroke_width)
		image.draw_line(transformed_points[-1], transformed_points[0], stroke_color, stroke_width)
	
	return ImageTexture.create_from_image(image)

func create_polyline_texture(attributes: Dictionary) -> Texture2D:
	var points_str = attributes.get("points", "")
	if points_str.is_empty():
		return null
	
	# Parse points
	var point_strings = points_str.split(" ", false)
	var points := []
	for point_str in point_strings:
		var coords = point_str.split(",")
		if coords.size() == 2:
			points.append(Vector2(float(coords[0]), float(coords[1])))
	
	if points.size() < 2:
		return null
	
	# Calculate bounds for image size
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	
	bounds = bounds.grow(10)
	var image = Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	
	# Parse stroke (polylines typically don't have fill)
	var stroke_color = Color.TRANSPARENT
	var stroke_width = 1.0
	
	if attributes.has("style"):
		var stroke = parse_style(attributes["style"])
		if stroke.has("stroke"):
			stroke_color = parse_color(stroke["stroke"])
			stroke_width = float(stroke.get("stroke-width", "1.0"))
	
	image.fill(Color.TRANSPARENT)
	
	# Transform points to image coordinates
	var transformed_points := []
	for point in points:
		transformed_points.append(point - bounds.position)
	
	if stroke_color.a > 0:
		for i in range(len(transformed_points) - 1):
			image.draw_line(transformed_points[i], transformed_points[i + 1], stroke_color, stroke_width)
	
	return ImageTexture.create_from_image(image)

func parse_path_data(d: String) -> Array:
	var commands = []
	var current_command = ""
	var current_number = ""
	var i = 0
	
	while i < d.length():
		var c = d[i]
		if c in "MmLlCcZz":
			if current_number != "":
				# Process previous command
				if current_command != "":
					commands.append(_create_path_command(current_command, current_number))
				current_number = ""
			current_command = c
		elif c.is_valid_float() or c in ".-":
			current_number += c
		elif c == "," or c == " ":
			if current_number != "":
				if current_command != "":
					commands.append(_create_path_command(current_command, current_number))
				current_number = ""
		i += 1
	
	if current_number != "" and current_command != "":
		commands.append(_create_path_command(current_command, current_number))
	
	return commands

func _create_path_command(command: String, number_string: String) -> Dictionary:
	var points = []
	var numbers = number_string.split(" ", false)
	var i = 0
	while i < numbers.size():
		if i + 1 < numbers.size():
			points.append(Vector2(float(numbers[i]), float(numbers[i + 1])))
			i += 2
		else:
			break
	return {
		"type": command,
		"points": points
	}

func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1.0 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt
	
	return p0 * mt3 + p1 * 3.0 * mt2 * t + p2 * 3.0 * mt * t2 + p3 * t3
