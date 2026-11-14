extends Control
## Void of Exile launcher: account on the left with the newest release and its
## notes, the play area on the right. The game only starts on the latest
## release; updates download just the chunks that changed (see updater.gd).
## Game and Server at the top choose what the big button does: play, or host a
## server of your own (server_host.gd; signed in only).

const VERSION := "1.2.1"
const RECHECK := 300.0

var net := Net.new()
var accounts := Accounts.new()
var updater: Updater
var host: ServerHost
## "game" or "server": what the big button at the bottom does.
var mode := "game"

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
# Server page
var stop_button: Button
var server_body: Control
var server_signin: Control
var server_status: Label
var server_fields := {}
var players_title: Label
var players_list: VBoxContainer
var server_log: RichTextLabel
var library_label: Label
var launcher_update: Button
var _launcher_latest := {}


func _ready() -> void:
	theme = UI.theme()
	get_window().min_size = Vector2i(1060, 640)
	add_child(net)
	updater = Updater.new(net, Paths.game_dir())
	add_child(updater)
	updater.progress.connect(_on_progress)
	host = ServerHost.new(net)
	add_child(host)
	host.updater.progress.connect(_on_progress)
	host.changed.connect(_on_host_changed)
	host.log_line.connect(_on_server_log)
	get_tree().auto_accept_quit = false
	_build()
	_refresh_account()
	_check()
	_check_launcher()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if host and host.running:
			status.text = "Stopping your server: saving the players"
			await host.shutdown()
		get_tree().quit()


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
	launcher_update = UI.green_button(Button.new(), 14)
	launcher_update.visible = false
	launcher_update.pressed.connect(_update_launcher)
	col.add_child(launcher_update)
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
	for key in ["play", "server", "notes", "settings"]:
		var b := UI.stone_button(Button.new(), 16)
		b.text = {play = "Game", server = "Server", notes = "Patch notes", settings = "Settings"}[key]
		b.toggle_mode = true
		b.pressed.connect(_show_page.bind(key))
		tabs[key] = b
		top.add_child(b)

	var stack := Control.new()
	stack.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(stack)
	pages.play = _play_page()
	pages.server = _server_page()
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
	# A soft dark halo keeps the logo clear of the busy backdrop.
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.92))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.6, Color(0, 0, 0, 0.65))
	var halo_tex := GradientTexture2D.new()
	halo_tex.gradient = g
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	var halo := TextureRect.new()
	halo.texture = halo_tex
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.custom_minimum_size = Vector2(720, 720)
	halo.mouse_filter = MOUSE_FILTER_IGNORE
	page.add_child(halo)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(400, 400)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	col.add_child(UI.label("Install folder (the game and your server)", 15, UI.DIM))
	library_label = UI.label(Paths.library(), 15)
	library_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	col.add_child(library_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var open := UI.stone_button(Button.new(), 15)
	open.text = "Open folder"
	open.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(Paths.library())
		OS.shell_open(Paths.library()))
	var change := UI.stone_button(Button.new(), 15)
	change.text = "Change folder"
	change.pressed.connect(_pick_library)
	var verify := UI.stone_button(Button.new(), 15)
	verify.text = "Repair files"
	verify.pressed.connect(func() -> void: _install(true))
	row.add_child(open)
	row.add_child(change)
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
	stop_button = UI.red_button(Button.new(), 30)
	stop_button.custom_minimum_size = Vector2(300, 74)
	stop_button.text = "STOP SERVER"
	stop_button.visible = false
	stop_button.pressed.connect(func() -> void: host.stop())
	row.add_child(stop_button)

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
	if key in ["play", "server"]:
		mode = "server" if key == "server" else "game"
		if mode == "server" and host.latest.is_empty():
			host.check()
		_update_play()


# --- account ----------------------------------------------------------------------

func _refresh_account() -> void:
	me = {}
	_draw_account()
	_update_play()
	_draw_server()
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
	var cancel := UI.red_button(Button.new(), 17)
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
	if mode == "server":
		_update_server_button()
		return
	stop_button.visible = false
	play.visible = true
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
	elif not updater.is_current(latest):
		play.text = "UPDATE"
		status.text = "%s is out" % latest.version if have != str(latest.version) else "An update for %s is out" % have
	else:
		play.text = "PLAY"


func _on_play() -> void:
	if mode == "server":
		_on_server_button()
		return
	if accounts.current() == "":
		_open_login()
	elif not updater.is_current(latest):
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


# --- server -----------------------------------------------------------------------

