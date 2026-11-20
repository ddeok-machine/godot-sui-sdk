extends RefCounted
## Parses a Sui GraphQL balance response. Throwaway spike code.

const QUERY := "query($a: SuiAddress!) { address(address: $a) { balance(coinType: \"0x2::sui::SUI\") { totalBalance } } }"


static func build_request(address: String) -> String:
	return JSON.stringify({"query": QUERY, "variables": {"a": address}})


## Returns {"ok": true, "mist": int} or {"ok": false, "error": String}.
static func parse_balance(body: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(body) != OK or not (json.data is Dictionary):
		return {"ok": false, "error": "invalid JSON"}
	var data: Dictionary = json.data
	if data.has("errors"):
		var errors = data["errors"]
		if errors is Array and not errors.is_empty() and errors[0] is Dictionary:
			return {"ok": false, "error": str(errors[0].get("message", "GraphQL error"))}
		return {"ok": false, "error": "GraphQL error"}
	var d = data.get("data")
	if not (d is Dictionary) or not (d.get("address") is Dictionary):
		return {"ok": false, "error": "missing data.address"}
	var bal = d["address"].get("balance")
	if bal == null:
		return {"ok": true, "mist": 0}
	if not (bal is Dictionary) or not bal.has("totalBalance"):
		return {"ok": false, "error": "missing totalBalance"}
	var total := str(bal["totalBalance"])
	if not total.is_valid_int():
		return {"ok": false, "error": "bad totalBalance"}
	return {"ok": true, "mist": total.to_int()}
