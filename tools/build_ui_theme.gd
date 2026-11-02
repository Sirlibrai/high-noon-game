extends SceneTree
## Builds ui/ui_theme.tres (the project's theme) from ui/palette.tres and the generated art in
## assets/ui_art (tools/make_ui_art.gd), matching the approved mockup:
##   Godot --headless --path . -s res://tools/build_ui_theme.gd
## Type variations: Panel (the torn parchment card; Card and InfoPanel are the same), Strip (the pause
## menu's tall strip), PillOrange and PillTeal (pill buttons: Button, PrimaryButton and BigPrimaryButton are
## orange; GhostButton, SecondaryButton and SmallGhostButton teal), RoundOrange and RoundTeal (round icon
## buttons; IconButton is orange), Chip (teal slabs; Pill is the same), OfficeTag, OfficeTagSoon (cream paper
## tags), OfficeTagPrimary (the orange one), Badge (the teal level-number disc), and Heading, HeadingDanger
## and BigTitle (Rye with a thick dark brown outline and a hard shadow straight down). Pressed buttons show
## their face sunk into the base (the pressed art) and their label moves down with it.
## Fonts: Rye for big titles, Lilita One for buttons, labels, chips and numbers.
## Nine-slice margins are in design pixels: the game swaps each texture for one that reports half its
## pixel size (Assets._halve_ui_art), so the 2x art draws sharp at its design size.
##
## The wanted posters, the CAPTURED stamp, the telegram and the office's own styles are copied unchanged
## from ui/theme.tres, with the fonts they had pinned.

const SOURCE := "res://ui/theme.tres"
const OUT := "res://ui/ui_theme.tres"
const PALETTE := "res://ui/palette.tres"
const ART := "res://assets/ui_art/"
const RYE := "res://ui/fonts/Rye-Regular.ttf"
const LILITA := "res://ui/fonts/LilitaOne-Regular.ttf"
const LORA := "res://ui/fonts/Lora-Variable.ttf"
## Minimum text size (design pixels; 26 is about 13.5 points on the smallest landscape iPhone).
const MIN_TEXT := 26
## How far a pressed face sinks (design pixels), as drawn by make_ui_art.gd.
const PILL_DEPTH := 10
const ROUND_DEPTH := 8
## Types the posters, stamps, telegram and old office ledger use: left exactly as they were.
const KEEP := ["Poster", "PosterWanted", "PosterName", "PosterCrime", "PosterReward", "PortraitFrame", "WallPoster",
	"PosterBigName", "PosterTitle", "RewardBanner", "RewardLabel", "StampFaded", "StampFadedLabel", "PosterStars",
	"Telegram", "TelegramText", "Stamp", "StampLabel", "DeskPlaque", "DeskLedger", "DeskTitle", "DeskSub", "DeskKey",
	"DeskValue", "Plaque", "PlaqueSoon", "ParchmentHeading", "Logo", "InkTitle", "TapPrompt", "Title"]

var P: UiPalette
var lilita: FontFile
var rye: FontFile


