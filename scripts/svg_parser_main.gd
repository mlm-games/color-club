@tool
extends EditorScript

#TODO: remove if unnecessary
#class RectangleSVG:
	#var id: String
	#var 

var original_color_dict : Dictionary[StringName, Color] = {}

func _run() -> void:
	var parser = XMLParser.new()
	parser.open("res://assets/art/map01.svg")
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			var attributes_dict = {}
			for idx in range(parser.get_attribute_count()):
				#TODO: if reduces code heavily, insert after typing values: if (parser.get_attribute_value(idx)).is_valid_float() : attributes_dict[parser.get_attribute_name(idx)] = float(parser.get_attribute_value(idx))
				attributes_dict[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
			#print("The ", node_name, " element has the following attributes: ", attributes_dict)
			match node_name:
				"rect":
					print("The ", node_name, " element has the following attributes: ", attributes_dict)
					var shape = create_rect_shape(attributes_dict)
					#print(create_rect_shape(attributes_dict).global_position)
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()
				"circle":
					#print(create_circle_shape(attributes_dict).global_position)
					#self.get_scene().add_child(create_circle_shape(attributes_dict))
					var shape = create_circle_shape(attributes_dict)
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()
				"path":
					var shape = create_path_shape(attributes_dict)
					self.get_scene().add_child(shape)
					shape.owner = self.get_scene()


func create_rect_shape(attributes_dict: Dictionary) -> Panel:
	var panel := Panel.new()
	var style_box := StyleBoxFlat.new()
	panel.add_theme_stylebox_override("panel", style_box)
	
	for attribute in attributes_dict:
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
				style_box.bg_color = Color(attributes_dict[attribute])
			
	return panel

func create_circle_shape(attributes_dict: Dictionary) -> SVGCircle:
	var circle := SVGCircle.new()
	circle.set_circle_properties(attributes_dict)
	return circle

func create_path_shape(attributes_dict: Dictionary) -> SVGPath:
	var path := SVGPath.new()
	
	for attribute in attributes_dict:
		match attribute:
			"id":
				path.name = attributes_dict[attribute]
			"d":
				path.set_path_data(attributes_dict[attribute])
			"stroke":
				path.stroke_color = Color(attributes_dict[attribute])
			"stroke-width":
				path.stroke_width = float(attributes_dict[attribute])
			"fill":
				path.fill_color = Color(attributes_dict[attribute])
			"opacity":
				path.modulate.a = float(attributes_dict[attribute])
	
	return path
