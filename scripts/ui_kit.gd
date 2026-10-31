class_name UiKit
## Builds overlay cards from Controls styled by the shared theme
## (ui/theme.tres) through theme type variations. No colours, fonts or sizes
## are set here; change the look in the theme and the manifest.


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


## A painted wooden panel (theme "Card") holding a centred column: every overlay screen sits on one.
static func card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


## A centred label. `variation` is a Label type in the theme: Heading, Title, Tip, Hint, Pay, AdTag...
static func text(parent: Node, s: String, variation := &"", wrap_width := 0.0) -> Label:
	var l := Label.new()
	l.text = s
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	parent.add_child(l)
	return l


static func row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


## `variation`: "" for the gold button, GhostButton, SmallGhostButton.
static func button(parent: Node, s: String, variation := &"") -> Button:
	var b := Button.new()
	b.text = s
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


static func icon_button(parent: Node, icon_asset: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"IconButton"
	b.icon = Assets.texture(icon_asset)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


static func pill(parent: Node, s: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Pill"
	parent.add_child(p)
	text(p, s, &"PillLabel")
	return p


static func image(parent: Node, asset: String, size := Vector2.ZERO) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.texture(asset)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
