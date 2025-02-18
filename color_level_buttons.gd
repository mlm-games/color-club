extends Sprite2D

var SourcePath: String = texture.resource_path # Store the path of the SVG this sprite is using.
@onready var SVGScaleMaster: Node2D = SvgScaler  # $".."  # A reference to the node containing the SVG Scaling script, in this case it is the root node

func _ready() -> void:
	SVGScaleMaster.connect("rescale",_on_rescale) # Connect to the root node's rescale signal
	SVGScaleMaster.add_svg(SourcePath) # Add a new entry to the SVG Tracker in the SVG Scale Master script if one does not already exist for this SVG.
	SVGScaleMaster.SVGTracker[SourcePath] += [self] # Add self to list in the root node that keeps track of which nodes are using this SVG

func _on_rescale(SVG:String,TEX:ImageTexture,AR:Vector2,LS:Vector2) -> void:
	if SourcePath == SVG: # If the modified SVG is the same as the one this sprite is using
		texture = TEX # Update the displayed texture with the re-scaled one
		#position.y = position.y/ LS.y * AR.y / get_window().content_scale_size.y # Keep relative sprite positioning on Y axis only
		position = position / LS * AR / Vector2(get_window().content_scale_size) # Keep relative sprite positioning (works best if aspect ratio is locked)

func _on_death() -> void:
	SVGScaleMaster.remove_svg(SourcePath,self) # Remove self from tracking for the SVG Scaling script
	call_deferred("free") # Mark for deletion at the next opportunity (safer than queue_free())
