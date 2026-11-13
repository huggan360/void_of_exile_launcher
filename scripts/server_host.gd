class_name ServerHost
extends Node
## The launcher's own dedicated server. Installs the server build (its own
## Updater; its files are the game's under another name, so the chunks are
## shared), writes its config, starts and stops it, reads its log, and asks it
## who is on and to kick someone over the local admin channel (the game's
## NetServer._admin: "VRADMIN <token> players|kick <name>|stop" on the status
## port, answered only on this computer, only with the token set here).
##
## Its files live in the launcher's data folder: server_build/ (the build) and
## server/ (server.cfg with the host's settings and key, and the world saves).

signal changed
signal log_line(text: String)

## What a host may set (the server is locked to the official game otherwise).
const DEFAULTS := {name = "My Void Realm", motd = "Welcome to the Void.", max_players = 40, port = 24565,
	max_memory_mb = 4096, player_collision = false, public = true}
const POLL := 1.5
const STOP_WAIT := 25.0
const LOG_LINES := 400

var net: Net
var updater: Updater
var latest := {}
var settings := {}
var running := false
var stopping := false
var players: Array = []
var info := {}
var log_lines: PackedStringArray = []

var _pid := 0
var _stdio: FileAccess
var _stderr: FileAccess
var _partial := {}
var _udp := PacketPeerUDP.new()
var _token := ""
var _poll := 0.0
var _stop_left := 0.0


func _init(net_node: Net) -> void:
	net = net_node
	updater = Updater.new(net_node, "server_build")
	add_child(updater)
	load_settings()


func config_dir() -> String:
	return OS.get_user_data_dir().path_join("server")


func _cfg_path() -> String:
	return config_dir().path_join("server.cfg")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_cfg_path())
	settings = {}
	for key: String in DEFAULTS:
		var section := "gameplay" if key == "player_collision" else "server"
		settings[key] = type_convert(cfg.get_value(section, key, DEFAULTS[key]), typeof(DEFAULTS[key]))


## Reads the newest server release (/launcher/v1/server).
func check() -> void:
	var r := await net.fetch("/launcher/v1/server")
	latest = r.data if r.ok else {}
	changed.emit()


func available() -> bool:
	return latest.get("platforms", {}).has(Updater.platform())


## A key for this account's server: asked once per account from the account
## service (it ties the server to whoever signed in) and kept in server.cfg.
func _ensure_key(username: String, token: String) -> String:
	var cfg := ConfigFile.new()
	cfg.load(_cfg_path())
	if str(cfg.get_value("accounts", "server_key", "")) != "" and str(cfg.get_value("launcher", "account", "")) == username:
		return ""
	var r := await net.fetch("/api/host/key", HTTPClient.METHOD_POST, {}, token)
	if not r.ok:
		return r.error if r.error != "" else "Couldn't get a server key."
	cfg.set_value("accounts", "server_key", str(r.data.key))
	cfg.set_value("launcher", "account", username)
	DirAccess.make_dir_recursive_absolute(config_dir())
	cfg.save(_cfg_path())
	return ""


## Writes the host's settings into server.cfg (keeps everything else there).
func save_settings(values: Dictionary) -> void:
	settings.merge(values, true)
	var cfg := ConfigFile.new()
	cfg.load(_cfg_path())
	for key: String in settings:
		cfg.set_value("gameplay" if key == "player_collision" else "server", key, settings[key])
	cfg.set_value("accounts", "url", Net.SITE)
	DirAccess.make_dir_recursive_absolute(config_dir())
	cfg.save(_cfg_path())


## Starts the server for `username`. "" when it started, else why not.
func start(username: String, token: String) -> String:
	if running:
		return ""
	var exe := updater.executable()
	if exe == "" or not FileAccess.file_exists(exe):
		return "Install the server first."
	var err := await _ensure_key(username, token)
	if err != "":
		return err
	save_settings({})
	var bytes := Crypto.new().generate_random_bytes(24)
	_token = bytes.hex_encode()
	OS.set_environment("VOID_ADMIN_TOKEN", _token)
	var proc := OS.execute_with_pipe(exe, ["--headless", "--", "--dedicated", "--config=" + config_dir()], false)
	OS.unset_environment("VOID_ADMIN_TOKEN")
	if proc.is_empty() or int(proc.get("pid", 0)) <= 0:
		return "The server couldn't start."
	_pid = int(proc.pid)
	_stdio = proc.stdio
	_stderr = proc.stderr
	_partial = {}
	running = true
	stopping = false
	players = []
	info = {}
	log_lines = []
	_add_log("Starting %s on port %d" % [settings.name, int(settings.port)])
	changed.emit()
	return ""


## Asks it to save everyone and quit; it is killed if it doesn't within STOP_WAIT.
func stop() -> void:
	if not running or stopping:
		return
	stopping = true
	_stop_left = STOP_WAIT
	_admin("stop")
	_add_log("Stopping: saving the players")
	changed.emit()


func kick(player_name: String) -> void:
	if running:
		_admin("kick " + player_name)
		_add_log("Kicked %s" % player_name)
		_poll = 0.3


func _admin(command: String) -> void:
	_udp.set_dest_address("127.0.0.1", int(settings.port) + 1)
	_udp.put_packet(("VRADMIN %s %s" % [_token, command]).to_utf8_buffer())


func _process(delta: float) -> void:
	if not running:
		return
	_drain(_stdio, "out")
	_drain(_stderr, "err")
	if not OS.is_process_running(_pid):
		_drain(_stdio, "out")
		_drain(_stderr, "err")
		_add_log("The server stopped.")
		running = false
		stopping = false
		players = []
		_pid = 0
		changed.emit()
		return
	if stopping:
		_stop_left -= delta
		if _stop_left <= 0.0:
			OS.kill(_pid)
	while _udp.get_available_packet_count() > 0:
		var reply = JSON.parse_string(_udp.get_packet().get_string_from_utf8())
		if reply is Dictionary:
			info = reply.get("info", info)
			if reply.has("players"):
				players = reply.players
			changed.emit()
	_poll -= delta
	if _poll <= 0.0 and not stopping:
		_poll = POLL
		_admin("players")


## Reads what the server printed (non-blocking pipes) into whole lines.
func _drain(pipe: FileAccess, which: String) -> void:
	if pipe == null:
		return
	for i in 16:
		var data := pipe.get_buffer(8192)
		if data.is_empty():
			return
		var text: String = _partial.get(which, "") + data.get_string_from_utf8()
		var lines := text.split("\n")
		_partial[which] = lines[lines.size() - 1]
		for k in lines.size() - 1:
			var line := lines[k].strip_edges(false, true)
			if line != "" and not line.begins_with("   at:"):
				_add_log(line)


func _add_log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > LOG_LINES:
		log_lines = log_lines.slice(log_lines.size() - LOG_LINES)
	log_line.emit(line)


## The launcher closes: a running server is stopped properly first.
func shutdown() -> void:
	if not running:
		return
	stop()
	var waited := 0.0
	while running and waited < STOP_WAIT + 2.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
