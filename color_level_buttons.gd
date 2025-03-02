class_name SVGImage extends Panel

#Huge thanks to https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial for most of the "understanding" part

#TODO: remove if unnecessary
#class RectangleSVG:
	#var id: String
	#var 

const SVG_SIZE_XY = 400


# Layer class to group SVG elements
class SVGLayer extends Control:
	var layer_name: String
	
	@warning_ignore("shadowed_variable_base_class")
	func _init(name: String = "SVGLayer") -> void:
		self.name = name
		layer_name = name

func _ready() -> void:
	var parser := XMLParser.new()
	parser.open("res://assets/art/pic2.svg")
	
	# Create root node for the SVG
	var svg_root := Control.new()
	svg_root.name = "SVGRoot"
	self.add_child(svg_root)
	svg_root.owner = self
	

	# Make sure the scale is proportional
	#var scale_factor = min(self.size.x, self.size.y) / min(size.x/2, size.y/2)
	#svg_root.scale = Vector2(scale_factor, scale_factor)
	
	# Current layer tracking
	var current_layer := SVGLayer.new("DefaultLayer")
	svg_root.add_child(current_layer)
	current_layer.owner = self
	
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
					var width = 100  # Default fallback width
					var height = 100  # Default fallback height
					var viewBox = ""
					
					if attributes_dict.has("width"):
						width = parse_dimension(attributes_dict["width"])
					elif attributes_dict.has("height"):
						height = parse_dimension(attributes_dict["height"])
					elif attributes_dict.has("viewBox"):
						viewBox = attributes_dict["viewBox"]
						
					# If no direct width/height but has viewBox, use that
					if (width == 100 or height == 100) and viewBox != "":
						var parts = viewBox.split(" ")
						if parts.size() >= 4:
							# viewBox format: min-x min-y width height
							width = float(parts[2])
							height = float(parts[3])
						svg_root.scale = (Vector2.ONE * SVG_SIZE_XY) / Vector2(width, height) #(get_viewport_rect().size/16)
					else:
						# If we get here, we couldn't find dimensions
						push_warning("Could not extract dimensions from SVG file")
						svg_root.scale = (Vector2.ONE * SVG_SIZE_XY) / Vector2(100, 100) # Default fallback size
					
					#HACK: This centers the svg drawing somehow (for 1920, 1080; use SVG_XY = 700 with pivot offset 25,25)
					svg_root.set_anchors_preset(Control.PRESET_CENTER)
					svg_root.pivot_offset -= Vector2(105, 25)
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
					new_layer.owner = self
					
					# Push to stack
					layer_stack.push_back(new_layer)
					current_layer = new_layer
				"rect":
					var shape := create_rect_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self
				"circle":
					var shape := create_circle_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self
				"path":
					var shape := create_path_shape(attributes_dict)
					current_layer.add_child(shape)
					shape.owner = self
				"line", "ellipse", "polyline", "polygon":
					push_warning(node_name + " hasn't been fully implemented yet")
		
		 #Handle closing tags for groups
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "g":
				layer_stack.pop_back()
				current_layer = layer_stack.back()
	
	
	get_tree().get_first_node_in_group("HUD").colors_for_image = remove_fill_colors_and_add_to_dict(svg_root)

static func create_rect_shape(attributes_dict: Dictionary) -> Panel:
	var panel := ClickablePanel.new()
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


#TODO: add similar named svg variables to rect shape (from circle or path) and get styles for all using SVGUtils style function
static func apply_css_styles_for_rect(styles: Dictionary, style_box: StyleBox) -> void:
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


func parse_dimension(value: String) -> float:
		# Remove units like px, mm, etc.
		var numeric_part = value.replace("px", "").replace("mm", "").replace("cm", "").replace("pt", "")
		return float(numeric_part)

#
static func remove_fill_colors_and_add_to_dict(root_node: Control) -> Dictionary[Color, Array]:
	var colors_object_dict :Dictionary[Color, Array]  = {}
	##Add fill color to the colors array
	for child in root_node.get_children():
		if child is SVGLayer:
			for svg_layer_child in child.get_children():
				if svg_layer_child is Panel or svg_layer_child is Node2D: #FIXME: Replace with base svg node?
					if colors_object_dict.has(svg_layer_child.fill_color):
						colors_object_dict[svg_layer_child.fill_color].append(svg_layer_child)
					else:
						colors_object_dict.get_or_add(svg_layer_child.fill_color, [svg_layer_child,])
					svg_layer_child.fill_color = Color.WHITE
	
	return colors_object_dict

#func add_color_and_object_to_dict(dict: Dictionary, color: Color, object: CanvasItem):



#region old_stuff
#var SourcePath: String = texture_normal.resource_path # Store the path of the SVG this sprite is using.
#@onready var SVGScaleMaster: Node2D = SvgScaler  # $".."  # A reference to the node containing the SVG Scaling script, in this case it is the root node

#func _ready() -> void:
	#SVGScaleMaster.connect("rescale",_on_rescale) # Connect to the root node's rescale signal
	#SVGScaleMaster.add_svg(SourcePath) # Add a new entry to the SVG Tracker in the SVG Scale Master script if one does not already exist for this SVG.
	#SVGScaleMaster.SVGTracker[SourcePath] += [self] # Add self to list in the root node that keeps track of which nodes are using this SVG
#
#func _on_rescale(SVG:String,TEX:ImageTexture,AR:Vector2,LS:Vector2) -> void:
	#if SourcePath == SVG: # If the modified SVG is the same as the one this sprite is using
		#texture_normal = TEX # Update the displayed texture_normal with the re-scaled one
		##position.y = position.y/ LS.y * AR.y / get_window().content_scale_size.y # Keep relative sprite positioning on Y axis only
		#position = position / LS * AR / Vector2(get_window().content_scale_size) # Keep relative sprite positioning (works best if aspect ratio is locked)
#
#func _on_death() -> void:
	#SVGScaleMaster.remove_svg(SourcePath,self) # Remove self from tracking for the SVG Scaling script
	#call_deferred("free") # Mark for deletion at the next opportunity (safer than queue_free())
#endregion
