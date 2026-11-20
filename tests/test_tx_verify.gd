extends RefCounted

const TxVerify := preload("res://spikes/desktop_handoff/tx_verify.gd")


func test_success() -> bool:
	var r := TxVerify.parse('{"data":{"transaction":{"digest":"x","effects":{"status":"SUCCESS"}}}}')
	return r["ok"] and r["found"] and r["status"] == "SUCCESS"


func test_failure_status() -> bool:
	var r := TxVerify.parse('{"data":{"transaction":{"digest":"x","effects":{"status":"FAILURE"}}}}')
	return r["ok"] and r["found"] and r["status"] == "FAILURE"


func test_not_found() -> bool:
	var r := TxVerify.parse('{"data":{"transaction":null}}')
	return r["ok"] and not r["found"]


func test_error() -> bool:
	return not TxVerify.parse('{"errors":[{"message":"boom"}]}')["ok"] and not TxVerify.parse("x")["ok"]
