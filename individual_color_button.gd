extends Button

var color: Color:
	set(val):
		color = val
		$ColorRect.color = color
