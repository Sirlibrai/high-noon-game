class_name UiKit
## Builds overlay cards from Controls styled by the shared theme
## (ui/ui_theme.tres, built from ui/palette.tres and the art of tools/make_ui_art.gd by tools/build_ui_theme.gd)
## through theme type variations. No colours, fonts or sizes are set here; change the look in the palette,
## the art script and the builder. As in the approved mockup, cards, chips and tags sit a few degrees off
## straight, badges, stars and buttons break out of their cards' edges, and cards and stars bounce in.


## Wrapped text is never wider than this (design pixels): the cards stay compact.
const MAX_TEXT_WIDTH := 780.0
## The smallest button (design pixels: 46 points on a 375-point-tall phone, Apple asks for 44).
const TAP := 88.0
## Round buttons: their art is 96 x 104 (the face over its base).
const ROUND_ASPECT := 104.0 / 96.0


## A full-screen dimmed layer that swallows taps, with a centred card column.
static func overlay(parent: Node) -> CenterContainer:
	var shade := Panel.new()
	shade.theme_type_variation = &"Shade"
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	return center


## A torn parchment card (theme "Card") holding a centred column: every overlay screen sits on one. It
## sits a degree off straight and bounces in.
static func card(parent: Node, tilt_deg := -1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	tilt(panel, tilt_deg)
	pop_in(panel, 0.0)
	return box


## A centred label. `variation` is a Label type in the theme: Heading, BigTitle, Tip, Hint, Pay, AdTag...
static func text(parent: Node, s: String, variation := &"", wrap_width := 0.0) -> Label:
	var l := Label.new()
	l.text = s
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(wrap_width, MAX_TEXT_WIDTH)
	parent.add_child(l)
	return l


static func row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


## A pill button. `variation`: "" or PrimaryButton (orange), BigPrimaryButton (the big orange main action),
## GhostButton or SecondaryButton (teal), SmallGhostButton. Pressed, its face sinks into its base (theme).
static func button(parent: Node, s: String, variation := &"") -> Button:
	var b := Button.new()
	b.text = s
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


## A round icon button, orange or teal (`kind`), `size` design pixels across; `label` names it (tooltip).
static func round_button(parent: Node, icon_asset: String, label: String, kind := "orange", size := TAP) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"RoundOrange" if kind == "orange" else &"RoundTeal"
	b.icon = Assets.texture(icon_asset)
	b.tooltip_text = label
	b.custom_minimum_size = Vector2(size, size * ROUND_ASPECT)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


static func icon_button(parent: Node, icon_asset: String) -> Button:
	return round_button(parent, icon_asset, "")


## A teal chip (a fact on a card), a little off straight.
static func pill(parent: Node, s: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Pill"
	parent.add_child(p)
	text(p, s.to_upper(), &"PillLabel")
	tilt(p, [-2.0, 1.5, -1.0, 2.0][parent.get_child_count() % 4])
	return p


## An image at `size`, or at its own size times its manifest scale (the art is stored at twice the size it shows).
static func image(parent: Node, asset: String, size := Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.texture(asset)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := float(Assets.meta(asset, "scale", 1.0))
	if size == Vector2.ZERO and k != 1.0:
		size = (t.texture.get_size() * k).round()
	if size != Vector2.ZERO:
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = size
	parent.add_child(t)
	return t


static func stars(parent: Node, count: int, size := 40.0, total := 3) -> HBoxContainer:
	var r := row(parent)
	for k in total:
		image(r, "ui/star_on" if k < count else "ui/star_off", Vector2(size, size))
	return r


## Turns a control a few degrees about its middle. Through its offset transform (drawing only, about its
## centre), which containers don't reset when they lay it out (they do reset rotation and scale).
static func tilt(c: Control, degrees: float) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	c.offset_transform_rotation = deg_to_rad(degrees)


## A short bounce in: from a little smaller and transparent to full size, after `delay` seconds (through the
## offset transform too, so it works inside containers).
static func pop_in(c: Control, delay: float, from := 0.7) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	c.offset_transform_scale = Vector2.ONE * from
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.12).set_delay(delay)


## Puts `child` on `panel`'s edge, breaking out of it (badges, tacks, stars, buttons): its centre at
## `anchor` (fractions of the panel's size) plus `offset`. It isn't laid out with the panel's content.
static func attach(panel: Control, child: Control, anchor: Vector2, offset := Vector2.ZERO) -> void:
	panel.add_child(child, false, Node.INTERNAL_MODE_BACK)
	var place := func():
		if is_instance_valid(child) and is_instance_valid(panel):
			child.size = child.get_combined_minimum_size()
			child.position = panel.size * anchor - child.size / 2 + offset
	panel.resized.connect(place)
	child.resized.connect(place)
	place.call_deferred()


## The panel a card's column sits in.
static func panel_of(card_box: Control) -> PanelContainer:
	return card_box.get_parent() as PanelContainer
