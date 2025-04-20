@tool
class_name SVGUtils extends Node

# Removed instance variables (id, opacity, transform) as this class seems intended for static utility functions.

# --- Element Creation ---

static func create_element_from_tag(tag_name: String, attributes: Dictionary) -> SVGElement:
	"""Creates and configures an SVGElement subclass based on the SVG tag name."""
	var element: SVGElement

	match tag_name:
		"circle":
			element = SVGCircle.new()
			# Let the element parse its own specific attributes
			if element.has_method("set_circle_properties"):
				element.set_circle_properties(attributes)
			else:
				push_warning("SVGCircle is missing set_circle_properties method.")

		"rect":
			element = SVGRect.new()
			if element.has_method("set_rect_properties"):
				element.set_rect_properties(attributes)
			else:
				push_warning("SVGRect is missing set_rect_properties method.")

		"path":
			element = SVGPath.new()
			# Path data is crucial and specific
			if attributes.has("d"):
				if element.has_method("set_path_data"):
					element.set_path_data(attributes["d"])
				else:
					push_warning("SVGPath is missing set_path_data method.")
			else:
				push_warning("SVG <path> element missing 'd' attribute.")

		"ellipse":
			# Assuming SVGEllipse class exists
			element = SVGEllipse.new()
			if element.has_method("set_ellipse_properties"):
				element.set_ellipse_properties(attributes)
			else:
				push_warning("SVGEllipse is missing set_ellipse_properties method.")
		_:
			push_warning("Unsupported SVG element type: " + tag_name)
			return null

	# Apply common attributes AFTER specific setup (so styles can override)
	if element != null and element.has_method("set_common_attributes"):
		element.set_common_attributes(attributes)
	elif element != null:
		push_warning("SVGElement subclass %s is missing set_common_attributes method." % element.get_class())


	# ID / Name should be handled by the element itself or the caller
	if element != null and attributes.has("id"):
		element.name = attributes["id"]

	return element

# This function seems redundant if SVGElement handles common attributes itself.
# Keeping it commented out for now.
#func apply_common_attributes(attributes_dict: Dictionary, svg_item: CanvasItem) -> void:
#	# ... implementation ...


# --- Transform Parsing ---

# Regex to find transform functions like "translate(arg1 arg2)" or "scale(arg)"
var TRANSFORM_REGEX = RegEx.create_from_string(TRANSFORM_REGEX_PATTERN) # Create a RegEx resource or define inline
# Example inline definition (might need adjustments for complex cases):
const TRANSFORM_REGEX_PATTERN = "([a-zA-Z]+)\\s*\\(([^\\)]*)\\)"
var _transform_regex = RegEx.new()
# func _init(): _transform_regex.compile(TRANSFORM_REGEX_PATTERN)


