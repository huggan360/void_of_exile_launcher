class_name Net
extends Node
## JSON and file requests against void.plainshow.se.

const SITE := "https://void.plainshow.se"
const USER_AGENT := "VoidOfExileLauncher/1"


## {ok, status, data (parsed JSON or {}), body (bytes), error}
func fetch(url: String, method := HTTPClient.METHOD_GET, body := {}, token := "", json := true) -> Dictionary:
	var http := HTTPRequest.new()
	http.use_threads = true
	http.timeout = 60.0
	add_child(http)
	var headers := PackedStringArray(["User-Agent: " + USER_AGENT, "Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var payload := ""
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	var err := http.request(url if url.begins_with("http") else SITE + url, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {ok = false, status = 0, data = {}, body = PackedByteArray(), error = "Couldn't connect."}
	var res: Array = await http.request_completed
	http.queue_free()
	var status: int = res[1]
	var bytes: PackedByteArray = res[3]
	var data = JSON.parse_string(bytes.get_string_from_utf8()) if json and bytes.size() < 4 << 20 else null
	if not data is Dictionary:
		data = {}
	var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var error := ""
	if not ok:
		error = str(data.get("error", "")) if data.has("error") else ("Couldn't reach the realm." if res[0] != HTTPRequest.RESULT_SUCCESS else "Error %d" % status)
	return {ok = ok, status = status, data = data, body = bytes, error = error}


func image(url: String) -> Texture2D:
	var r := await fetch(url, HTTPClient.METHOD_GET, {}, "", false)
	if not r.ok:
		return null
	var img := Image.new()
	var bytes: PackedByteArray = r.body
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		err = img.load_webp_from_buffer(bytes)
	if err != OK:
		err = img.load_jpg_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if err == OK else null
