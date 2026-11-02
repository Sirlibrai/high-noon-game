extends Node
## Native haptics. On iOS Godot's vibrate_handheld drives Core Haptics, and the
## amplitude maps to the haptic intensity; on Android it uses the vibrator
## (the export preset grants the VIBRATE permission).

var enabled := true
## The last pattern asked for (the tests check feedback with it).
var last_pattern: Array = []


func shot() -> void:
	_buzz(10, 0.35)


func hit() -> void:
	_buzz(25, 0.8)


func hurt() -> void:
	_buzz(80, 1.0)


func explosion() -> void:
	_buzz(60, 1.0)


## A pattern of pulses, [delay ms, length ms, strength 0..1] each, timed in real time (a hit-stop or the
## slow-motion debug view never delays them).
func pattern(pulses: Array) -> void:
	last_pattern = pulses
	for p in pulses:
		if int(p[0]) <= 0:
			_buzz(int(p[1]), float(p[2]))
		else:
			get_tree().create_timer(int(p[0]) / 1000.0, true, false, true).timeout.connect(_buzz.bind(int(p[1]), float(p[2])))


func _buzz(ms: int, amplitude: float) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
