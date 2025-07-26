extends AcceptDialog #NOTE: Vunerable svgs are a problem if the user adds them without verifying, recommend from trusted websites somewhere

@onready var url_input: LineEdit = $VBox/URLInput
@onready var name_input: LineEdit = $VBox/NameInput
@onready var load_button: Button = $VBox/LoadButton
@onready var preview_rect: TextureRect = $VBox/PreviewRect

signal svg_added(url: String, svg_content: String, name: String)

var loaded_svg_content: String = ""

func _ready() -> void:
	title = "Add Online SVG"
	get_ok_button().disabled = true
	get_ok_button().text = "Add"
	
	load_button.pressed.connect(_on_load_pressed)
	get_ok_button().pressed.connect(_on_add_pressed)

func _on_load_pressed() -> void:
	var url = url_input.text.strip_edges()
	if url.is_empty():
		return
	
	load_button.disabled = true
	load_button.text = "Loading..."
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))
	
	var error = http_request.request(url)
	if error != OK:
		load_button.text = "Load Failed"
		load_button.disabled = false
		http_request.queue_free()

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest) -> void:
	http_request.queue_free()
	
	if response_code == 200:
		loaded_svg_content = body.get_string_from_utf8()
		
		# Validate SVG
		if loaded_svg_content.contains("<svg") and loaded_svg_content.contains("</svg>"):
			# Show preview
			var svg_texture = SVGTexture.new()
			svg_texture.set_source(loaded_svg_content)
			svg_texture.base_scale = 0.3
			preview_rect.texture = svg_texture
			
			load_button.text = "Loaded!"
			get_ok_button().disabled = false
			
			# Auto-fill name if empty
			if name_input.text.is_empty():
				name_input.text = url_input.text.get_file().get_basename()
		else:
			load_button.text = "Invalid SVG"
			load_button.disabled = false
	else:
		load_button.text = "Load Failed: Response code: " + str(response_code) #FIXME: currently gives the response code 0 in web debug, (no conn) disable for now
		load_button.disabled = false

func _on_add_pressed() -> void:
	if not loaded_svg_content.is_empty():
		svg_added.emit(url_input.text, loaded_svg_content, name_input.text)
