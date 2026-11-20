extends Control
## Spike 1b (throwaway): browser connect page -> loopback callback -> GraphQL verification. Testnet only.

## Change this to point at GitHub Pages later.
const PAGE_URL := "http://localhost:8061/connect.html"
const GRAPHQL_URL := "https://graphql.testnet.sui.io/graphql"
const EXPLORER_TX_URL := "https://suiscan.xyz/testnet/tx/"
const AMOUNT_MIST := 1000000 # 0.001 SUI
const VERIFY_ATTEMPTS := 8
const VERIFY_DELAY_SEC := 2.0

const LoopbackServer := preload("res://spikes/desktop_handoff/loopback_server.gd")
const HandoffUrl := preload("res://spikes/desktop_handoff/handoff_url.gd")
const TxVerify := preload("res://spikes/desktop_handoff/tx_verify.gd")

var _server: RefCounted

@onready var _log: Label = %Log
@onready var _start: Button = %Start
@onready var _cancel: Button = %Cancel
@onready var _http: HTTPRequest = %Http


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_cancel.pressed.connect(_on_cancel)
	_cancel.disabled = true


func _say(msg: String) -> void:
	_log.text += msg + "\n"
	print(msg)


func _on_start() -> void:
	if _server != null and _server.is_listening():
		return
	var state := Crypto.new().generate_random_bytes(32).hex_encode()
	_server = LoopbackServer.new()
	_server.result_received.connect(_on_result)
	_server.failed.connect(_on_failed)
	var err: Error = _server.start(HandoffUrl.origin_of(PAGE_URL), state)
	if err != OK:
		_say("cannot start loopback server: " + error_string(err))
		return
	var url := HandoffUrl.build(PAGE_URL, AMOUNT_MIST, _server.port, state)
	_say("listening on 127.0.0.1:%d" % _server.port)
	_say("opening " + PAGE_URL + " in the system browser")
	var open_err := OS.shell_open(url)
	if open_err != OK:
		_say("shell_open failed: " + error_string(open_err))
		_server.cancel()
		return
	_start.disabled = true
	_cancel.disabled = false


func _on_cancel() -> void:
	if _server != null:
		_server.cancel()


func _on_failed(reason: String) -> void:
	_say("handoff failed: " + reason)
	_start.disabled = false
	_cancel.disabled = true


func _on_result(result: Dictionary) -> void:
	_start.disabled = false
	_cancel.disabled = true
	var digest: String = result["digest"]
	_say("callback received, digest " + digest)
	await _verify(digest)


func _verify(digest: String) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	for attempt in VERIFY_ATTEMPTS:
		var err := _http.request(GRAPHQL_URL, headers, HTTPClient.METHOD_POST, TxVerify.build_request(digest))
		if err != OK:
			_say("verify request error: " + str(err))
			return
		var res: Array = await _http.request_completed
		if res[0] != HTTPRequest.RESULT_SUCCESS:
			_say("verify http failed: result " + str(res[0]))
			return
		var parsed := TxVerify.parse((res[3] as PackedByteArray).get_string_from_utf8())
		if not parsed["ok"]:
			_say("verify error: " + parsed["error"])
			return
		if parsed["found"]:
			_say("VERIFIED: status %s" % parsed["status"] if parsed["status"] == "SUCCESS"
				else "FAILED ON CHAIN: status %s" % parsed["status"])
			_say("explorer: " + EXPLORER_TX_URL + digest)
			return
		_say("not indexed yet (%d/%d)" % [attempt + 1, VERIFY_ATTEMPTS])
		await get_tree().create_timer(VERIFY_DELAY_SEC).timeout
	_say("could not verify digest (not found)")
