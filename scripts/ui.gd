class_name UI
## The game's black stone look (scripts/ui/ui_style.gd in void_of_exile):
## ivy window frames, stone buttons, Bree Serif.

const TEXT := Color("f6ead3")
const DIM := Color("a89f91")
const GOLD := Color("e5b96d")
const ACCENT := Color("82d7ed")
const GOOD := Color("63d471")
const BAD := Color("ff7b7b")

static var _font: FontFile
static var _theme: Theme
static var _textures := {}


static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/BreeSerif.ttf")
		_font.oversampling = 2.0
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_NONE
	return _font


static func bold() -> Font:
	var v := FontVariation.new()
	v.base_font = font()
	v.variation_embolden = 0.55
	return v


## Source art is large; size overrides give the nine-patch borders the game's
## on-screen size without resampling the pixels.
static func _texture(path: String, size: Vector2i) -> Texture2D:
	var key := path + str(size)
	if not _textures.has(key):
		var t := ImageTexture.create_from_image((load(path) as Texture2D).get_image())
		t.set_size_override(size)
		_textures[key] = t
	return _textures[key]


static func panel(margin := 26.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _texture("res://assets/ui/panel.png", Vector2i(192, 192))
	box.texture_margin_left = 48
	box.texture_margin_right = 48
	box.texture_margin_top = 48
	box.texture_margin_bottom = 48
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(margin)
	return box


static func card(margin := 14.0, alpha := 1.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _texture("res://assets/ui/panel_inner.png", Vector2i(300, 300))
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.modulate_color = Color(1, 1, 1, alpha)
	box.set_content_margin_all(margin)
	return box


static func _button_face(pressed: bool, tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _texture("res://assets/ui/button_pressed.png" if pressed else "res://assets/ui/button.png", Vector2i(192, 48))
	box.texture_margin_left = 9
	box.texture_margin_right = 9
	box.texture_margin_top = 9
	box.texture_margin_bottom = 9
	box.modulate_color = tint
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 11 if pressed else 8
	box.content_margin_bottom = 11 if pressed else 14
	return box


static func stone_button(b: Button, size := 17) -> Button:
	b.add_theme_stylebox_override("normal", _button_face(false, Color(0.82, 0.82, 0.82)))
	b.add_theme_stylebox_override("hover", _button_face(false, Color(1.15, 1.15, 1.15)))
	b.add_theme_stylebox_override("pressed", _button_face(true, Color.WHITE))
	b.add_theme_stylebox_override("hover_pressed", _button_face(true, Color(1.1, 1.1, 1.1)))
	b.add_theme_stylebox_override("disabled", _button_face(false, Color(0.45, 0.45, 0.45)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## The game's coloured stones: green to play and buy, red to cancel and leave.
static func green_button(b: Button, size := 30) -> Button:
	return _coloured(b, "green", size, Color("f3ffef"))


static func red_button(b: Button, size := 17) -> Button:
	return _coloured(b, "red", size, Color("fff0f0"))


static func _coloured(b: Button, colour: String, size: int, text: Color) -> Button:
	var faces := {normal = [false, Color.WHITE], hover = [false, Color(1.2, 1.2, 1.2)], pressed = [true, Color.WHITE],
		hover_pressed = [true, Color(1.1, 1.1, 1.1)], disabled = [false, Color(0.45, 0.45, 0.45)]}
	for state: String in faces:
		var down: bool = faces[state][0]
		var box := StyleBoxTexture.new()
		box.texture = _texture("res://assets/ui/button_%s%s.png" % ["pressed_" if down else "", colour], Vector2i(192, 48))
		box.texture_margin_left = 9
		box.texture_margin_right = 9
		box.texture_margin_top = 9
		box.texture_margin_bottom = 9
		box.modulate_color = faces[state][1]
		box.content_margin_left = 30
		box.content_margin_right = 30
		box.content_margin_top = 12 if down else 8
		box.content_margin_bottom = 8 if down else 12
		b.add_theme_stylebox_override(state, box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, text)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func label(text: String, size := 16, color := TEXT, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold() if heavy else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func field(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 42)
	for focused in [false, true]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.02, 0.03, 0.92)
		box.border_color = Color(ACCENT, 0.9) if focused else Color(0.62, 0.62, 0.68, 0.4)
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		box.content_margin_left = 12
		box.content_margin_right = 12
		e.add_theme_stylebox_override("focus" if focused else "normal", box)
	e.add_theme_font_override("font", font())
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(DIM, 0.7))
	return e


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = 16
		_theme.set_color("font_color", "Label", TEXT)
		_theme.set_color("default_color", "RichTextLabel", TEXT)
		_theme.set_font("bold_font", "RichTextLabel", bold())
		_theme.set_stylebox("panel", "PopupMenu", panel(14))
		_theme.set_stylebox("hover", "PopupMenu", card(4))
		_theme.set_color("font_color", "PopupMenu", TEXT)
		_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
		_theme.set_font_size("font_size", "PopupMenu", 17)
		for bar in ["VScrollBar", "HScrollBar"]:
			var track := StyleBoxFlat.new()
			track.bg_color = Color(0, 0, 0, 0.35)
			track.content_margin_left = 4
			track.content_margin_right = 4
			var grab := StyleBoxFlat.new()
			grab.bg_color = Color(1, 1, 1, 0.22)
			grab.set_corner_radius_all(3)
			_theme.set_stylebox("scroll", bar, track)
			_theme.set_stylebox("grabber", bar, grab)
			var hi := grab.duplicate()
			hi.bg_color = Color(1, 1, 1, 0.4)
			_theme.set_stylebox("grabber_highlight", bar, hi)
			_theme.set_stylebox("grabber_pressed", bar, hi)
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0, 0, 0, 0.7)
		bar_bg.border_color = Color(1, 1, 1, 0.14)
		bar_bg.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("3cb755")
		_theme.set_stylebox("background", "ProgressBar", bar_bg)
		_theme.set_stylebox("fill", "ProgressBar", fill)
	return _theme
