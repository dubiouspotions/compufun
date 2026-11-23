class_name GitHubIssues
extends RefCounted
## Makes GitHub issues for the dev tools (F9, the Story Lab) with the team's fine-grained token; the
## board's own workflow adds each new issue to the board. Works in a run from the checkout: it reads
## the token and the repo from there.

## The environment variable that holds the token; without it, [constant TOKEN_FILE] does.
const TOKEN_ENV: String = "HUMANERROR_ISSUES_TOKEN"
## The token file in the repo root (docs/working-together.md).
const TOKEN_FILE: String = "issues-token.txt"

var _host: Node
var _token: String
var _repo: String
var _agent: String


## Sends with [param token] (from [method read_token]) to [param repo] (owner/name; "" reads it
## from git's remote origin). Each request runs on an HTTPRequest under [param host], which must
## be in the tree, and says [param agent] as its User-Agent.
func _init(host: Node, token: String, repo: String, agent: String) -> void:
	_host = host
	_token = token
	_repo = repo if repo != "" else repo_slug()
	_agent = agent


## {"token"} from [constant TOKEN_ENV] or [constant TOKEN_FILE] in the repo, or {"error"} that says
## where to put one.
static func read_token() -> Dictionary:
	var token := OS.get_environment(TOKEN_ENV).strip_edges()
	if token != "":
		return {"token": token}
	var path := repo_dir().path_join(TOKEN_FILE)
	if not FileAccess.file_exists(path):
		return {"error": "no token: put one in %s (see docs/working-together.md)" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	token = file.get_line().replace("﻿", "").strip_edges()
	if token == "":
		return {"error": "%s is empty" % path}
	return {"token": token}


## The repo root: the folder above the Godot project.
static func repo_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


## The trimmed output of git with [param arguments] in the repo, or "unknown" when git is missing
## or fails.
static func git(arguments: PackedStringArray) -> String:
	var output: Array = []
	var args := PackedStringArray(["-C", repo_dir()])
	args.append_array(arguments)
	var code := OS.execute("git", args, output, true)
	if code != 0 or output.is_empty():
		return "unknown"
	return String(output[0]).strip_edges()


## owner/name from git's remote "origin", or "" when it is not a GitHub URL.
static func repo_slug() -> String:
	var regex := RegEx.create_from_string("github\\.com[:/]([^/]+)/([^/]+?)(?:\\.git)?$")
	var found := regex.search(git(["remote", "get-url", "origin"]))
	return "%s/%s" % [found.get_string(1), found.get_string(2)] if found != null else ""


## The repo as owner/name, or "" when it is unknown.
func repo() -> String:
	return _repo


## The label of an F9 report. The issue builder builds every open issue that has it.
const FEEDBACK_LABEL: Dictionary = {"name": "feedback", "color": "FBCA04", "description": "F9 report from the game"}

## Makes the issue with [param title] and [param body] (Markdown), labelled with [param labels]
## (each {"name", "color", "description"}; made when the repo lacks it). Returns {"url"}, or
## {"error"} when there is no issue.
func create_issue(title: String, body: String, labels: Array[Dictionary]) -> Dictionary:
	if _repo == "":
		return {"error": "cannot find the GitHub repo: set it, or check git's remote origin"}
	var names: Array[String] = []
	for label: Dictionary in labels:
		var made := await api(HTTPClient.METHOD_POST, "/repos/%s/labels" % _repo, label)
		if made["code"] != 422 and made.has("error"):  # 422: the label exists.
			return {"error": "cannot make the label %s: %s" % [label["name"], made["error"]]}
		names.append(label["name"])
	var created := await api(HTTPClient.METHOD_POST, "/repos/%s/issues" % _repo, {"title": title, "body": body, "labels": names})
	if created.has("error"):
		return {"error": "cannot create the issue: %s" % created["error"]}
	return {"url": String(created["data"]["html_url"])}


## One request to the GitHub REST API at [param path] (such as "/repos/o/n/issues"). Returns
## {"code", "data"} (the parsed JSON reply), with "error" too when there is no reply or the status
## is not 2xx. [param body] null: no body.
func api(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	var url := "https://api.github.com" + path
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	_host.add_child(http)
	var headers := PackedStringArray([
		"Authorization: Bearer " + _token,
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"Content-Type: application/json",
		"User-Agent: " + _agent,
	])
	var err := http.request(url, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return {"code": 0, "error": "cannot send the request to %s: %s" % [url, error_string(err)]}
	var reply: Array = await http.request_completed
	http.queue_free()
	if reply[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "error": "no reply from %s (HTTPRequest result %d)" % [url, reply[0]]}
	var code: int = reply[1]
	var text := (reply[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	var result := {"code": code, "data": data}
	if code < 200 or code >= 300:
		var message := String(data.get("message", "")) if data is Dictionary else text.left(200)
		result["error"] = "HTTP %d from %s: %s" % [code, path, message]
	return result
