class_name FxLayer
extends Node2D
## Particles and explosions as AssetSprites, stepped with the prototype's
## per-frame physics (in gameplay units). A particle kind ("fx/blood") is a
## manifest animation whose frames are colour variants, chosen like the
## prototype's `colors[i % colors.length]`.

## Explosions last this many steps in the rules (the out-of-ammo check waits for them).
const BOOM_STEPS := 30

var ppu := 2.0
var parts: Array = []
var booms: Array = []
var _boom_layer := Node2D.new()
var _part_layer := Node2D.new()


func _ready() -> void:
	add_child(_boom_layer)
	add_child(_part_layer)


func particle(kind: String, variant: int, x: float, y: float, vx: float, vy: float, life: int, floating := false) -> void:
	var s := AssetSprite.make(kind, _part_layer)
	s.show_frame(variant)
	s.position = Vector2(roundf(x), roundf(y)) * ppu
	parts.append({"node": s, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "float": floating})


func burst(x: float, y: float, n: int, kind: String, spd := 1.5, up := 1.0) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf() * spd + 0.3
		particle(kind, i, x, y, cos(a) * s, sin(a) * s - up, 20 + randi() % 20)


func explosion(x: float, y: float) -> void:
	var s := AssetSprite.make("fx/explosion", _boom_layer)
	s.show_frame(0)
	s.position = Vector2(x, y) * ppu
	booms.append({"node": s, "t": 0})


func step() -> void:
	for q in parts:
		q.vy += -0.008 if q.float else 0.12
		q.x += q.vx
		q.y += q.vy
		q.life -= 1
		q.node.position = Vector2(roundf(q.x), roundf(q.y)) * ppu
	for q in parts.filter(func(q): return q.life <= 0):
		q.node.queue_free()
	parts = parts.filter(func(q): return q.life > 0)
	for b in booms:
		b.t += 1
		var frames := Assets.frame_count("fx/explosion")
		b.node.show_frame(mini(b.t * frames / BOOM_STEPS, frames - 1))
	for b in booms.filter(func(b): return b.t >= BOOM_STEPS):
		b.node.queue_free()
	booms = booms.filter(func(b): return b.t < BOOM_STEPS)
