@tool
extends EditorScript

#Huge thanks to https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial for most of the "understanding" part

#TODO: remove if unnecessary
#class RectangleSVG:
	#var id: String
	#var 

#TODO: add a main SVGNode class from which others inherit so all of them have similar names for properties?

var original_color_dict : Dictionary[StringName, Color] = {}

func _run() -> void:
	var parser := XMLParser.new()
	parser.open("res://assets/art/pic2.svg")
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			var attributes_dict := {}
			for idx in range(parser.get_attribute_count()):
				#TODO: if reduces code heavily, insert after typing values: if (parser.get_attribute_value(idx)).is_valid_float() : attributes_dict[parser.get_attribute_name(idx)] = float(parser.get_attribute_value(idx))
				attributes_dict[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
			#print("The ", node_name, " element has the following attributes: ", attributes_dict)
			match node_name:
				"rect":
					print("The ", node_name, " element has the following attributes: ", attributes_dict)
					var shape := create_rect_shape(attributes_dict)
					#print(create_rect_shape(attributes_dict).global_position)
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()
				"circle":
					#print(create_circle_shape(attributes_dict).global_position)
					#self.get_scene().add_child(create_circle_shape(attributes_dict))
					var shape := create_circle_shape(attributes_dict)
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()
				"path":
					var shape := create_path_shape(attributes_dict)
					
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()
				"line":
					push_warning("Line hasnt been implemented yet, will be later coverted to path and drawn ig")
				"ellipse":
					push_warning("Will be implemented once draw_ellipse is merged into godot.")
				"polyline":
					push_warning("PathSVG already does this, need to convert...")
				"polygon":
					push_warning("PathSVG already does this, need to convert...")


static func create_rect_shape(attributes_dict: Dictionary) -> Panel:
	var panel := Panel.new()
	var style_box := StyleBoxFlat.new()
	panel.add_theme_stylebox_override("panel", style_box)
	
	for attribute:StringName in attributes_dict:
		match attribute:
			"id":
				panel.name = attributes_dict[attribute]
			"x":
				panel.position.x = float(attributes_dict[attribute])
			"y":
				panel.position.y = float(attributes_dict[attribute])
			"width":
				panel.custom_minimum_size.x = float(attributes_dict[attribute])
			"height":
				panel.custom_minimum_size.y = float(attributes_dict[attribute])
			"opacity":
				panel.modulate.a = float(attributes_dict[attribute])
			"rx":
				style_box.corner_radius_top_left = float(attributes_dict[attribute])
				style_box.corner_radius_top_right = float(attributes_dict[attribute])
				style_box.corner_radius_bottom_left = float(attributes_dict[attribute])
				style_box.corner_radius_bottom_right = float(attributes_dict[attribute])
			"ry":
				#TODO: Can be used in combination with rx for different horizontal/vertical rounding
				style_box.corner_radius_top_left = float(attributes_dict[attribute])
				style_box.corner_radius_top_right = float(attributes_dict[attribute])
				style_box.corner_radius_bottom_left = float(attributes_dict[attribute])
				style_box.corner_radius_bottom_right = float(attributes_dict[attribute])
			"fill":
				style_box.bg_color = Color.html(attributes_dict[attribute])
				print("Color: "); print(Color.html(attributes_dict[attribute]))
			"style":
				var styles := analyse_style(attributes_dict[attribute])
				apply_styles_for_shape(styles, panel)
	return panel

static func create_circle_shape(attributes_dict: Dictionary) -> SVGCircle:
	var circle := SVGCircle.new()
	circle.set_circle_properties(attributes_dict)
	return circle

static func create_path_shape(attributes_dict: Dictionary) -> SVGPath:
	var path := SVGPath.new()
	
	for attribute:StringName in attributes_dict:
		match attribute:
			"id":
				path.name = attributes_dict[attribute]
			"d":
				path.set_path_data(attributes_dict[attribute])
			"stroke":
				print("Color: "); print(Color.html(attributes_dict[attribute]))
				#path.stroke_color = Color.html(attributes_dict[attribute])
			"stroke-width":
				path.stroke_width = float(attributes_dict[attribute])
			"fill":
				path.fill_color = Color.html(attributes_dict[attribute])
			"opacity":
				path.modulate.a = float(attributes_dict[attribute])
	return path

static func analyse_style(style_params: String) -> Dictionary:
	var result := {}
	for pair in style_params.split(";", false):
		# Split by colon to separate key and value
		var parts := pair.split(":", false)
		if parts.size() == 2:
			result[parts[0].strip_edges()] = parts[1].strip_edges()
	
	return result

#TODO: Do it indivdually per object shape by passing the shape also as an parameter


func analyse_transform(transform_values: String, shape: Node2D) -> Transform2D:
	var transform := Transform2D.IDENTITY
	match transform_values:
		transform_values when transform_values.begins_with("transform"):
			transform_values = transform_values.lstrip("transform(").rstrip(")")
			var transform_split := transform_values.split_floats(",")
			if !transform_split[1]: transform_split[1] = 0 #From the mdn docs,TODO: Add a proper documention for anyone else's viewing sake in the future
			transform[2] = Vector2(transform_split[0], transform_split[1])
			
		transform_values when transform_values.begins_with("scale"):
			transform_values = transform_values.lstrip("scale(").rstrip(")")
			var scale_split := transform_values.split_floats(",")
			if !scale_split[2]: scale_split[2] = scale_split[1]
			
		transform_values when transform_values.begins_with("skewX"):
			transform_values = transform_values.lstrip("skewX(").rstrip(")")
			push_warning("Transform not yet implemented")
			
		transform_values when transform_values.begins_with("skewY"):
			transform_values = transform_values.lstrip("skewY(").rstrip(")")
			push_warning("Transform not yet implemented")
			
		transform_values when transform_values.begins_with("matrix"):
			transform_values = transform_values.lstrip("matrix(").rstrip(")")
			transform_values = transform_values.replace("matrix", "").replacen("(", "").replacen(")", "")
			var matrix := transform_values.split_floats(",")
			for i in 3:
				transform[i] = Vector2(matrix[i*2], matrix[i*2+1])
				
		transform_values when transform_values.begins_with("rotate"):
			transform_values = transform_values.lstrip("rotate(").rstrip(")")
			var float_values := transform_values.split_floats(",")
			if float_values[1]: shape.pivot_offset.x = float_values[1]
			if float_values[2]: shape.pivot_offset.y = float_values[2]
			push_warning("Transform not yet implemented")
	
	return transform

static func apply_styles_for_shape(styles: Dictionary, shape: CanvasItem):
	push_warning("Not yet implemented, styles")