func _init() -> void:
	P = load(PALETTE)
	var old: Theme = load(SOURCE)
	var t := Theme.new()
	lilita = load(LILITA)
	rye = load(RYE)
	t.default_font = lilita
	t.default_font_size = 30
	for type in KEEP:
		_copy(old, t, type)
		if not old.get_font_list(type).has("font") and not _inherits_font(old, type):  # (has_font counts the default font)
			t.set_font("font", type, old.default_font if old.default_font != null else load(LORA))
	# Pill buttons.
	for type in ["Button", "PillOrange", "PrimaryButton", "BigPrimaryButton", "DangerButton"]:
		_pill(t, type, "orange", 48 if type == "BigPrimaryButton" else 36)
	for type in ["PillTeal", "GhostButton", "SecondaryButton", "SmallGhostButton"]:
		_pill(t, type, "teal", 30 if type == "SmallGhostButton" else 34)
	# Round icon buttons.
	for type in ["RoundOrange", "IconButton"]:
		_round(t, type, "orange")
	_round(t, "RoundTeal", "teal")
	# Panels.
	_nine(t, "Panel", "panel", "panel_cream", Rect2(44, 40, 44, 48), Rect2(50, 28, 50, 36))
	for type in ["Card", "InfoPanel"]:
		t.set_type_variation(type, "Panel")
	_nine(t, "Strip", "panel", "panel_strip", Rect2(30, 30, 30, 38), Rect2(22, 18, 22, 24))
	_nine(t, "Chip", "panel", "chip_teal", Rect2(16, 14, 16, 18), Rect2(16, 4, 16, 8))
	t.set_type_variation("Pill", "Chip")
	for type in ["ChipLabel", "PillLabel"]:
		_label(t, type, P.cream, 26, lilita)
	_nine(t, "Badge", "panel", "badge_teal", Rect2(0, 0, 0, 0), Rect2(16, 10, 16, 18))
	_label(t, "BadgeLabel", P.cream, 52, rye)
	_outlined(t, "BadgeLabel", 10, 4)
	# The dim behind cards, and no panel behind the HUD.
	var dim := StyleBoxFlat.new()
	dim.bg_color = P.dim
	t.set_type_variation("Shade", "Panel")
	t.set_stylebox("panel", "Shade", dim)
	for type in ["HudPill", "HudPanel", "HudPlaque"]:
		t.set_type_variation(type, "PanelContainer")
		t.set_stylebox("panel", type, StyleBoxEmpty.new())
	# Labels: ink Lilita on parchment; Rye titles in orange (red for failure, cream over the scene).
	t.set_color("font_color", "Label", P.ink)
	t.set_font_size("font_size", "Label", 30)
	_label(t, "Heading", P.primary, 64, rye)
	_outlined(t, "Heading", 12, 6)
	_label(t, "HeadingDanger", P.danger, 64, rye, "Heading")
	_label(t, "BigTitle", P.cream, 128, rye, "Heading")
	_outlined(t, "BigTitle", 20, 10)
	_label(t, "Tip", P.ink, 30, lilita)
	_label(t, "Hint", P.ink_soft, MIN_TEXT + 2, lilita)
	_label(t, "Pay", P.ink, 48, lilita)
	_label(t, "AdTag", P.ink_soft, MIN_TEXT, lilita)
	_label(t, "HudLabel", P.cream, 28, lilita)
	_outlined(t, "HudLabel", 8, 0)
	_label(t, "HudPlaqueLabel", P.cream, 28, lilita, "HudLabel")
	_label(t, "HudCount", P.cream, 48, lilita)  # the HUD's cartridge count in a long chase
	_outlined(t, "HudCount", 12, 4)
	_label(t, "Callout", P.cream, 96, rye)
	_outlined(t, "Callout", 18, 8)
	_label(t, "CalloutSmall", P.cream, 54, rye, "Callout")
	_outlined(t, "CalloutSmall", 12, 5)
	# The office's paper tags; the Bounty board's is the orange one. The wallet is a tag too.
	_tag(t, "OfficeTag", "tag_cream", P.ink)
	_tag(t, "OfficeTagSoon", "tag_cream", P.ink_soft)
	_tag(t, "OfficeTagPrimary", "tag_orange", P.cream)
	t.set_font_size("font_size", "OfficeTagPrimary", 34)
	t.set_color("font_outline_color", "OfficeTagPrimary", P.outline)
	t.set_constant("outline_size", "OfficeTagPrimary", 8)
	_tag(t, "Wallet", "tag_cream", P.ink)
	t.set_font_size("font_size", "Wallet", 36)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:  # room for the coin breaking out of its left edge
		var w := (t.get_stylebox(s, "Wallet") as StyleBoxTexture).duplicate() as StyleBoxTexture
		w.content_margin_left = 84
		w.content_margin_right = 26
		w.content_margin_top = 14
		w.content_margin_bottom = 18
		t.set_stylebox(s, "Wallet", w)
	t.set_type_variation("Hotspot", "Button")
	var none := StyleBoxEmpty.new()
	var glow := StyleBoxFlat.new()  # pressed: a warm highlight over the painted object
	glow.bg_color = Color(1.0, 0.85, 0.55, 0.22)
	glow.set_corner_radius_all(18)
	glow.border_color = Color(1.0, 0.9, 0.6, 0.7)
	glow.set_border_width_all(3)
	for s in ["normal", "hover", "disabled", "focus"]:
		t.set_stylebox(s, "Hotspot", none)
	t.set_stylebox("pressed", "Hotspot", glow)
	t.set_type_variation("TapArea", "Button")
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(s, "TapArea", none)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 16)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(P.outline, 0.6)
	back.set_corner_radius_all(999)
	var fill := back.duplicate() as StyleBoxFlat
	fill.bg_color = P.gold
	t.set_stylebox("background", "ProgressBar", back)
	t.set_stylebox("fill", "ProgressBar", fill)
	var err := ResourceSaver.save(t, OUT)
	print("ui_theme.tres saved: ", err == OK)
	quit()


