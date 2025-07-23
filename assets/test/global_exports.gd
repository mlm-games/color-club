class_name GlobalExports extends Node

enum Audio {
	Win,
	Click,
	Hover,
	ShapeColored,
	BGMusic
}


@export var Sounds : Dictionary[StringName, AudioStreamWAV] = {
	Win = AudioStreamWAV.new(),
	Click = AudioStreamWAV.new(),
	Hover = AudioStreamWAV.new(),
	LittleWin = AudioStreamWAV.new(),
}

func get_enum_name():
	pass
