extends SceneTree
## Builds ui/ui_theme.tres (the project's theme) from ui/palette.tres:
##   Godot --headless --path . -s res://tools/build_ui_theme.gd
## Flat styles only for the game's own UI: a solid fill, a thick dark brown outline, rounded corners and a
## soft drop shadow. Type variations: PrimaryButton (the one main action, orange), SecondaryButton (wood),
## InfoPanel (parchment, every card), Chip (facts on a card), HudPill (translucent, over the scene),
## OfficeTag (the office's labels) and IconButton (round). Older names (Button, GhostButton, Card,
## Pill...) map onto these. Pressed buttons are darker (and UiKit scales them down a little).
## Fonts: Rye for titles only; the system's sans-serif (SF Pro on iPhone) for everything else.
##
## The wanted posters, the CAPTURED stamp, the telegram and the office illustration's own styles are
## copied unchanged from ui/theme.tres, with the fonts they had pinned so nothing about them moves.

const SOURCE := "res://ui/theme.tres"
const OUT := "res://ui/ui_theme.tres"
const PALETTE := "res://ui/palette.tres"
const RYE := "res://ui/fonts/Rye-Regular.ttf"
const LORA := "res://ui/fonts/Lora-Variable.ttf"
## Minimum text sizes (design pixels on the 720-pixel-tall screen; 26 is about 13.5 points on the
## smallest landscape iPhone): body and chips, and button labels.
const MIN_TEXT := 26
const BUTTON_TEXT := 30
## Buttons are at least this tall (88 design pixels: 46 points on a 375-point-tall phone).
const TAP := 88
const OUTLINE := 3
const RADIUS := 14
## Types the posters, stamps, telegram and old office ledger use: left exactly as they were.
const KEEP := ["Poster", "PosterWanted", "PosterName", "PosterCrime", "PosterReward", "PortraitFrame", "WallPoster",
	"PosterBigName", "PosterTitle", "RewardBanner", "RewardLabel", "StampFaded", "StampFadedLabel", "PosterStars",
	"Telegram", "TelegramText", "Stamp", "StampLabel", "DeskPlaque", "DeskLedger", "DeskTitle", "DeskSub", "DeskKey",
	"DeskValue", "Plaque", "PlaqueSoon", "ParchmentHeading", "Logo", "InkTitle", "TapPrompt", "Title"]

var P: UiPalette
var sans: SystemFont
var sans_bold: SystemFont