static func parse_transform(transform_str: String) -> Transform2D:
	"""
	Parses an SVG 'transform' attribute string containing one or more transform functions.
	Returns a Godot Transform2D representing the combined transformation.
	Transforms are applied in the order they appear in the string (left-to-right).
	"""
	if transform_str == null or transform_str.strip_edges().is_empty():
		return Transform2D.IDENTITY

	var accumulated_transform := Transform2D.IDENTITY

	# Use a precompiled RegEx for efficiency
	var regex = RegEx.new()
	regex.compile("([a-zA-Z]+)\\s*\\(([^\\)]*)\\)") # Pattern: functionName(arguments)

	var matches = regex.search_all(transform_str)

	if matches.is_empty() and not transform_str.is_empty():
		push_warning("Could not parse SVG transform string: ", transform_str)
		return Transform2D.IDENTITY

	for match in matches:
		if match.get_group_count() < 2: continue # Should not happen with this regex

		var func_name = match.get_string(1).to_lower()
		var args_str = match.get_string(2)
		var args = args_str.split_floats(",", false) # Split arguments by comma or space

		var current_func_transform := Transform2D.IDENTITY

		match func_name:
			"translate":
				var tx = args[0] if args.size() >= 1 else 0.0
				var ty = args[1] if args.size() >= 2 else 0.0 # SVG ty defaults to 0
				current_func_transform = Transform2D(0.0, Vector2(tx, ty)) # Create a pure translation transform

			"scale":
				var sx = args[0] if args.size() >= 1 else 1.0
				var sy = args[1] if args.size() >= 2 else sx # SVG sy defaults to sx
				current_func_transform = Transform2D.IDENTITY.scaled(Vector2(sx, sy))

			"rotate":
				var angle_deg = args[0] if args.size() >= 1 else 0.0
				var angle_rad = deg_to_rad(angle_deg)
				if args.size() >= 3:
					# Rotate around a specific point (cx, cy)
					var cx = args[1]
					var cy = args[2]
					var center = Vector2(cx, cy)
					# Create transform: Translate to origin, Rotate, Translate back
					var T_center = Transform2D(0.0, center)
					var R = Transform2D(angle_rad, Vector2.ZERO) # Rotation around origin
					var T_neg_center = Transform2D(0.0, -center)
					# Order: Apply T_neg_center first, then R, then T_center
					current_func_transform = T_center * R * T_neg_center
				else:
					# Rotate around the current origin (0,0 of the local space)
					current_func_transform = Transform2D(angle_rad, Vector2.ZERO)

			"skewx":
				var angle_deg = args[0] if args.size() >= 1 else 0.0
				var angle_rad = deg_to_rad(angle_deg)
				# Matrix: [1 tan(a)] [0 1] [0 0] -> Godot columns: (1, tan(a)), (0, 1), (0, 0)
				# Correction: Godot basis vectors are columns. SVG matrix rows become columns.
				# SVG: [[1, tan(a)], [0, 1]] => Godot: x=(1,0), y=(tan(a), 1)
				current_func_transform = Transform2D(Vector2(1, 0), Vector2(tan(angle_rad), 1), Vector2.ZERO)

			"skewy":
				var angle_deg = args[0] if args.size() >= 1 else 0.0
				var angle_rad = deg_to_rad(angle_deg)
				# Matrix: [1 0] [tan(a) 1] [0 0] -> Godot columns: (1, tan(a)), (0, 1), (0, 0)
				# Correction: SVG: [[1, 0], [tan(a), 1]] => Godot: x=(1, tan(a)), y=(0, 1)
				current_func_transform = Transform2D(Vector2(1, tan(angle_rad)), Vector2(0, 1), Vector2.ZERO)

			"matrix":
				if args.size() >= 6:
					var a = args[0]
					var b = args[1]
					var c = args[2]
					var d = args[3]
					var e = args[4]
					var f = args[5]
					# SVG matrix(a b c d e f) maps to Transform2D columns:
					# x = (a, b)
					# y = (c, d)
					# origin = (e, f)
					current_func_transform = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(e, f))
				else:
					push_warning("Invalid matrix transform arguments: ", args_str)

			_:
				push_warning("Unsupported SVG transform function: ", func_name)

		# Apply the transform for the current function
		# Since Godot methods apply T * current, and SVG implies current * T,
		# we multiply the accumulated transform by the new function's transform.
		accumulated_transform = accumulated_transform * current_func_transform

	return accumulated_transform


# --- Style Parsing ---

static func apply_css_styles_for_shape(styles: Dictionary, shape_node: Node) -> void:
	"""Applies styles from a CSS-like dictionary to an SVGElement node."""
	# Ensure the target node is actually an SVGElement or has the expected properties
	if not shape_node is SVGElement:
		# Maybe try setting properties directly if names match? Risky.
		# push_warning("Attempting to apply styles to non-SVGElement node: %s" % shape_node.name)
		return

	# Note: This might override attributes set directly on the tag (e.g., fill="red" style="fill:blue;")
	# CSS specificity rules are not implemented here; style attribute usually wins.

	if styles.has("fill"):
		var fill_val = styles["fill"].to_lower()
		if fill_val != "none":
			shape_node.fill_color = Color.html(fill_val)
		else:
			shape_node.fill_color = Color.TRANSPARENT # Treat 'none' as transparent fill
	if styles.has("stroke"):
		var stroke_val = styles["stroke"].to_lower()
		if stroke_val != "none":
			shape_node.stroke_color = Color.html(stroke_val)
			# SVG default stroke-width is 1 if stroke is not none
			if not styles.has("stroke-width"):
				shape_node.stroke_width = 1.0
		else:
			shape_node.stroke_color = Color.TRANSPARENT
			shape_node.stroke_width = 0.0 # Stroke 'none' implies zero width
	if styles.has("stroke-width"):
		shape_node.stroke_width = float(styles["stroke-width"])
	if styles.has("opacity"):
		# This applies to the whole element (fill and stroke)
		shape_node.opacity = float(styles["opacity"]) # Uses the opacity setter in SVGElement
	if styles.has("fill-opacity"):
		# Modulates only the fill color's alpha
		shape_node.fill_color.a *= float(styles["fill-opacity"])
	if styles.has("stroke-opacity"):
		# Modulates only the stroke color's alpha
		shape_node.stroke_color.a *= float(styles["stroke-opacity"])

	# Add more CSS properties here as needed (e.g., stroke-linecap, stroke-linejoin, font-family, etc.)


static func analyse_style(style_string: String) -> Dictionary:
	"""Parses a CSS style string (e.g., 'fill:red; stroke:blue;') into a dictionary."""
	var result := {}
	if style_string == null or style_string.is_empty():
		return result

	for pair in style_string.split(";", false): # Don't allow empty strings from trailing ';'
		var parts := pair.split(":", 2, false) # Split only on the first colon, max 2 parts
		if parts.size() == 2:
			var key = parts[0].strip_edges().to_lower() # Use lowercase keys for consistency
			var value = parts[1].strip_edges()
			if not key.is_empty() and not value.is_empty():
				result[key] = value

	return result
