class_name UiPalette
extends Resource
## The theme's colours, in one place (ui/palette.tres), from the approved mockup's reference file
## (port_kit/high-noon-port-kit/style/ui-reference/high_noon_ui_reference.py): ink #3B2416, cream #F7E8C8,
## orange #F08A24, teal #2E7A80, gold #FFC83D, red #D9342B. tools/build_ui_theme.gd builds ui/ui_theme.tres
## from it; the generated art's own colours (faces, highlights, bases) are set in tools/make_ui_art.gd.
##   Godot --headless --path . -s res://tools/build_ui_theme.gd
## Materials: parchment for information (cards), orange for the one main action, teal for the rest,
## gold only for stars and coins, red only for danger and failure.

@export var outline := Color("3b2416")
@export var parchment := Color("f7e8c8")
## A deeper cream.
@export var parchment_deep := Color("e6cb98")
## The secondary colour (teal; the mockup has no wood buttons).
@export var wood := Color("2e7a80")
@export var primary := Color("f08a24")
@export var gold := Color("ffc83d")
@export var danger := Color("d9342b")
## Text on parchment, and its quieter shade for hints.
@export var ink := Color("3b2416")
@export var ink_soft := Color("6b4a33")
## Text on orange and teal, titles over the scene.
@export var cream := Color("f7e8c8")
## The HUD's translucent pills over the scene, and the dim behind cards.
@export var hud_pill := Color(0.231, 0.141, 0.086, 0.55)
@export var dim := Color(0.09, 0.05, 0.03, 0.35)
@export var shadow := Color(0.12, 0.06, 0.03, 0.35)
## (Kept for older screens.)
@export var press_darken := 0.18
