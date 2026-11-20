extends RefCounted
## One-shot loopback HTTP server for the browser -> game handoff. Binds 127.0.0.1 only.
## Throwaway spike code. Poll is driven by SceneTree.process_frame.

signal result_received(result: Dictionary)
signal failed(reason: String)

const MAX_REQUEST_BYTES := 16384
const CONN_TIMEOUT_MSEC := 10000
const DIGEST_PATTERN := "^[1-9A-HJ-NP-Za-km-z]{32,64}$"

var port := 0
var timeout_sec := 300.0

var _server := TCPServer.new()
var _conns: Array = [] # {peer: StreamPeerTCP, buf: PackedByteArray, t0: int}
var _origin := ""
var _state_hash := PackedByteArray()
var _deadline_msec := 0
var _running := false
var _digest_re := RegEx.new()


func is_listening() -> bool:
	return _running


## Starts listening on an ephemeral 127.0.0.1 port. origin is the page origin allowed by CORS.
func start(origin: String, state: String) -> Error:
	if state == "" or origin == "":
		return ERR_INVALID_PARAMETER
	var err := _server.listen(0, "127.0.0.1")
	if err != OK:
		return err
	port = _server.get_local_port()
	_origin = origin
	_state_hash = state.sha256_buffer()
	_digest_re.compile(DIGEST_PATTERN)
	_deadline_msec = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	_running = true
	(Engine.get_main_loop() as SceneTree).process_frame.connect(poll)
	return OK


func cancel() -> void:
	if _running:
		stop()
		failed.emit("cancelled")


func stop() -> void:
	if not _running:
		return
	_running = false
	var tree := Engine.get_main_loop() as SceneTree
	if tree.process_frame.is_connected(poll):
		tree.process_frame.disconnect(poll)
	_server.stop()
	for c in _conns:
		c["peer"].disconnect_from_host()
	_conns.clear()


func poll() -> void:
	if not _running:
		return
	if Time.get_ticks_msec() > _deadline_msec:
		stop()
		failed.emit("timeout")
		return
	while _server.is_connection_available():
		_conns.append({"peer": _server.take_connection(), "buf": PackedByteArray(), "t0": Time.get_ticks_msec()})
	var i := 0
	while i < _conns.size() and _running:
		var c: Dictionary = _conns[i]
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		var drop := false
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var n := peer.get_available_bytes()
			if n > 0:
				var got := peer.get_data(n)
				if got[0] == OK:
					c["buf"].append_array(got[1])
			if c["buf"].size() > MAX_REQUEST_BYTES:
				_respond(peer, 413, "text/plain", "too large")
				drop = true
			elif _try_handle(c):
				drop = true
			elif Time.get_ticks_msec() - c["t0"] > CONN_TIMEOUT_MSEC:
				drop = true
		elif peer.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			drop = true
		if not _running:
			return # a valid callback stopped the server; stop() already closed everything
		if drop:
			peer.disconnect_from_host()
			_conns.remove_at(i)
		else:
			i += 1


## Returns true when the request was complete and has been answered.
func _try_handle(c: Dictionary) -> bool:
	var text: String = (c["buf"] as PackedByteArray).get_string_from_utf8()
	var head_end := text.find("\r\n\r\n")
	if head_end < 0:
		return false
	var lines := text.substr(0, head_end).split("\r\n")
	var req := lines[0].split(" ")
	if req.size() != 3:
		_respond(c["peer"], 400, "text/plain", "bad request")
		return true
	var headers := {}
	for l in lines.slice(1):
		var idx: int = l.find(":")
		if idx > 0:
			headers[l.substr(0, idx).strip_edges().to_lower()] = l.substr(idx + 1).strip_edges()
	var body_len := int(headers.get("content-length", "0"))
	var body_bytes: PackedByteArray = (c["buf"] as PackedByteArray).slice(head_end + 4)
	if body_bytes.size() < body_len:
		return false
	var body := body_bytes.slice(0, body_len).get_string_from_utf8()
	_handle(c["peer"], req[0], req[1], headers, body)
	return true


func _handle(peer: StreamPeerTCP, method: String, target: String, headers: Dictionary, body: String) -> void:
	var path := target.get_slice("?", 0)
	if path != "/cb":
		_respond(peer, 404, "text/plain", "not found")
		return
	# DNS-rebinding guard: only accept loopback Host headers.
	var host: String = headers.get("host", "")
	if host != "127.0.0.1:%d" % port and host != "localhost:%d" % port:
		_respond(peer, 403, "text/plain", "bad host")
		return
	if method == "OPTIONS":
		_respond(peer, 204, "", "")
		return
	if headers.has("origin") and headers["origin"] != _origin:
		_respond(peer, 403, "text/plain", "bad origin")
		return
	var state := ""
	var digest := ""
	if method == "POST":
		var data = JSON.parse_string(body)
		if data is Dictionary:
			state = str(data.get("state", ""))
			digest = str(data.get("digest", ""))
	elif method == "GET":
		var query := target.get_slice("?", 1) if "?" in target else ""
		for pair in query.split("&"):
			var k := pair.get_slice("=", 0).uri_decode()
			var v := pair.get_slice("=", 1).uri_decode() if "=" in pair else ""
			if k == "state":
				state = v
			elif k == "digest":
				digest = v
	else:
		_respond(peer, 405, "text/plain", "method not allowed")
		return
	var html := method == "GET"
	if state == "" or not _constant_time_equal(state):
		_respond(peer, 403, "text/html" if html else "application/json",
			"<p>Rejected.</p>" if html else '{"ok":false}')
		return
	if _digest_re.search(digest) == null:
		_respond(peer, 400, "text/html" if html else "application/json",
			"<p>Bad digest.</p>" if html else '{"ok":false}')
		return
	_respond(peer, 200, "text/html" if html else "application/json",
		"<!doctype html><title>Done</title><p>You can close this tab.</p>" if html else '{"ok":true}')
	stop()
	result_received.emit({"digest": digest})


func _constant_time_equal(state: String) -> bool:
	return Crypto.new().constant_time_compare(state.sha256_buffer(), _state_hash)


func _respond(peer: StreamPeerTCP, code: int, content_type: String, body: String) -> void:
	var reasons := {200: "OK", 204: "No Content", 400: "Bad Request", 403: "Forbidden", 404: "Not Found",
		405: "Method Not Allowed", 413: "Payload Too Large"}
	var body_bytes := body.to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\n" % [code, reasons.get(code, "Error")]
	head += "Access-Control-Allow-Origin: %s\r\n" % _origin
	head += "Access-Control-Allow-Private-Network: true\r\n"
	head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	head += "Access-Control-Allow-Headers: Content-Type\r\n"
	head += "Access-Control-Max-Age: 60\r\nVary: Origin\r\nCache-Control: no-store\r\n"
	if code != 204:
		head += "Content-Type: %s; charset=utf-8\r\nContent-Length: %d\r\n" % [content_type, body_bytes.size()]
	head += "Connection: close\r\n\r\n"
	var out := head.to_utf8_buffer()
	out.append_array(body_bytes)
	peer.put_data(out)