func _server_page() -> Control:
	var page := Control.new()
	var pad := MarginContainer.new()
	pad.set_anchors_preset(PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(m, 26)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	page.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	pad.add_child(row)
	server_body = row

	# Settings: only what a host may change; the game itself is locked.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.panel(24))
	left.custom_minimum_size.x = 420
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 10)
	left.add_child(lcol)
	lcol.add_child(UI.label("Your server", 28, UI.TEXT, true))
	server_status = UI.label("", 15, UI.DIM)
	server_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lcol.add_child(server_status)
	lcol.add_child(_rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	lcol.add_child(grid)
	_setting(grid, "name", "Name", UI.field("My Void Realm"))
	_setting(grid, "motd", "Message", UI.field("Welcome to the Void."))
	_setting(grid, "max_players", "Players", _number(1, 300))
	_setting(grid, "port", "Port", _number(1024, 65000))
	var memory := UI.stone_button(OptionButton.new(), 15)
	for mb in [2048, 3072, 4096, 6144, 8192, 0]:
		memory.add_item("No limit" if mb == 0 else "%d GB" % (mb / 1024))
		memory.set_item_metadata(memory.item_count - 1, mb)
	_setting(grid, "max_memory_mb", "Memory", memory)
	_setting(grid, "player_collision", "Player contact", _toggle())
	_setting(grid, "public", "Listed for all", _toggle())
	var hint := UI.label("Servers play exactly like the official ones: only these settings can change. "
			+ "Forward UDP to the port and the port + 1 for players outside your network.", 13, Color(UI.DIM, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lcol.add_child(hint)
	row.add_child(left)

	# Players and the log.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	var who := PanelContainer.new()
	who.add_theme_stylebox_override("panel", UI.panel(22))
	who.size_flags_vertical = SIZE_EXPAND_FILL
	var wcol := VBoxContainer.new()
	wcol.add_theme_constant_override("separation", 8)
	who.add_child(wcol)
	players_title = UI.label("Players", 22, UI.TEXT, true)
	wcol.add_child(players_title)
	var pscroll := ScrollContainer.new()
	pscroll.size_flags_vertical = SIZE_EXPAND_FILL
	pscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_list = VBoxContainer.new()
	players_list.size_flags_horizontal = SIZE_EXPAND_FILL
	players_list.add_theme_constant_override("separation", 6)
	pscroll.add_child(players_list)
	wcol.add_child(pscroll)
	right.add_child(who)
	var logs := PanelContainer.new()
	logs.add_theme_stylebox_override("panel", UI.panel(18))
	logs.size_flags_vertical = SIZE_EXPAND_FILL
	var lgcol := VBoxContainer.new()
	logs.add_child(lgcol)
	lgcol.add_child(UI.label("Log", 17, UI.DIM))
	server_log = RichTextLabel.new()
	server_log.scroll_following = true
	server_log.size_flags_vertical = SIZE_EXPAND_FILL
	server_log.add_theme_font_size_override("normal_font_size", 13)
	server_log.add_theme_color_override("default_color", Color(UI.TEXT, 0.82))
	server_log.selection_enabled = true
	lgcol.add_child(server_log)
	right.add_child(logs)
	row.add_child(right)

	# Signed out: hosting needs an account.
	var gate := CenterContainer.new()
	gate.set_anchors_preset(PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel(30))
	var gcol := VBoxContainer.new()
	gcol.add_theme_constant_override("separation", 12)
	box.add_child(gcol)
	gcol.add_child(UI.label("Host a server", 28, UI.TEXT, true))
	var why := UI.label("Sign in to run a Void of Exile server. It is tied to your account.", 16, UI.DIM)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = 380
	gcol.add_child(why)
	var sign := UI.stone_button(Button.new(), 17)
	sign.text = "Sign in"
	sign.pressed.connect(_open_login)
	gcol.add_child(sign)
	gate.add_child(box)
	page.add_child(gate)
	server_signin = gate
	_fill_settings()
	_draw_server()
	return page


func _setting(grid: GridContainer, key: String, title: String, control: Control) -> void:
	var l := UI.label(title, 16, UI.DIM)
	l.custom_minimum_size.x = 120
	grid.add_child(l)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(control)
	server_fields[key] = control
	if control is LineEdit:
		(control as LineEdit).text_changed.connect(func(_t: String) -> void: _settings_changed())
	elif control is SpinBox:
		(control as SpinBox).value_changed.connect(func(_v: float) -> void: _settings_changed())
	elif control is OptionButton:
		(control as OptionButton).item_selected.connect(func(_i: int) -> void: _settings_changed())
	elif control is Button:
		(control as Button).toggled.connect(func(on: bool) -> void:
			(control as Button).text = "On" if on else "Off"
			_settings_changed())


func _number(low: int, high: int) -> SpinBox:
	var n := SpinBox.new()
	n.min_value = low
	n.max_value = high
	n.rounded = true
	var e := n.get_line_edit()
	var look := UI.field("")
	for state in ["normal", "focus"]:
		e.add_theme_stylebox_override(state, look.get_theme_stylebox(state))
	e.add_theme_font_size_override("font_size", 17)
	e.custom_minimum_size.y = 42
	look.free()
	return n


func _toggle() -> Button:
	var b := UI.stone_button(Button.new(), 15)
	b.toggle_mode = true
	b.text = "Off"
	return b


func _fill_settings() -> void:
	var s := host.settings
	(server_fields.name as LineEdit).text = str(s.name)
	(server_fields.motd as LineEdit).text = str(s.motd)
	(server_fields.max_players as SpinBox).set_value_no_signal(int(s.max_players))
	(server_fields.port as SpinBox).set_value_no_signal(int(s.port))
	var memory := server_fields.max_memory_mb as OptionButton
	for i in memory.item_count:
		if int(memory.get_item_metadata(i)) == int(s.max_memory_mb):
			memory.select(i)
	for key in ["player_collision", "public"]:
		var b := server_fields[key] as Button
		b.set_pressed_no_signal(bool(s[key]))
		b.text = "On" if bool(s[key]) else "Off"


func _settings_changed() -> void:
	var memory := server_fields.max_memory_mb as OptionButton
	host.save_settings({
		name = (server_fields.name as LineEdit).text.strip_edges().left(40) if (server_fields.name as LineEdit).text.strip_edges() != "" else "My Void Realm",
		motd = (server_fields.motd as LineEdit).text.strip_edges().left(110),
		max_players = int((server_fields.max_players as SpinBox).value),
		port = int((server_fields.port as SpinBox).value),
		max_memory_mb = int(memory.get_item_metadata(memory.selected)) if memory.selected >= 0 else 4096,
		player_collision = (server_fields.player_collision as Button).button_pressed,
		public = (server_fields.public as Button).button_pressed,
	})
	if host.running:
		server_status.text = "Running. Changes apply the next time it starts."


func _draw_server() -> void:
	if server_body == null:
		return
	var signed := accounts.current() != ""
	server_signin.visible = not signed
	server_body.visible = signed
	for key: String in server_fields:
		var c: Control = server_fields[key]
		if c is LineEdit: (c as LineEdit).editable = not host.running
		elif c is SpinBox: (c as SpinBox).editable = not host.running
		elif c is BaseButton: (c as BaseButton).disabled = host.running
	if host.running:
		var count := host.players.size()
		server_status.text = ("Stopping: saving the players" if host.stopping else
			"Running on port %d - %s" % [int(host.settings.port), str(host.info.get("version", ""))])
		players_title.text = "Players  %d / %d" % [count, int(host.settings.max_players)]
	else:
		var have := host.updater.installed_version()
		server_status.text = ("Installed  %s" % have) if have != "" else "Not installed yet"
		players_title.text = "Players"
	for c in players_list.get_children():
		c.queue_free()
	if host.running and host.players.is_empty():
		players_list.add_child(UI.label("Nobody is on yet.", 15, UI.DIM))
	elif not host.running:
		players_list.add_child(UI.label("Start the server to see who plays on it.", 15, UI.DIM))
	for p: Dictionary in host.players:
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", UI.card(10, 0.9))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 14)
		line.add_child(r)
		var n := UI.label(str(p.get("name", "?")), 17, UI.BAD if p.get("dead", false) else UI.TEXT, true)
		n.custom_minimum_size.x = 150
		r.add_child(n)
		r.add_child(UI.label("%s %d" % [str(p.get("class_id", "")).capitalize(), int(p.get("level", 0))], 15, UI.GOLD))
		var where := UI.label(str(p.get("place", "")), 15, UI.DIM)
		where.size_flags_horizontal = SIZE_EXPAND_FILL
		r.add_child(where)
		r.add_child(UI.label("%d ms" % int(p.get("ping", 0)), 14, UI.DIM))
		var kick := UI.red_button(Button.new(), 14)
		kick.text = "Kick"
		kick.pressed.connect(host.kick.bind(str(p.get("name", ""))))
		r.add_child(kick)
		players_list.add_child(line)


func _on_host_changed() -> void:
	_draw_server()
	if mode == "server":
		_update_play()


func _on_server_log(line: String) -> void:
	if server_log:
		server_log.add_text(line + "\n")


func _update_server_button() -> void:
	var have := host.updater.installed_version()
	installed_label.text = ("Server  %s" % have) if have != "" else ""
	play.visible = not host.running
	stop_button.visible = host.running
	stop_button.disabled = host.stopping
	if busy:
		return
	play.disabled = false
	if accounts.current() == "":
		play.text = "SIGN IN"
	elif host.latest.is_empty():
		play.text = "START"
		play.disabled = true
		status.text = "Looking for the server build"
	elif not host.available():
		play.text = "SOON"
		play.disabled = true
		status.text = "The server runs on Linux for now"
	elif have == "":
		play.text = "INSTALL"
		status.text = "Server %s - %s" % [host.latest.version, Updater._mb(int(host.latest.platforms[Updater.platform()].get("download", 0)))]
	elif not host.updater.is_current(host.latest):
		play.text = "UPDATE"
		status.text = "Server %s is out" % host.latest.version
	else:
		play.text = "START"
		status.text = "Your server is running" if host.running else ""


func _on_server_button() -> void:
	if accounts.current() == "":
		_open_login()
	elif not host.updater.is_current(host.latest):
		if busy or host.latest.is_empty():
			return
		busy = true
		play.disabled = true
		play.text = "INSTALLING"
		bar.visible = true
		bar.value = 0
		var err := await host.updater.update(host.latest)
		busy = false
		bar.visible = false
		status.text = err if err != "" else "Server ready"
		_draw_server()
		_update_play()
	else:
		play.disabled = true
		status.text = "Starting your server"
		var err := await host.start(accounts.current(), accounts.token())
		status.text = err if err != "" else "Your server is running"
		_update_play()


# --- install folder and the launcher's own updates --------------------------------

## Moves the game and the server build to another folder (or, across drives,
## installs them there again).
func _pick_library() -> void:
	if busy or host.running:
		status.text = "Wait until the download or your server is done."
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = "Install Void of Exile in"
	dialog.current_dir = Paths.library()
	add_child(dialog)
	dialog.dir_selected.connect(func(dir: String) -> void:
		dialog.queue_free()
		_move_library(dir))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.6)


func _move_library(root: String) -> void:
	if root == "" or root == Paths.library():
		return
	var moved := true
	for pair: Array in [[updater, Paths.game_dir(root)], [host.updater, Paths.server_dir(root)]]:
		var u: Updater = pair[0]
		var target: String = pair[1]
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if DirAccess.dir_exists_absolute(u.install_dir) and not DirAccess.dir_exists_absolute(target):
			if DirAccess.rename_absolute(u.install_dir, target) != OK:
				moved = false
		u.install_dir = target
	Paths.set_library(root)
	library_label.text = Paths.library()
	status.text = "Moved to %s" % root if moved else "Couldn't move the files there: they will be installed again in the new folder."
	_update_play()
	_draw_server()


## The newest launcher (mirrored on void.plainshow.se by the release sync).
func _check_launcher() -> void:
	var r := await net.fetch("/files/launcher/latest.json")
	if not r.ok or _newer(str(r.data.get("version", "")), VERSION) <= 0:
		return
	_launcher_latest = r.data
	launcher_update.text = "Update the launcher to %s" % str(r.data.version)
	launcher_update.visible = true


## Windows: fetch the online installer and let it replace this launcher (it
## starts the new one when done). Elsewhere: the download page.
func _update_launcher() -> void:
	if OS.get_name() != "Windows":
		OS.shell_open(Net.SITE + "/download")
		return
	if host.running or busy:
		status.text = "Stop your server and wait for downloads before updating the launcher."
		return
	launcher_update.disabled = true
	status.text = "Downloading the launcher update"
	var r := await net.fetch("/files/launcher/VoidOfExileSetup.exe", HTTPClient.METHOD_GET, {}, "", false)
	if not r.ok:
		launcher_update.disabled = false
		status.text = "Couldn't download the update: " + r.error
		return
	var setup := OS.get_user_data_dir().path_join("VoidOfExileSetup.exe")
	var f := FileAccess.open(setup, FileAccess.WRITE)
	f.store_buffer(r.body)
	f.close()
	# /S: silent, into this launcher's own folder (NSIS reads /D= last).
	var install_root := OS.get_executable_path().get_base_dir().get_base_dir()
	if OS.create_process(setup, ["/S", "/D=" + install_root.replace("/", "\\")]) <= 0:
		launcher_update.disabled = false
		status.text = "Couldn't start the update."
		return
	get_tree().quit()


## >0 when version a is newer than b ("1.10.0" > "1.9.2").
static func _newer(a: String, b: String) -> int:
	var x := a.split(".")
	var y := b.split(".")
	for i in maxi(x.size(), y.size()):
		var p := int(x[i]) if i < x.size() else 0
		var q := int(y[i]) if i < y.size() else 0
		if p != q:
			return 1 if p > q else -1
	return 0