func _copy(from: Theme, to: Theme, type: String) -> void:
	if from.get_type_variation_base(type) != &"":
		to.set_type_variation(type, from.get_type_variation_base(type))
	for dt in [Theme.DATA_TYPE_COLOR, Theme.DATA_TYPE_CONSTANT, Theme.DATA_TYPE_FONT, Theme.DATA_TYPE_FONT_SIZE, Theme.DATA_TYPE_ICON, Theme.DATA_TYPE_STYLEBOX]:
		for item in from.get_theme_item_list(dt, type):
			to.set_theme_item(dt, item, type, from.get_theme_item(dt, item, type))


func _inherits_font(th: Theme, type: String) -> bool:
	var base := th.get_type_variation_base(type)
	var seen := {}
	while base != &"" and not seen.has(base):  # (guarded: a chain of bases could loop)
		seen[base] = true
		if th.get_font_list(base).has("font"):
			return true
		base = th.get_type_variation_base(base)
	return false


## A nine-slice from the generated art. margins: the texture's slice margins (left, top, right, bottom),
## content: the content margins (design pixels).
func _box(art: String, margins: Rect2, content: Rect2) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(ART + art + ".png")
	s.texture_margin_left = margins.position.x
	s.texture_margin_top = margins.position.y
	s.texture_margin_right = margins.size.x
	s.texture_margin_bottom = margins.size.y
	s.content_margin_left = content.position.x
	s.content_margin_top = content.position.y
	s.content_margin_right = content.size.x
	s.content_margin_bottom = content.size.y
	return s


func _nine(t: Theme, type: String, slot: String, art: String, margins: Rect2, content: Rect2) -> void:
	t.set_type_variation(type, "PanelContainer")
	t.set_stylebox(slot, type, _box(art, margins, content))


## A button whose face sinks into its base when pressed: the pressed art, and its label lower by the depth.
func _press_styles(t: Theme, type: String, up: StyleBoxTexture, down: StyleBoxTexture) -> void:
	if type != "Button":
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, up)
	t.set_stylebox("hover", type, up)
	t.set_stylebox("pressed", type, down)
	t.set_stylebox("hover_pressed", type, down)
	var off := up.duplicate() as StyleBoxTexture
	off.modulate_color = Color(0.75, 0.72, 0.68, 0.75)
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


func _pill(t: Theme, type: String, kind: String, size: int) -> void:
	var m := Rect2(48, 30, 48, 40)
	var up := _box("pill_%s_up" % kind, m, Rect2(40, 22, 40, 22 + PILL_DEPTH))
	var down := _box("pill_%s_down" % kind, m, Rect2(40, 22 + PILL_DEPTH, 40, 22))
	_press_styles(t, type, up, down)
	t.set_font("font", type, lilita)
	t.set_font_size("font_size", type, size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, P.cream)
	t.set_color("font_disabled_color", type, Color(P.cream, 0.7))
	t.set_color("font_outline_color", type, P.outline)
	t.set_constant("outline_size", type, maxi(8, int(size * 0.22)))
	t.set_constant("h_separation", type, 10)


## A round button: the art stretched whole (no slices), the icon centred on the face.
func _round(t: Theme, type: String, kind: String) -> void:
	var up := _box("round_%s_up" % kind, Rect2(), Rect2(20, 16, 20, 16 + ROUND_DEPTH))
	var down := _box("round_%s_down" % kind, Rect2(), Rect2(20, 16 + ROUND_DEPTH, 20, 16))
	_press_styles(t, type, up, down)
	t.set_constant("icon_max_width", type, 44)


func _tag(t: Theme, type: String, art: String, text: Color) -> void:
	var s := _box(art, Rect2(16, 14, 16, 18), Rect2(18, 8, 18, 12))
	_press_styles(t, type, s, s)
	t.set_font("font", type, lilita)
	t.set_font_size("font_size", type, 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		t.set_color(c, type, text)
	t.set_constant("outline_size", type, 0)
	t.set_constant("h_separation", type, 8)
	t.set_constant("icon_max_width", type, 22)


func _label(t: Theme, type: String, colour: Color, size: int, font: Font, base := "Label") -> void:
	t.set_type_variation(type, base)
	t.set_color("font_color", type, colour)
	t.set_font_size("font_size", type, maxi(size, MIN_TEXT))
	t.set_font("font", type, font)


## A thick dark brown outline, and a hard shadow straight down (drop pixels) that carries the outline too.
func _outlined(t: Theme, type: String, outline: int, drop: int) -> void:
	t.set_color("font_outline_color", type, P.outline)
	t.set_constant("outline_size", type, outline)
	if drop > 0:
		t.set_color("font_shadow_color", type, P.outline)
		t.set_constant("shadow_offset_x", type, 0)
		t.set_constant("shadow_offset_y", type, drop)
		t.set_constant("shadow_outline_size", type, outline)
