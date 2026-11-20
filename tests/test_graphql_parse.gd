extends RefCounted

const Parse := preload("res://spikes/web_signing/graphql_parse.gd")


func test_parses_balance() -> bool:
	var r := Parse.parse_balance('{"data":{"address":{"balance":{"totalBalance":"1234567890"}}}}')
	return r["ok"] == true and r["mist"] == 1234567890


func test_null_balance_is_zero() -> bool:
	var r := Parse.parse_balance('{"data":{"address":{"balance":null}}}')
	return r["ok"] == true and r["mist"] == 0


func test_graphql_error() -> bool:
	var r := Parse.parse_balance('{"errors":[{"message":"bad address"}],"data":null}')
	return r["ok"] == false and r["error"] == "bad address"


func test_invalid_json() -> bool:
	return Parse.parse_balance("not json")["ok"] == false
