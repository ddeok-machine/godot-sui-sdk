extends RefCounted

const LoopbackServer := preload("res://spikes/desktop_handoff/loopback_server.gd")
const ORIGIN := "http://localhost:8061"
const STATE := "0123456789abcdef0123456789abcdef"
const DIGEST := "5Xg7Wq9pLmN2vB8cD4eF6hJ3kR1tY7uZ2aS5dG8jK9mP" # syntactically valid base58, not a real digest
const MAX_FRAMES := 600

var _frames := func() -> Signal: return (Engine.get_main_loop() as SceneTree).process_frame


func _start(timeout := 300.0) -> Array:
	var srv := LoopbackServer.new()
	srv.timeout_sec = timeout
	var seen := {"result": null, "failed": ""}
	srv.result_received.connect(func(r): seen["result"] = r)
	srv.failed.connect(func(reason): seen["failed"] = reason)
	var err := srv.start(ORIGIN, STATE)
	assert(err == OK)
	return [srv, seen]


## Real HTTP request via HTTPClient. Returns {code, headers, body} or {} on failure.
func _request(port: int, method: int, path: String, headers: Array = [], body := "") -> Dictionary:
	var c := HTTPClient.new()
	if c.connect_to_host("127.0.0.1", port) != OK:
		return {}
	var n := 0
	while c.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING] and n < MAX_FRAMES:
		c.poll()
		await _frames.call()
		n += 1
	if c.get_status() != HTTPClient.STATUS_CONNECTED:
		return {}
	if c.request(method, path, PackedStringArray(headers), body) != OK:
		return {}
	while c.get_status() == HTTPClient.STATUS_REQUESTING and n < MAX_FRAMES:
		c.poll()
		await _frames.call()
		n += 1
	if not c.has_response():
		return {}
	var out := {"code": c.get_response_code(), "headers": c.get_response_headers_as_dictionary(), "body": ""}
	var buf := PackedByteArray()
	while c.get_status() == HTTPClient.STATUS_BODY and n < MAX_FRAMES:
		c.poll()
		var chunk := PackedByteArray()
		if c.get_status() == HTTPClient.STATUS_BODY:
			chunk = c.read_response_body_chunk()
		if chunk.is_empty():
			await _frames.call()
			n += 1
		else:
			buf.append_array(chunk)
	out["body"] = buf.get_string_from_utf8()
	return out


func _post(port: int, payload: Dictionary, extra: Array = []) -> Dictionary:
	return await _request(port, HTTPClient.METHOD_POST, "/cb",
		["Content-Type: application/json"] + extra, JSON.stringify(payload))


func _settle() -> void:
	for i in 5:
		await _frames.call()


func test_valid_post_emits_result() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _post(srv.port, {"state": STATE, "digest": DIGEST}, ["Origin: " + ORIGIN])
	await _settle()
	srv.stop()
	return r.get("code") == 200 and s[1]["result"] is Dictionary and s[1]["result"]["digest"] == DIGEST


func test_wrong_state_rejected() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _post(srv.port, {"state": "ffffffffffffffffffffffffffffffff", "digest": DIGEST})
	await _settle()
	var still: bool = srv.is_listening()
	srv.stop()
	return r.get("code") == 403 and s[1]["result"] == null and still


func test_missing_state_rejected() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _post(srv.port, {"digest": DIGEST})
	await _settle()
	srv.stop()
	return r.get("code") == 403 and s[1]["result"] == null


func test_bad_digest_rejected() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _post(srv.port, {"state": STATE, "digest": "<script>"})
	await _settle()
	srv.stop()
	return r.get("code") == 400 and s[1]["result"] == null


func test_wrong_origin_rejected() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _post(srv.port, {"state": STATE, "digest": DIGEST}, ["Origin: http://evil.example"])
	await _settle()
	srv.stop()
	return r.get("code") == 403 and s[1]["result"] == null


func test_options_cors_headers() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _request(srv.port, HTTPClient.METHOD_OPTIONS, "/cb", ["Origin: " + ORIGIN,
		"Access-Control-Request-Method: POST", "Access-Control-Request-Private-Network: true"])
	srv.stop()
	var h: Dictionary = r.get("headers", {})
	return r.get("code") == 204 \
		and h.get("Access-Control-Allow-Origin") == ORIGIN \
		and h.get("Access-Control-Allow-Private-Network") == "true" \
		and "POST" in str(h.get("Access-Control-Allow-Methods", ""))


func test_get_emits_result() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _request(srv.port, HTTPClient.METHOD_GET, "/cb?state=%s&digest=%s" % [STATE, DIGEST])
	await _settle()
	srv.stop()
	return r.get("code") == 200 and "You can close this tab" in r.get("body", "") \
		and s[1]["result"] is Dictionary and s[1]["result"]["digest"] == DIGEST


func test_other_paths_ignored() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _request(srv.port, HTTPClient.METHOD_GET, "/other?state=%s&digest=%s" % [STATE, DIGEST])
	await _settle()
	var still: bool = srv.is_listening()
	srv.stop()
	return r.get("code") == 404 and s[1]["result"] == null and still


func test_closes_after_success() -> bool:
	var s := _start()
	var srv = s[0]
	var port: int = srv.port
	await _post(port, {"state": STATE, "digest": DIGEST})
	await _settle()
	if srv.is_listening():
		srv.stop()
		return false
	var late := await _post(port, {"state": STATE, "digest": DIGEST})
	return late.is_empty()


func test_times_out() -> bool:
	var s := _start(0.2)
	var n := 0
	while s[1]["failed"] == "" and n < MAX_FRAMES * 4:
		await _frames.call()
		n += 1
	var ok: bool = s[1]["failed"] == "timeout" and not s[0].is_listening()
	s[0].stop()
	return ok


func test_binds_loopback_only() -> bool:
	var s := _start()
	var srv = s[0]
	var r := await _request(srv.port, HTTPClient.METHOD_OPTIONS, "/cb")
	var reachable_elsewhere := false
	for addr in IP.get_local_addresses():
		if addr.begins_with("127.") or ":" in addr or addr.begins_with("169.254."):
			continue # skip loopback, IPv6 and link-local; the server is IPv4 only
		var peer := StreamPeerTCP.new()
		peer.connect_to_host(addr, srv.port)
		var n := 0
		while peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and n < 120:
			peer.poll()
			await _frames.call()
			n += 1
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			reachable_elsewhere = true
		peer.disconnect_from_host()
	srv.stop()
	return r.get("code") == 204 and not reachable_elsewhere
