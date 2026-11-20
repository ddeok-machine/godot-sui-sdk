extends RefCounted
## Builds the connect-page URL. Throwaway spike code.


## Returns "" if any required value is missing or out of range.
static func build(base_url: String, amount_mist: int, port: int, state: String) -> String:
	if base_url == "" or amount_mist <= 0 or port < 1024 or port > 65535 or state == "":
		return ""
	var query := "action=%s&amount_mist=%d&network=%s&port=%d&state=%s" % [
		"transfer".uri_encode(), amount_mist, "testnet".uri_encode(), port, state.uri_encode()]
	return base_url + ("&" if "?" in base_url else "?") + query


## "http://localhost:8061/connect.html" -> "http://localhost:8061"
static func origin_of(url: String) -> String:
	var scheme_end := url.find("://")
	if scheme_end < 0:
		return ""
	var path_start := url.find("/", scheme_end + 3)
	return url if path_start < 0 else url.substr(0, path_start)
