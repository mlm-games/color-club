extends Node2D

signal rescale(File:String,OutTexture:ImageTexture,LastRes:Vector2, LastScale:Vector2) # Create a signal to be used to tell sprites when they need to update their texture and position, and send them the data to do so.

var SVGTracker: Dictionary = {} # A dictionary to keep track of which SVGs are in use, at what scale, and what nodes are using them.

@onready var MainWindow: Window = get_window() # Store window reference in variable because we will use it a lot.
@onready var DevelopmentResolution:Vector2 = Vector2(MainWindow.content_scale_size) # Original resolution of the project
@onready var ActiveResolution:Vector2 =  Vector2(MainWindow.size) # Buffer to store the last resolution used for scaling
var LastScale:Vector2 # Buffer to store last used scale value for both axis
var Bitmap: Image = Image.new() # Bitmap for SVG->Bitmap conversion

func _ready() -> void:
	get_tree().get_root().connect("size_changed",window_size_changed) # Hook up the size_changed event for the root to the window_size_changed function

func window_size_changed():
	LastScale = ActiveResolution / DevelopmentResolution # Store the last used scale for both axis
	ActiveResolution = MainWindow.size # Update Active Resolution
	for key in SVGTracker: # For every SVG being tracked by this script
		Bitmap.load_svg_from_buffer(SVGTracker[key][0],(ActiveResolution.y / DevelopmentResolution.y)*SVGTracker[key][1]) # Convert SVG to Bitmap with updated scaling settings
		rescale.emit(key,ImageTexture.create_from_image(Bitmap),ActiveResolution,LastScale) # Forward the SVG File Path, Bitmap(as texture), Window Resolution and Last Scale values to all nodes connected to the rescale signal.
		'''
		# Alternate way which does not require a signal connection, i'm not sure which is more efficient.
		for node in SVGTracker[key]: # For each node using SVG
			if node is Object: # Make sure it's actually a node (first 2 items in the array are never nodes, which is why this is needed)
				node._on_rescale(key,ImageTexture.create_from_image(Bitmap),ActiveResolution,LastScale) # Activate rescale function with all the relevant data (doing this actually does not require the signal to be connected)
		'''

func add_svg(file: String): # Adds a new SVG file to the tracking dictionary (Generally needs to be called from the child)
	if !SVGTracker.has(file): # Only run if the key does not already exist (svg not already being tracked)
		SVGTracker[file] = [FileAccess.get_file_as_bytes(file), get_import_scale(file)] # create dictionary Key:SVG File Path, Value: [SVG as bytes, Importer Scale Setting]


func remove_svg(file: String, node: Object): # Removes node from tracking dictionary, and deletes the svg from tracking if no nodes are using it.  (Generally needs to be called from the child)
	SVGTracker[file].remove_at(SVGTracker[file].find(node,2)) # Remove the target node from the list of nodes using the target SVG 
	if SVGTracker[file].size() < 3: # If no nodes are using this SVG anymore
		SVGTracker.erase(file) # Delete the SVG file from the tracking dictionary


func get_import_scale(file: String): # Gets the scale at which the SVG was imported into the editor.
	var ImportSettings: ConfigFile = ConfigFile.new() # Blank config file buffer
	ImportSettings.load(file+".import")	# Load import settings to config file buffer
	return ImportSettings.get_value("params","svg/scale") # Read import scale value