func _init() -> void:
	P = load(PALETTE)
	var old: Theme = load(SOURCE)
	var t := Theme.new()
	var lora := load(LORA) as FontFile
	var rye := load(RYE) as FontFile
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["SF Pro Text", "Helvetica Neue", "Helvetica", "sans-serif"])
	sans.font_weight = 600
	sans_bold = sans.duplicate()
	sans_bold.font_weight = 800
	t.default_font = sans
	t.default_font_size = 30
	# The kept types: copied as they were. Those that used the old default font (Lora) keep it.
	for type in KEEP:
		_copy(old, t, type)
		if not old.has_font("font", type) and not _inherits_font(old, type):
			t.set_font("font", type, old.default_font if old.default_font != null else lora)
	# Office styles: the tags are rebuilt below; the hotspot gets a press highlight.
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Buttons.
	_button(t, "Button", P.primary, P.cream, BUTTON_TEXT, sans_bold)
	_button(t, "PrimaryButton", P.primary, P.cream, BUTTON_TEXT, sans_bold, "Button")
	_button(t, "SecondaryButton", P.wood, P.cream, BUTTON_TEXT, sans_bold, "Button")
	_button(t, "GhostButton", P.wood, P.cream, BUTTON_TEXT, sans_bold, "Button")
	_button(t, "SmallGhostButton", P.wood, P.cream, 28, sans_bold, "Button")
	_button(t, "DangerButton", P.danger, P.cream, BUTTON_TEXT, sans_bold, "Button")
	_button(t, "BigPrimaryButton", P.primary, P.cream, 38, sans_bold, "Button", 24)
	for type in ["Button", "PrimaryButton", "SecondaryButton", "GhostButton", "SmallGhostButton", "DangerButton", "BigPrimaryButton"]:
		t.set_color("font_outline_color", type, P.outline)
		t.set_constant("outline_size", type, 6)
	# Round icon buttons (the HUD's sound and pause): a wood circle.
	t.set_type_variation("IconButton", "Button")
	var circle := _flat(P.wood, 999, 22)
	circle.content_margin_top = 18
	circle.content_margin_bottom = 18
	circle.content_margin_left = 18
	circle.content_margin_right = 18
	t.set_stylebox("normal", "IconButton", circle)
	t.set_stylebox("hover", "IconButton", circle)
	t.set_stylebox("pressed", "IconButton", _darker(circle))
	t.set_stylebox("disabled", "IconButton", circle)
	t.set_constant("icon_max_width", "IconButton", 44)
	# The wallet: a translucent pill with the coin and a gold number.
	t.set_type_variation("Wallet", "Button")
	var wallet := _flat(P.hud_pill, 999, 0)
	wallet.content_margin_left = 20
	wallet.content_margin_right = 22
	wallet.content_margin_top = 24
	wallet.content_margin_bottom = 24
	wallet.shadow_size = 0
	t.set_stylebox("normal", "Wallet", wallet)
	t.set_stylebox("hover", "Wallet", wallet)
	t.set_stylebox("pressed", "Wallet", _darker(wallet))
	t.set_font("font", "Wallet", sans_bold)
	t.set_font_size("font_size", "Wallet", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Wallet", P.gold)
	t.set_color("font_outline_color", "Wallet", P.outline)
	t.set_constant("outline_size", "Wallet", 6)
	t.set_constant("icon_max_width", "Wallet", 36)
	t.set_constant("h_separation", "Wallet", 10)
	# Panels: parchment for information; chips; the dim behind cards; HUD pills.
	var paper := _flat(P.parchment, 22, 40)
	paper.content_margin_top = 22
	paper.content_margin_bottom = 22
	paper.border_width_left = 4
	paper.border_width_top = 4
	paper.border_width_right = 4
	paper.border_width_bottom = 4
	paper.shadow_size = 18
	paper.shadow_offset = Vector2(0, 8)
	for type in ["InfoPanel", "Card"]:
		t.set_type_variation(type, "PanelContainer")
		t.set_stylebox("panel", type, paper)
	var chip := _flat(P.parchment_deep, 999, 20)
	chip.content_margin_top = 6
	chip.content_margin_bottom = 6
	chip.border_width_left = 2
	chip.border_width_top = 2
	chip.border_width_right = 2
	chip.border_width_bottom = 2
	chip.shadow_size = 0
	for type in ["Chip", "Pill"]:
		t.set_type_variation(type, "PanelContainer")
		t.set_stylebox("panel", type, chip)
	for type in ["ChipLabel", "PillLabel"]:
		t.set_type_variation(type, "Label")
		t.set_font("font", type, sans_bold)
		t.set_font_size("font_size", type, 28)
		t.set_color("font_color", type, P.ink)
	var dim := StyleBoxFlat.new()
	dim.bg_color = P.dim
	t.set_type_variation("Shade", "Panel")
	t.set_stylebox("panel", "Shade", dim)
	var pill := _flat(P.hud_pill, 999, 16)
	pill.content_margin_top = 8
	pill.content_margin_bottom = 8
	pill.border_width_left = 0
	pill.border_width_top = 0
	pill.border_width_right = 0
	pill.border_width_bottom = 0
	pill.shadow_size = 0
	for type in ["HudPill", "HudPanel", "HudPlaque"]:
		t.set_type_variation(type, "PanelContainer")
		t.set_stylebox("panel", type, pill)
	# Labels: ink on parchment; Rye for headings only.
	t.set_color("font_color", "Label", P.ink)
	t.set_font_size("font_size", "Label", 30)
	_label(t, "Heading", P.ink, 56, rye)
	t.set_color("font_shadow_color", "Heading", Color(P.primary, 0.35))
	t.set_constant("shadow_offset_x", "Heading", 0)
	t.set_constant("shadow_offset_y", "Heading", 3)
	_label(t, "HeadingDanger", P.danger, 56, rye, "Heading")
	_label(t, "Tip", P.ink, 30, sans)
	_label(t, "Hint", P.ink_soft, MIN_TEXT + 2, sans)
	_label(t, "Pay", P.gold, 38, sans_bold)
	t.set_color("font_outline_color", "Pay", P.outline)
	t.set_constant("outline_size", "Pay", 8)
	_label(t, "AdTag", P.ink_soft, MIN_TEXT, sans_bold)
	_label(t, "HudLabel", P.cream, 28, sans_bold)
	t.set_color("font_outline_color", "HudLabel", P.outline)
	t.set_constant("outline_size", "HudLabel", 6)
	_label(t, "HudPlaqueLabel", P.cream, 28, sans_bold, "HudLabel")
	t.set_color("font_outline_color", "HudPlaqueLabel", P.outline)
	t.set_constant("outline_size", "HudPlaqueLabel", 6)
	# Callouts over the scene: Rye, cream, a thick outline.
	_label(t, "Callout", P.cream, 96, rye)
	t.set_color("font_outline_color", "Callout", P.outline)
	t.set_constant("outline_size", "Callout", 16)
	t.set_color("font_shadow_color", "Callout", P.shadow)
	t.set_constant("shadow_offset_y", "Callout", 6)
	_label(t, "CalloutSmall", P.cream, 54, rye, "Callout")
	# The office's labels: chips by the objects; the Bounty board's is the primary action.
	_office_tag(t, "OfficeTag", P.parchment, P.ink)
	_office_tag(t, "OfficeTagSoon", Color(P.parchment_deep, 0.92), P.ink_soft)
	_office_tag(t, "OfficeTagPrimary", P.primary, P.cream)
	t.set_font_size("font_size", "OfficeTagPrimary", 32)
	t.set_color("font_outline_color", "OfficeTagPrimary", P.outline)
	t.set_constant("outline_size", "OfficeTagPrimary", 6)
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
	t.set_type_variation("TapArea", "Button")  # an invisible, larger tap area round a small label
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(s, "TapArea", none)
	# Containers and bars.
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 18)
	var back := _flat(Color(P.outline, 0.6), 999, 0)
	back.shadow_size = 0
	var fill := _flat(P.gold, 999, 0)
	fill.shadow_size = 0
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
	while base != &"":
		if th.has_font("font", base):
			return true
		base = th.get_type_variation_base(base)
	return false


