class_name Updater
extends Node
## Installs and patches the game from the release store on void.plainshow.se.
##
## Each release manifest lists every file as a run of content-addressed chunks
## (server/void_release.py in void_of_exile_account). A changed file is rebuilt
## from chunks already on disk; only chunks the old build lacked are fetched.
## Every chunk is checked against its SHA-256 before it is written.

signal progress(done: int, total: int, text: String)

const STATE := ".void_manifest.json"
const PARALLEL := 6
const AHEAD := 24

var net: Net
var install_dir := ""
var cancelled := false

var _results := {}
var _next := 0
var _in_flight := 0
var _failed := ""
var _done := 0
var _total := 0
var _speed_bytes := 0
var _speed_time := 0.0
var _speed := 0.0

signal _chunk_landed


func _init(net_node: Net) -> void:
	net = net_node
	install_dir = OS.get_user_data_dir().path_join("game")


static func platform() -> String:
	match OS.get_name():
		"Windows": return "windows-x86_64"
		"macOS": return "macos-universal"
		_: return "linux-x86_64" if Engine.get_architecture_name() == "x86_64" else "linux-" + Engine.get_architecture_name()


func installed() -> Dictionary:
	var text := FileAccess.get_file_as_string(install_dir.path_join(STATE))
	var data = JSON.parse_string(text) if text != "" else null
	return data if data is Dictionary else {}


func installed_version() -> String:
	return str(installed().get("version", ""))


func executable() -> String:
	var state := installed()
	return install_dir.path_join(str(state.get("launch", ""))) if state.has("launch") else ""


func _process(delta: float) -> void:
	_speed_time += delta
	if _speed_time >= 1.0:
		_speed = lerpf(_speed, _speed_bytes / _speed_time, 0.6)
		_speed_bytes = 0
		_speed_time = 0.0


## Brings the install to `latest` (the /launcher/v1/latest reply). "" on success.
func update(latest: Dictionary, verify := false) -> String:
	cancelled = false
	_failed = ""
	var spec: Dictionary = latest.get("platforms", {}).get(platform(), {})
	if spec.is_empty():
		return "Void of Exile isn't available for this system yet."
	progress.emit(0, 0, "Reading the release")
	var r := await net.fetch(str(spec.manifest_url))
	if not r.ok:
		return "Couldn't read the release: " + r.error
	var manifest: Dictionary = r.data
	var chunks_url := str(latest.chunks_url)
	DirAccess.make_dir_recursive_absolute(install_dir)
	var old := installed()
	var old_files := {}
	for f: Dictionary in old.get("files", []):
		old_files[f.path] = f

	# Plan: which files change, and how many bytes must come over the network.
	var work: Array[Dictionary] = []
	_total = 0
	_done = 0
	for f: Dictionary in manifest.files:
		var path := install_dir.path_join(f.path)
		var same: bool = old_files.has(f.path) and old_files[f.path].sha256 == f.sha256 and FileAccess.file_exists(path) \
				and FileAccess.get_size(path) == int(f.size)
		if same and not verify:
			continue
		var local := _local_chunks(old_files.get(f.path, {}), path) if FileAccess.file_exists(path) else {}
		for c: Dictionary in f.chunks:
			if not local.has(c.h):
				_total += int(c.z)
		work.append({file = f, local = local})
	if work.is_empty():
		return ""
	for job in work:
		if cancelled:
			return "Cancelled."
		var err := await _build(job.file, job.local, chunks_url)
		if err != "":
			return err
	# Files the new build no longer has.
	var keep := {}
	for f: Dictionary in manifest.files:
		keep[f.path] = true
	for p: String in old_files:
		if not keep.has(p):
			DirAccess.remove_absolute(install_dir.path_join(p))
	var state := manifest.duplicate()
	state.erase("files")
	state.files = manifest.files.map(func(f: Dictionary) -> Dictionary:
		return {path = f.path, size = f.size, sha256 = f.sha256, chunks = f.chunks})
	var out := FileAccess.open(install_dir.path_join(STATE), FileAccess.WRITE)
	out.store_string(JSON.stringify(state))
	out.close()
	progress.emit(_total, _total, "Ready")
	return ""


