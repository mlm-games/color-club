extends Control

static var local_pics : PackedStringArray = DirAccess.get_files_at(ART_FOLDER)

var tween : Tween

func _on_button_pressed() -> void:
	on_play_clicked()
	

func on_play_clicked() -> void:
	tween = get_tree().create_tween()
	tween.tween_property(%PlayButton, "modulate", Color.TRANSPARENT, 0.2)
	await tween.finished
	%PlayButton.hide()
	
	tween.tween_property(%PicContainer, "modulate", Color.WHITE, 0.2)
	populate_pics()
	
	#add_child(SVGPath.new(SVGPath.Type.CURVE_TO, 0, 0 ,20 ,20 ,30, 40))

func populate_pics() -> void:
	for pic_path: StringName in local_pics:
		var pic_button := LevelButtonsScene.instantiate()
		if pic_path.ends_with(".import"):
			continue
		pic_button.icon = load(ART_FOLDER + pic_path)
		%PicContainer.add_child(pic_button)
		





#region Ideas
#HACK: Have a seperate mode where the user is able to color the images on his own (get images from file picker or from vectorassests copyright free online). And share the colored images if needed...
#endregion

const ART_FOLDER = "res://assets/art/"
const LevelButtonsScene = preload("uid://df6stj0kgo1jl")
