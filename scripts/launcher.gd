extends Control
## Void of Exile launcher: account on the left with the newest release and its
## notes, the play area on the right. The game only starts on the latest
## release; updates download just the chunks that changed (see updater.gd).

const VERSION := "1.0.0"
const RECHECK := 300.0

var net := Net.new()
var accounts := Accounts.new()
var updater: Updater

var latest := {}
var me := {}
var busy := false
var _recheck := RECHECK

# Sidebar
var account_box: VBoxContainer
var cover: TextureRect
var version_label: Label
var date_label: Label
var title_label: Label
var notes: RichTextLabel
# Main area
var background: TextureRect
var pages: Dictionary = {}
var tabs: Dictionary = {}
var play: Button
var status: Label
var bar: ProgressBar
var ink: InkWeapon
var installed_label: Label
var notes_list: VBoxContainer
var login: Control
var login_name: LineEdit
var login_pass: LineEdit
var login_error: Label
var login_go: Button
var account_menu: PopupMenu


func _ready() -> void:
	theme = UI.theme()
	get_window().min_size = Vector2i(1060, 640)
	add_child(net)
	updater = Updater.new(net)
	add_child(updater)
	updater.progress.connect(_on_progress)
	_build()
	_refresh_account()
	_check()


func _process(delta: float) -> void:
	_recheck -= delta
	if _recheck <= 0.0 and not busy:
		_recheck = RECHECK
		_check()
	# Slow drift of the backdrop.
	var t := Time.get_ticks_msec() / 1000.0
	background.scale = Vector2.ONE * (1.06 + sin(t * 0.05) * 0.03)
	background.position = Vector2(sin(t * 0.07) * 14.0, cos(t * 0.05) * 8.0)


# --- layout ------------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var root := HBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_sidebar())
	root.add_child(_main())
	login = _login_overlay()
	add_child(login)


