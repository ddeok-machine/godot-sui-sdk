extends RefCounted

const HandoffUrl := preload("res://spikes/desktop_handoff/handoff_url.gd")
const BASE := "http://localhost:8061/connect.html"


func test_builds_all_params() -> bool:
	var u := HandoffUrl.build(BASE, 1000000, 54321, "abc123")
	return u == BASE + "?action=transfer&amount_mist=1000000&network=testnet&port=54321&state=abc123"


func test_encodes_state() -> bool:
	var u := HandoffUrl.build(BASE, 1, 2000, "a b&c=d/e")
	return u.ends_with("state=a%20b%26c%3Dd%2Fe") and not ("a b" in u)


func test_appends_to_existing_query() -> bool:
	return HandoffUrl.build(BASE + "?x=1", 1, 2000, "s").contains(".html?x=1&action=transfer")


func test_rejects_missing_params() -> bool:
	return HandoffUrl.build("", 1, 2000, "s") == "" \
		and HandoffUrl.build(BASE, 0, 2000, "s") == "" \
		and HandoffUrl.build(BASE, 1, 0, "s") == "" \
		and HandoffUrl.build(BASE, 1, 70000, "s") == "" \
		and HandoffUrl.build(BASE, 1, 2000, "") == ""


func test_origin_of() -> bool:
	return HandoffUrl.origin_of(BASE) == "http://localhost:8061" \
		and HandoffUrl.origin_of("https://example.github.io") == "https://example.github.io" \
		and HandoffUrl.origin_of("nonsense") == ""
