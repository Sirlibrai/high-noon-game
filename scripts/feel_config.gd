class_name FeelConfig
extends Resource
## Every feel value for shooting, in one place (data/feel.tres), so it can be tuned without touching
## logic: durations, hit-stop, shake, sound pitch, haptic patterns and the revolver's size and aim.
## FeedbackDirector reads it. Times are in seconds of real time (they ignore the game's time scale).
## Haptic patterns are lists of [delay ms, length ms, strength 0..1] pulses.

@export_group("Shot")
## The muzzle flash stays this long.
@export var muzzle_flash_time := 0.05
## The revolver turns toward the tap this fast, recoils (kick up and back, then return), then settles.
@export var aim_turn_time := 0.03
@export var recoil_peak_time := 0.025
@export var recoil_return_time := 0.12
@export var settle_delay := 0.25
@export var settle_time := 0.3
## The revolver and hand, drawn this much bigger than the art's size.
@export var gun_scale := 1.4
## How far the revolver may turn toward a tap (radians, added to the art's barrel angle): up, down.
@export var aim_range := Vector2(-0.45, 0.35)
## How hard each shot kicks (the weapon's kick is multiplied by this).
@export var recoil_strength := 1.0
@export var shot_pitch := Vector2(0.94, 1.06)
@export var shot_trauma := 0.12
@export var shot_haptic: Array = [[0, 10, 0.45]]

@export_group("Hit")
## The enemy flashes white, is knocked back (units) and squashed, then falls.
@export var hit_flash_time := 0.06
@export var knockback := 3.0
@export var knockback_time := 0.08
@export var squash := Vector2(1.15, 0.86)
@export var squash_time := 0.12
@export var hit_stop := 0.06
## The time scale during a hit-stop (a fraction of the scale before it).
@export var hit_stop_scale := 0.03
@export var hit_trauma := 0.22
@export var hit_pitch := Vector2(0.9, 1.1)
## A hit lands just after the shot's tick: a firm knock, clearly apart from it.
@export var hit_haptic: Array = [[45, 30, 1.0]]

@export_group("Miss")
@export var miss_dust := 12
@export var miss_pitch := Vector2(0.85, 1.15)
## A miss adds no haptic of its own (the shot's light tick alone), so it never blurs with a hit.
@export var miss_haptic: Array = []

@export_group("Blocked")
## Cover, iron or armour took it: sparks, a clank, a tiny shake and no hit-stop.
@export var blocked_sparks := 10
@export var blocked_trauma := 0.1
@export var blocked_pitch := Vector2(0.92, 1.08)
@export var blocked_haptic: Array = [[40, 8, 0.7], [85, 8, 0.7]]

@export_group("Explosion")
@export var explosion_flash := 0.6
@export var explosion_flash_time := 0.15
@export var explosion_debris := 70
@export var explosion_trauma := 0.85
@export var explosion_hit_stop := 0.04
@export var explosion_haptic: Array = [[0, 120, 1.0], [150, 80, 0.6]]

@export_group("Bosses")
@export var boss_armour_trauma := 0.18
@export var boss_crack_trauma := 0.4
@export var boss_crack_haptic: Array = [[40, 25, 1.0], [90, 25, 1.0]]
@export var boss_hit_stop := 0.08
@export var boss_hit_trauma := 0.35
@export var boss_hit_haptic: Array = [[45, 40, 1.0]]
## The boss's final shot: the longest hit-stop, a big shake and a long haptic.
@export var boss_final_hit_stop := 0.15
@export var boss_defeat_trauma := 0.9
@export var boss_defeat_haptic: Array = [[45, 60, 1.0], [140, 140, 0.8]]

@export_group("Player hit")
@export var heart_pulse_scale := 1.5
@export var heart_pulse_time := 0.35
@export var vignette_alpha := 0.75
@export var vignette_time := 0.4
@export var player_hit_trauma := 0.45
@export var player_hit_haptic: Array = [[0, 80, 1.0]]

@export_group("Shake")
## Trauma-based: events add trauma (0..1), which decays at this rate a second; the shake is trauma
## squared times max_offset (units), from smooth noise at shake_speed.
@export var trauma_decay := 2.2
@export var max_offset := 6.0
@export var max_angle := 0.0
@export var shake_speed := 28.0
## With the reduced-shake setting on, every shake is multiplied by this.
@export var reduced_shake := 0.25

@export_group("Debug")
## The slow-motion debug toggle runs the game at this speed.
@export var slow_motion := 0.25