## A flat panel: fill, a thick dark brown outline, rounded corners, a soft shadow below.
func _flat(fill: Color, radius: int, side: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = P.outline
	s.set_border_width_all(OUTLINE)
	s.set_corner_radius_all(radius)
	s.shadow_color = P.shadow
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = side
	s.content_margin_right = side
	s.anti_aliasing = true
	return s


func _darker(s: StyleBoxFlat) -> StyleBoxFlat:
	var d := s.duplicate() as StyleBoxFlat
	d.bg_color = s.bg_color.darkened(P.press_darken)
	d.shadow_offset = Vector2(0, 2)
	d.shadow_size = 3
	return d


func _button(t: Theme, type: String, fill: Color, text: Color, size: int, font: Font, base := "", pad := 26) -> void:
	if base != "":
		t.set_type_variation(type, base)
	var n := _flat(fill, RADIUS, pad + 10)
	n.content_margin_top = pad
	n.content_margin_bottom = pad
	var off := n.duplicate() as StyleBoxFlat
	off.bg_color = fill.lerp(Color(0.6, 0.55, 0.5), 0.55)
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, n)
	t.set_stylebox("pressed", type, _darker(n))
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, text)
	t.set_color("font_disabled_color", type, Color(text, 0.6))
	t.set_constant("h_separation", type, 10)


func _label(t: Theme, type: String, colour: Color, size: int, font: Font, base := "Label") -> void:
	t.set_type_variation(type, base)
	t.set_color("font_color", type, colour)
	t.set_font_size("font_size", type, maxi(size, MIN_TEXT))
	t.set_font("font", type, font)


func _office_tag(t: Theme, type: String, fill: Color, text: Color) -> void:
	t.set_type_variation(type, "Button")
	var s := _flat(fill, 22, 16)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	t.set_stylebox("normal", type, s)
	t.set_stylebox("hover", type, s)
	t.set_stylebox("pressed", type, _darker(s))
	t.set_stylebox("disabled", type, s)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font("font", type, sans_bold)
	t.set_font_size("font_size", type, MIN_TEXT + 2)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		t.set_color(c, type, text)
	t.set_constant("h_separation", type, 6)
	t.set_constant("icon_max_width", type, 22)
	t.set_constant("outline_size", type, 0)  # (Button's outline is for buttons on the scene)
