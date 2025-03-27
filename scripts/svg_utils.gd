class_name SVGUtils extends Node

var id: String
var opacity: float = 1.0
var transform: Transform2D = Transform2D.IDENTITY

func apply_common_attributes(attributes_dict: Dictionary, svg_item: CanvasItem) -> void:
	for attribute in attributes_dict:
		match attribute:
			"id":
				svg_item.name = attributes_dict[attribute]
				id = attributes_dict[attribute]
			"opacity":
				svg_item.modulate.a = float(attributes_dict[attribute])
				opacity = float(attributes_dict[attribute])
			"transform":
				transform = parse_transform(attributes_dict[attribute], svg_item)
				svg_item.transform = transform
			"style":
				apply_css_styles_for_shape(analyse_style(attributes_dict[attribute]), svg_item)

static func parse_transform(transform_str: String, shape: CanvasItem) -> Transform2D:
	var transform := shape.get_transform()
	match transform_str:
		transform_str when transform_str.begins_with("translate"):
			transform_str = transform_str.lstrip("translate(").rstrip(")")
			var transform_split := transform_str.split_floats(",")
			if !transform_split[1]: transform_split[1] = 0 #From the mdn docs,TODO: Add a proper documention for anyone else's viewing sake in the future
			#transform[2] = Vector2(transform_split[0], transform_split[1])
			transform.translated(Vector2(transform_split[0], transform_split[1]))
			
		transform_str when transform_str.begins_with("scale"):
			transform_str = transform_str.lstrip("scale(").rstrip(")")
			var scale_split := transform_str.split_floats(",")
			push_warning("Relative scaling not yet implemented")
			if !scale_split[1]: scale_split[1] = scale_split[0]
			
			
		transform_str when transform_str.begins_with("skewX"):
			transform_str = transform_str.lstrip("skewX(").rstrip(")")
			#transform.get_skew()
			push_warning("Transform not yet implemented")
			
		transform_str when transform_str.begins_with("skewY"):
			transform_str = transform_str.lstrip("skewY(").rstrip(")")
			push_warning("Transform not yet implemented")
			
		transform_str when transform_str.begins_with("matrix"):
			transform_str = transform_str.lstrip("matrix(").rstrip(")")
			transform_str = transform_str.replace("matrix", "").replacen("(", "").replacen(")", "")
			var matrix := transform_str.split_floats(",")
			for i in 3:
				transform[i] = Vector2(matrix[i*2], matrix[i*2+1])
				
		transform_str when transform_str.begins_with("rotate"):
			transform_str = transform_str.lstrip("rotate(").rstrip(")")
			#var float_values := transform_str.split_floats(",")
			#var initial_pivot : Vector2 = shape.pivot_offset
			#print("Float value size: " + str(float_values))
			#if float_values.size() == 1:
				#float_values.append(0)
				#float_values.append(0)
			#shape.pivot_offset = Vector2(float_values[1], float_values[2])
			#print("Setting rotation: " + str(float_values[0]))
			#shape.rotation_degrees = float_values[0]
			##transform.rotated(deg_to_rad(float_values[0]))
			#shape.pivot_offset = initial_pivot
			push_warning("Transform rotation somehow doesnt seem to work properly, not yet implemented")
	
	return transform

## Fill here later
static func apply_css_styles_for_shape(styles: Dictionary, shape: Node) -> void:
	if styles.has("stroke"):
		#print("adding default stroke")
		styles.get_or_add("stroke-width", 1.0)
	for attribute:StringName in styles:
		match attribute:
			"stroke":
				#print("Color: "); print(Color.html(styles[attribute]))
				shape.stroke_color = Color.html(styles[attribute])
				
			"stroke-width":
				shape.stroke_width = float(styles[attribute])
			"fill":
				shape.fill_color = Color.html(styles[attribute])
			var unimplemented_attribute:
				push_warning("Not yet implemented, ", unimplemented_attribute)

static func analyse_style(style_params: String) -> Dictionary:
	var result := {}
	for pair in style_params.split(";", false):
		# Split by colon to separate key and value
		var parts := pair.split(":", false)
		if parts.size() == 2:
			result[parts[0].strip_edges()] = parts[1].strip_edges()
	
	return result
