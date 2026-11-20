extends RefCounted
## GraphQL transaction-status query and parser. Throwaway spike code.

const QUERY := "query($d: String!) { transaction(digest: $d) { digest effects { status } } }"


static func build_request(digest: String) -> String:
	return JSON.stringify({"query": QUERY, "variables": {"d": digest}})


## Returns {"ok": bool, "found": bool, "status": String, "error": String}.
## found=false with ok=true means the node does not know the digest (yet).
static func parse(body: String) -> Dictionary:
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
	if not (d is Dictionary):
		return {"ok": false, "error": "missing data"}
	var tx = d.get("transaction")
	if tx == null:
		return {"ok": true, "found": false}
	if not (tx is Dictionary) or not (tx.get("effects") is Dictionary):
		return {"ok": false, "error": "missing effects"}
	return {"ok": true, "found": true, "status": str(tx["effects"].get("status", ""))}
