class_name GlobalAudioExports extends AudioStreamPlayer

static var I : GlobalAudioExports

func _init() -> void:
	I = self
	max_polyphony = 100 

enum Sound {
	Win,
	Click,
	Hover,
	ShapeColored,
	ColorSelect,
	BGMusic
}


@export var Sounds : Dictionary[Sound, AudioStreamWAV] = {
}

func get_enum_name():
	pass


func play_ui_sound(sound: Sound) -> void:
	stream = Sounds.get(sound)
	play()