func _sidebar() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size.x = 370
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.025)
	bg.border_color = Color(1, 1, 1, 0.08)
	bg.border_width_right = 1
	side.add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 14)
	pad.add_child(col)
	side.add_child(pad)

	var account := PanelContainer.new()
	account.add_theme_stylebox_override("panel", UI.panel(22))
	account_box = VBoxContainer.new()
	account.add_child(account_box)
	col.add_child(account)
	account_menu = PopupMenu.new()
	account_menu.id_pressed.connect(_on_account_menu)
	add_child(account_menu)

	var release := PanelContainer.new()
	release.size_flags_vertical = SIZE_EXPAND_FILL
	release.add_theme_stylebox_override("panel", UI.panel(22))
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 8)
	release.add_child(rcol)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.card(2))
	cover = TextureRect.new()
	cover.custom_minimum_size = Vector2(0, 164)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture = load("res://assets/launch_background_black.png")
	frame.add_child(cover)
	frame.clip_contents = true
	rcol.add_child(frame)
	var vrow := HBoxContainer.new()
	version_label = UI.label("", 17, UI.GOLD, true)
	date_label = UI.label("", 14, UI.DIM)
	date_label.size_flags_horizontal = SIZE_EXPAND_FILL
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vrow.add_child(version_label)
	vrow.add_child(date_label)
	rcol.add_child(vrow)
	title_label = UI.label("", 25, UI.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rcol.add_child(title_label)
	rcol.add_child(_rule())
	rcol.add_child(UI.label("What's new", 17, UI.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes = RichTextLabel.new()
	notes.bbcode_enabled = true
	notes.fit_content = true
	notes.size_flags_horizontal = SIZE_EXPAND_FILL
	notes.add_theme_font_size_override("normal_font_size", 16)
	notes.add_theme_constant_override("line_separation", 6)
	scroll.add_child(notes)
	rcol.add_child(scroll)
	col.add_child(release)

	var foot := HBoxContainer.new()
	var site := LinkButton.new()
	site.text = "void.plainshow.se"
	site.add_theme_color_override("font_color", UI.DIM)
	site.add_theme_color_override("font_hover_color", UI.TEXT)
	site.pressed.connect(func() -> void: OS.shell_open(Net.SITE))
	foot.add_child(site)
	var v := UI.label("Launcher " + VERSION, 13, Color(UI.DIM, 0.6))
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(v)
	col.add_child(foot)
	return side


func _rule() -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size.y = 1
	r.color = Color(1, 1, 1, 0.1)
	return r


func _main() -> Control:
	var main := Control.new()
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.clip_contents = true
	background = TextureRect.new()
	background.texture = load("res://assets/launch_background_black.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(PRESET_FULL_RECT)
	main.add_child(background)
	main.resized.connect(func() -> void: background.pivot_offset = main.size / 2.0)
	main.add_child(_shade())
	var voxels := VoxelDrift.new()
	voxels.set_anchors_preset(PRESET_FULL_RECT)
	main.add_child(voxels)

	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	main.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var top_pad := MarginContainer.new()
	top_pad.add_theme_constant_override("margin_left", 26)
	top_pad.add_theme_constant_override("margin_top", 18)
	top_pad.add_child(top)
	col.add_child(top_pad)
	for key in ["play", "notes", "settings"]:
		var b := UI.stone_button(Button.new(), 16)
		b.text = {play = "Play", notes = "Patch notes", settings = "Settings"}[key]
		b.toggle_mode = true
		b.pressed.connect(_show_page.bind(key))
		tabs[key] = b
		top.add_child(b)

	var stack := Control.new()
	stack.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(stack)
	pages.play = _play_page()
	pages.notes = _notes_page()
	pages.settings = _settings_page()
	for p: Control in pages.values():
		p.set_anchors_preset(PRESET_FULL_RECT)
		stack.add_child(p)
	col.add_child(_bottom_bar())
	_show_page("play")
	return main


func _shade() -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.25))
	g.set_color(1, Color(0, 0, 0, 0.92))
	g.add_point(0.55, Color(0, 0, 0, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	return shade


func _play_page() -> Control:
	var page := CenterContainer.new()
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(440, 368)
	page.add_child(logo)
	var tween := create_tween().set_loops()
	tween.tween_property(logo, "position:y", -12.0, 3.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(logo, "position:y", 12.0, 3.0).as_relative().set_trans(Tween.TRANS_SINE)
	return page


func _notes_page() -> Control:
	var page := MarginContainer.new()
	for m in ["margin_left", "margin_right"]:
		page.add_theme_constant_override(m, 26)
	page.add_theme_constant_override("margin_top", 16)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_list = VBoxContainer.new()
	notes_list.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_list.add_theme_constant_override("separation", 14)
	scroll.add_child(notes_list)
	page.add_child(scroll)
	return page


func _settings_page() -> Control:
	var page := CenterContainer.new()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel(30))
	box.custom_minimum_size.x = 520
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	col.add_child(UI.label("Settings", 28, UI.TEXT, true))
	col.add_child(UI.label("Game folder", 15, UI.DIM))
	var path := UI.label(updater.install_dir, 15)
	path.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	col.add_child(path)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var open := UI.stone_button(Button.new(), 15)
	open.text = "Open folder"
	open.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(updater.install_dir)
		OS.shell_open(updater.install_dir))
	var verify := UI.stone_button(Button.new(), 15)
	verify.text = "Repair files"
	verify.pressed.connect(func() -> void: _install(true))
	row.add_child(open)
	row.add_child(verify)
	col.add_child(row)
	col.add_child(_rule())
	col.add_child(UI.label("System  %s" % Updater.platform(), 15, UI.DIM))
	return page


func _bottom_bar() -> Control:
	var bar_box := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(1, 1, 1, 0.08)
	bg.border_width_top = 1
	bg.content_margin_left = 26
	bg.content_margin_right = 26
	bg.content_margin_top = 16
	bg.content_margin_bottom = 18
	bar_box.add_theme_stylebox_override("panel", bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar_box.add_child(row)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	ink = InkWeapon.new()
	ink.custom_minimum_size = Vector2(64, 64)
	ink.visible = false
	left.add_child(ink)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	status = UI.label("", 16, UI.TEXT)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 8
	bar.show_percentage = false
	bar.visible = false
	info.add_child(status)
	info.add_child(bar)
	left.add_child(info)
	row.add_child(left)

	play = UI.green_button(Button.new(), 30)
	play.custom_minimum_size = Vector2(300, 74)
	play.pressed.connect(_on_play)
	row.add_child(play)

	installed_label = UI.label("", 14, UI.DIM)
	installed_label.size_flags_horizontal = SIZE_EXPAND_FILL
	installed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	installed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(installed_label)
	return bar_box


func _show_page(key: String) -> void:
	for k: String in pages:
		pages[k].visible = k == key
		tabs[k].set_pressed_no_signal(k == key)
	if key == "notes":
		_load_notes()


# --- account ----------------------------------------------------------------------

func _refresh_account() -> void:
	me = {}
	_draw_account()
	_update_play()
	var token := accounts.token()
	if token == "":
		return
	var r := await net.fetch("/api/me", HTTPClient.METHOD_GET, {}, token)
	if r.ok:
		me = r.data
	elif r.status == 401:
		accounts.forget(accounts.current())
	_draw_account()
	_update_play()


func _draw_account() -> void:
	for c in account_box.get_children():
		c.queue_free()
	var user := accounts.current()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	account_box.add_child(row)
	var avatar := PanelContainer.new()
	var slot := StyleBoxTexture.new()
	slot.texture = load("res://assets/ui/slot.png")
	slot.texture_margin_left = 3
	slot.texture_margin_right = 3
	slot.texture_margin_top = 3
	slot.texture_margin_bottom = 3
	avatar.add_theme_stylebox_override("panel", slot)
	avatar.custom_minimum_size = Vector2(56, 56)
	var initial := UI.label(user.substr(0, 1).to_upper() if user != "" else "?", 26, UI.GOLD if user != "" else UI.DIM, true)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	row.add_child(avatar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	if user == "":
		col.add_child(UI.label("Not signed in", 18, UI.DIM))
		var b := UI.stone_button(Button.new(), 15)
		b.text = "Sign in"
		b.pressed.connect(_open_login)
		account_box.add_child(b)
		return
	col.add_child(UI.label(user, 21, UI.TEXT, true))
	var progress: Dictionary = me.get("progress", {})
	var lv := UI.label("Level %s" % progress.level if progress.has("level") else "Connecting", 15, UI.GOLD if progress.has("level") else UI.DIM)
	col.add_child(lv)
	if progress.has("needed"):
		var xp := ProgressBar.new()
		xp.custom_minimum_size.y = 5
		xp.show_percentage = false
		xp.max_value = float(progress.needed)
		xp.value = float(progress.into)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ffd959")
		xp.add_theme_stylebox_override("fill", fill)
		col.add_child(xp)
	var switch := UI.stone_button(Button.new(), 15)
	switch.text = "Switch account"
	switch.pressed.connect(func() -> void:
		account_menu.clear()
		var i := 0
		for saved_user: String in accounts.saved():
			account_menu.add_radio_check_item(saved_user, i)
			account_menu.set_item_checked(i, saved_user == user)
			account_menu.set_item_metadata(i, saved_user)
			i += 1
		account_menu.add_separator()
		account_menu.add_item("Add account", 1000)
		account_menu.add_item("Sign out", 1001)
		account_menu.popup(Rect2i(Vector2i(switch.get_screen_position()) + Vector2i(0, int(switch.size.y) + 4), Vector2i(int(switch.size.x), 0))))
	account_box.add_child(switch)


func _on_account_menu(id: int) -> void:
	if id == 1000:
		_open_login()
	elif id == 1001:
		var token := accounts.token()
		net.fetch("/api/logout", HTTPClient.METHOD_POST, {}, token)
		accounts.forget(accounts.current())
		_refresh_account()
	else:
		accounts.use(str(account_menu.get_item_metadata(account_menu.get_item_index(id))))
		_refresh_account()


func _login_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel(34))
	box.custom_minimum_size.x = 440
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var title := UI.label("Sign in", 30, UI.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	login_name = UI.field("Name")
	login_pass = UI.field("Password", true)
	login_name.text_submitted.connect(func(_t: String) -> void: login_pass.grab_focus())
	login_pass.text_submitted.connect(func(_t: String) -> void: _sign_in())
	col.add_child(login_name)
	col.add_child(login_pass)
	login_error = UI.label("", 15, UI.BAD)
	login_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(login_error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	login_go = UI.stone_button(Button.new(), 17)
	login_go.text = "Enter"
	login_go.size_flags_horizontal = SIZE_EXPAND_FILL
	login_go.pressed.connect(_sign_in)
	var cancel := UI.stone_button(Button.new(), 17)
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: login.visible = false)
	row.add_child(login_go)
	row.add_child(cancel)
	col.add_child(row)
	var join := LinkButton.new()
	join.text = "Create an account"
	join.add_theme_color_override("font_color", UI.DIM)
	join.add_theme_color_override("font_hover_color", UI.TEXT)
	join.size_flags_horizontal = SIZE_SHRINK_CENTER
	join.pressed.connect(func() -> void: OS.shell_open(Net.SITE + "/join"))
	col.add_child(join)
	return overlay


func _open_login() -> void:
	login_error.text = ""
	login_name.text = ""
	login_pass.text = ""
	login.visible = true
	login_name.grab_focus()


func _sign_in() -> void:
	if login_name.text.strip_edges() == "" or login_pass.text == "":
		login_error.text = "Enter your name and password."
		return
	login_go.disabled = true
	login_error.text = ""
	var r := await net.fetch("/api/login", HTTPClient.METHOD_POST, {username = login_name.text.strip_edges(), password = login_pass.text})
	login_go.disabled = false
	login_pass.text = ""
	if not r.ok:
		login_error.text = r.error
		return
	accounts.add(str(r.data.account.username), str(r.data.token))
	login.visible = false
	_refresh_account()


# --- releases ---------------------------------------------------------------------

func _check() -> void:
	status.text = "Looking for updates"
	var r := await net.fetch("/launcher/v1/latest")
	if r.ok:
		latest = r.data
		status.text = ""
		_draw_release()
	else:
		latest = {}
		status.text = "Can't reach void.plainshow.se" if r.status == 0 or r.status >= 500 else "No release yet"
	_update_play()


func _draw_release() -> void:
	version_label.text = str(latest.get("version", ""))
	date_label.text = str(latest.get("date", ""))
	title_label.text = str(latest.get("title", ""))
	var lines := PackedStringArray()
	for n in latest.get("notes", []):
		lines.append("[color=#e5b96d]-[/color]  " + str(n).replace("[", "[lb]"))
	notes.text = "\n".join(lines)
	if latest.get("cover_url"):
		var tex := await net.image(str(latest.cover_url))
		if tex:
			cover.texture = tex


func _load_notes() -> void:
	var r := await net.fetch("/launcher/v1/releases")
	if not r.ok:
		return
	for c in notes_list.get_children():
		c.queue_free()
	for rel: Dictionary in r.data.get("releases", []):
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.panel(24))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(240, 135)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(thumb)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.add_child(UI.label("%s   %s" % [rel.get("version", ""), rel.get("date", "")], 15, UI.GOLD))
		col.add_child(UI.label(str(rel.get("title", "")), 24, UI.TEXT, true))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.text = "\n".join(PackedStringArray(rel.get("notes", []).map(func(n) -> String: return "[color=#e5b96d]-[/color]  " + str(n).replace("[", "[lb]"))))
		col.add_child(text)
		row.add_child(col)
		notes_list.add_child(card)
		if rel.get("cover_url"):
			_set_thumb(thumb, str(rel.cover_url))


func _set_thumb(rect: TextureRect, url: String) -> void:
	var tex := await net.image(url)
	if tex and is_instance_valid(rect):
		rect.texture = tex


# --- play / install ---------------------------------------------------------------

func _update_play() -> void:
	var have := updater.installed_version()
	installed_label.text = ("Installed  %s" % have) if have != "" else ""
	if busy:
		return
	play.disabled = false
	if accounts.current() == "":
		play.text = "SIGN IN"
	elif latest.is_empty():
		play.text = "PLAY"
		play.disabled = true
	elif not latest.get("platforms", {}).has(Updater.platform()):
		play.text = "SOON"
		play.disabled = true
		status.text = "Void of Exile isn't out for this system yet"
	elif have == "":
		play.text = "INSTALL"
		status.text = "%s - %s" % [latest.version, Updater._mb(int(latest.platforms[Updater.platform()].get("download", 0)))]
	elif have != str(latest.version):
		play.text = "UPDATE"
		status.text = "%s is out" % latest.version
	else:
		play.text = "PLAY"


func _on_play() -> void:
	if accounts.current() == "":
		_open_login()
	elif updater.installed_version() != str(latest.get("version", "")):
		_install(false)
	else:
		_launch()


func _install(verify: bool) -> void:
	if busy or latest.is_empty():
		return
	busy = true
	play.disabled = true
	play.text = "UPDATING" if updater.installed_version() != "" else "INSTALLING"
	bar.visible = true
	bar.value = 0
	ink.visible = true
	ink.pick()
	var err := await updater.update(latest, verify)
	busy = false
	bar.visible = false
	ink.visible = false
	status.text = err if err != "" else "Ready to play"
	_update_play()


func _on_progress(done: int, total: int, text: String) -> void:
	bar.max_value = maxf(1.0, total)
	bar.value = done
	status.text = text


func _launch() -> void:
	var exe := updater.executable()
	if exe == "" or not FileAccess.file_exists(exe):
		status.text = "The game files are missing. Repair them in Settings."
		return
	OS.set_environment("VOID_LAUNCHER_SESSION", accounts.current() + "\t" + accounts.token())
	var pid := OS.create_process(exe, [])
	OS.unset_environment("VOID_LAUNCHER_SESSION")
	if pid <= 0:
		status.text = "Couldn't start the game."
		return
	status.text = "Void of Exile is running"
	get_window().mode = Window.MODE_MINIMIZED