## hash -> [offset, size] of chunks inside the file currently on disk.
func _local_chunks(old_file: Dictionary, path: String) -> Dictionary:
	var out := {}
	var offset := 0
	for c: Dictionary in old_file.get("chunks", []):
		out[c.h] = [offset, int(c.s)]
		offset += int(c.s)
	if offset != FileAccess.get_size(path):
		return {}  # not the file the manifest describes
	return out


func _build(f: Dictionary, local: Dictionary, chunks_url: String) -> String:
	var path := install_dir.path_join(f.path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var part := path + ".part"
	var out := FileAccess.open(part, FileAccess.WRITE)
	if out == null:
		return "Can't write %s." % path
	var source := FileAccess.open(path, FileAccess.READ) if not local.is_empty() else null
	var chunks: Array = f.chunks
	_results.clear()
	_next = 0
	for i in chunks.size():
		_top_up(i, chunks, local, chunks_url)
		var c: Dictionary = chunks[i]
		var data := PackedByteArray()
		if local.has(c.h) and source != null:
			source.seek(local[c.h][0])
			data = source.get_buffer(local[c.h][1])
			if _sha(data) != c.h:  # damaged on disk: fetch it after all
				_in_flight += 1
				_total += int(c.z)
				_fetch(i, chunks_url, c)
				data = PackedByteArray()
		if data.is_empty():
			while not _results.has(i) and _failed == "" and not cancelled:
				_top_up(i, chunks, local, chunks_url)
				await _chunk_landed
			if _failed != "" or cancelled:
				out.close()
				DirAccess.remove_absolute(part)
				return _failed if _failed != "" else "Cancelled."
			data = _results[i]
			_results.erase(i)
		out.store_buffer(data)
		if i % 8 == 0:
			_report(f)
	out.close()
	if source != null:
		source.close()
	DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(part, path)
	if err != OK:
		return "Can't replace %s (is the game still running?)" % path.get_file()
	if f.get("exec", false) and OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
				| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER)
	return ""


## Keeps a few downloads running ahead of the write position.
func _top_up(i: int, chunks: Array, local: Dictionary, chunks_url: String) -> void:
	while _next < chunks.size() and _next - i < AHEAD and _in_flight < PARALLEL:
		if not local.has(chunks[_next].h):
			_in_flight += 1
			_fetch(_next, chunks_url, chunks[_next])
		_next += 1


func _fetch(index: int, chunks_url: String, c: Dictionary) -> void:
	var url := chunks_url + str(c.h).substr(0, 2) + "/" + str(c.h) + ".gz"
	for attempt in 4:
		if cancelled or _failed != "":
			break
		var r := await net.fetch(url, HTTPClient.METHOD_GET, {}, "", false)
		if r.ok:
			var body: PackedByteArray = r.body
			# Some proxies already undo the gzip; take the bytes either way.
			var data := body.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP) if body.size() > 2 and body[0] == 0x1f and body[1] == 0x8b else body
			if _sha(data) == c.h:
				_results[index] = data
				_done += int(c.z)
				_speed_bytes += int(c.z)
				_in_flight -= 1
				_chunk_landed.emit()
				return
		await get_tree().create_timer(1.0 + attempt * 2.0).timeout
	_in_flight -= 1
	if _failed == "":
		_failed = "Download failed. Check your connection and try again."
	_chunk_landed.emit()


func _report(f: Dictionary) -> void:
	var text := "Downloading  %s / %s" % [_mb(_done), _mb(_total)]
	if _speed > 0:
		text += "   %s/s" % _mb(int(_speed))
	progress.emit(_done, _total, text)


static func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


static func _sha(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()
