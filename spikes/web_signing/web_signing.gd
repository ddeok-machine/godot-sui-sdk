extends Control
## Spike 1a (throwaway): Slush connect, GraphQL balance, wallet-signed self-transfer. Testnet only.

const GRAPHQL_URL := "https://graphql.testnet.sui.io/graphql"
const WALLET_NAME := "Slush"
const SEND_MIST := 1000000 # 0.001 SUI
const Parse := preload("res://spikes/web_signing/graphql_parse.gd")

var _bridge
var _cb_connect  # keep JavaScriptBridge callback refs alive as members
var _cb_send
var _address := ""

@onready var _log: Label = %Log
@onready var _connect: Button = %Connect
@onready var _refresh: Button = %Refresh
@onready var _send: Button = %Send
@onready var _http: HTTPRequest = %Http


func _ready() -> void:
	_connect.pressed.connect(_on_connect_pressed)
	_refresh.pressed.connect(_on_refresh_pressed)
	_send.pressed.connect(_on_send_pressed)
	_http.request_completed.connect(_on_http_done)
	if not OS.has_feature("web"):
		_say("web only")
		for b in [_connect, _refresh, _send]:
			b.disabled = true
		return
	_bridge = JavaScriptBridge.get_interface("SuiBridge")
	if _bridge == null:
		_say("SuiBridge missing: sui_bridge.js not loaded")
		return
	_cb_connect = JavaScriptBridge.create_callback(_on_connect_result)
	_cb_send = JavaScriptBridge.create_callback(_on_send_result)
	_say("wallets: " + str(_bridge.listWallets()))


func _say(msg: String) -> void:
	_log.text += msg + "\n"
	print(msg)


func _on_connect_pressed() -> void:
	_say("connecting to " + WALLET_NAME + "...")
	_bridge.connectWallet(WALLET_NAME, _cb_connect)


func _on_connect_result(args: Array) -> void:
	var r = JSON.parse_string(str(args[0]))
	if r is Dictionary and r.has("address"):
		_address = r["address"]
		_say("connected: " + _address)
	else:
		_say("connect failed: " + str(r))


func _on_refresh_pressed() -> void:
	if _address == "":
		_say("connect first")
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(GRAPHQL_URL, headers, HTTPClient.METHOD_POST, Parse.build_request(_address))
	if err != OK:
		_say("request error: " + str(err))


func _on_http_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_say("http failed: result " + str(result))
		return
	var r := Parse.parse_balance(body.get_string_from_utf8())
	if r["ok"]:
		_say("balance: %s SUI (%d MIST)" % [str(r["mist"] / 1000000000.0), r["mist"]])
	else:
		_say("balance error (http %d): %s" % [code, r["error"]])


func _on_send_pressed() -> void:
	if _address == "":
		_say("connect first")
		return
	_say("requesting wallet signature...")
	_bridge.signAndExecuteTransfer(SEND_MIST, _cb_send)


func _on_send_result(args: Array) -> void:
	var r = JSON.parse_string(str(args[0]))
	if r is Dictionary and r.has("digest"):
		_say("digest: " + str(r["digest"]))
	else:
		_say("send failed: " + str(r))
