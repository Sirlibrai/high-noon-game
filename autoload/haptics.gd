extends Node
## Native haptics. On iOS Godot's vibrate_handheld drives Core Haptics, and the
## amplitude maps to the haptic intensity; on Android it uses the vibrator
## (the export preset grants the VIBRATE permission).

var enabled := true


func shot() -> void:
	_buzz(10, 0.35)


func hit() -> void:
	_buzz(25, 0.8)


func hurt() -> void:
	_buzz(80, 1.0)


func explosion() -> void:
	_buzz(60, 1.0)


func _buzz(ms: int, amplitude: float) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
