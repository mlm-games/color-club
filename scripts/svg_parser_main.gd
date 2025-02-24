@tool
extends EditorScript

#TODO: remove if unnecessary
#class RectangleSVG:
	#var id: String
	#var 

var original_color_dict : Dictionary[StringName, Color] = {}

func _run() -> void:
	var parser = XMLParser.new()
	parser.open("res://icon.svg")
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
					#create_rect_shape(attributes_dict)
					print(create_rect_shape(attributes_dict).global_position)
				

func create_rect_shape(attributes_dict: Dictionary) -> ColorRect:
	var rect: ColorRect = ColorRect.new() 
	for attribute in attributes_dict:
		match attribute:
			"id": 
				rect.name = attributes_dict[attribute]
			"x":
				rect.position.x = float(attributes_dict[attribute])
			"y":
				rect.position.y = float(attributes_dict[attribute])
			"width":
				rect.size.x = float(attributes_dict[attribute])
			"height":
				rect.size.y = float(attributes_dict[attribute])
			"opacity":
				rect.modulate.a = float(attributes_dict[attribute])
			"rx":
				# Handle rounded corners later... (ColorRect does not support this directly)
				pass
			"ry":
				# Handle rounded corners later... (ColorRect does not support this directly)
				pass
			"fill":
				#TODO: Add smooth anim to coloring
				
				rect.color = Color(attributes_dict[attribute])

	return rect
