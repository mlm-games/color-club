@tool
extends EditorScript

#Huge thanks to https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial for most of the "understanding" part

#TODO: remove if unnecessary
#class RectangleSVG:
	#var id: String
	#var 

var original_color_dict : Dictionary[StringName, Color] = {}


# Layer class to group SVG elements
class SVGLayer extends Control:
	var layer_name: String
	
	func _init(name: String = "SVGLayer") -> void:
		self.name = name
		layer_name = name

func _run() -> void:
	var parser := XMLParser.new()
	parser.open("res://assets/art/pic2.svg")
	
	# Create root node for the SVG
	var svg_root := Control.new()
	svg_root.name = "SVGRoot"
	self.get_scene().add_child(svg_root)
	svg_root.owner = self.get_scene()
	
	# Current layer tracking
	var current_layer := SVGLayer.new("DefaultLayer")
	svg_root.add_child(current_layer)
	current_layer.owner = self.get_scene()
	
	# Stack for handling nested groups
	var layer_stack := [current_layer]
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			var attributes_dict := {}
			
			for idx in range(parser.get_attribute_count()):
				attributes_dict[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
			
			# Handle SVG structure elements
			match node_name:
				"svg":
					#TODO: Update root node with SVG attributes if needed
					pass
				"g":
					# Create a new layer/group
					var new_layer := SVGLayer.new()
					if attributes_dict.has("id"):
						new_layer.name = attributes_dict["id"]
						new_layer.layer_name = attributes_dict["id"]
					else:
						new_layer.name = "Layer_" + str(layer_stack.size())
					
					# Add to current layer
					layer_stack.back().add_child(new_layer)
					new_layer.owner = self.get_scene()
					
					# Push to stack
					layer_stack.push_back(new_layer)
					current_layer = new_layer
				"rect":
					var shape := create_rect_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self.get_scene()
				"circle":
					var shape := create_circle_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self.get_scene()
				"path":
					var shape := create_path_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self.get_scene()
				"line", "ellipse", "polyline", "polygon":
					push_warning(node_name + " hasn't been fully implemented yet")
		
		 #Handle closing tags for groups
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "g":
				layer_stack.pop_back()
				current_layer = layer_stack.back()

static func create_rect_shape(attributes_dict: Dictionary) -> Panel:
	var panel := Panel.new()
	var style_box := StyleBoxFlat.new()
	
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
			"transform":
				pass
				#panel.pivot_offset = panel.size/2
				#var self_transform := SVGUtils.parse_transform(attributes_dict[attribute], panel)
			"style":
				var styles := SVGUtils.analyse_style(attributes_dict[attribute])
				apply_css_styles_for_rect(styles, style_box)
			
	style_box.anti_aliasing_size = 0.1
	panel.add_theme_stylebox_override("panel", style_box)
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


#TODO: Do it indivdually per object shape by passing the shape also as an parameter



static func apply_css_styles_for_rect(styles: Dictionary, style_box: StyleBox):
	if styles.has("stroke"):
		#print("adding default stroke")
		styles.get_or_add("stroke-width", 1.0)
	for attribute:StringName in styles:
		match attribute:
			"stroke":
				print("Color: "); print(Color.html(styles[attribute]))
				style_box.border_color = Color.html(styles[attribute])
				
			"stroke-width":
				style_box.border_width_left = float(styles[attribute])
				style_box.border_width_right = float(styles[attribute])
				style_box.border_width_top = float(styles[attribute])
				style_box.border_width_bottom = float(styles[attribute])
			"fill":
				style_box.bg_color = Color.html(styles[attribute])
			var unimplemented_attribute:
				push_warning("Not yet implemented, ", unimplemented_attribute)
