class_name UiPalette
extends Resource
## Every UI colour, in one place (ui/palette.tres). tools/build_ui_theme.gd builds ui/ui_theme.tres from
## it: retune a colour here, re-run the builder, and every screen follows.
##   Godot --headless --path . -s res://tools/build_ui_theme.gd
## Materials: parchment for information (cards), wood brown for buttons only, the primary orange for
## the one main action, gold only for stars and coins, red only for danger and failure.

@export var outline := Color("3b2416")
@export var parchment := Color("f4e4c1")
## A deeper parchment, for chips sitting on a card.
@export var parchment_deep := Color("e6cf9f")
@export var wood := Color("8b5a2b")
@export var primary := Color("e07b2e")
@export var gold := Color("f2b630")
@export var danger := Color("c8372d")
## Text on parchment, and its quieter shade for hints.
@export var ink := Color("3b2416")
@export var ink_soft := Color("6b4a33")
## Text on wood, orange and over the scene.
@export var cream := Color("fff4dc")
## The HUD's translucent pills over the scene, and the dim behind cards.
@export var hud_pill := Color(0.231, 0.141, 0.086, 0.55)
@export var dim := Color(0.09, 0.05, 0.03, 0.35)
@export var shadow := Color(0.12, 0.06, 0.03, 0.35)
## How much a pressed button darkens.
@export var press_darken := 0.18
