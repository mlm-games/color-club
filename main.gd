extends ColorRect

const ColorPicScene = preload("uid://d23haj46gk4ea")
var pics : Array = []

var tween

func _on_button_pressed() -> void:
	on_play_clickd()
	

func on_play_clickd() -> void:
	tween = get_tree().create_tween()
	tween.tween_property(%PlayButton, "modulate", Color.TRANSPARENT, 0.2)
	%PlayButton.hide()
	populate_pics()
	#add_child(SVGPath.new(SVGPath.Type.CURVE_TO, 0, 0 ,20 ,20 ,30, 40))

func populate_pics() -> void:
	add_child(ColorPicScene.instantiate())


#var coloring_game: SVGColoringGame
var color_palette: ColorPalette

func _ready() -> void:
	pass
	#add_child(load_svg)
	#coloring_game = SVGColoringGame.new()
	#add_child(coloring_game)
	#
	## Load SVG and extract colors
	#coloring_game.load_svg("res://assets/coloring_page.svg")






#region Ideas
#HACK: Have a seperate mode where the user is able to color the images on his own. And share the colored images if needed...
#endregion
