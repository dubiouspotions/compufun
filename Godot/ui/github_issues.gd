class_name GitHubIssues
extends RefCounted
## Makes GitHub issues for the dev tools (F9, the Story Lab) with the team's fine-grained token; the
## board's own workflow adds each new issue to the board. In a run from the checkout it reads the
## token, the repo and the writer's name from there; on a device, from the debug menu's GitHub tab
## (user://).

## The environment variable that holds the token; without it, [constant TOKEN_FILE] does.
const TOKEN_ENV: String = "HUMANERROR_ISSUES_TOKEN"
## The token file in the repo root (docs/working-together.md).
const TOKEN_FILE: String = "issues-token.txt"
## The debug menu's GitHub tab saves the token and the reporter name here, on this device only.
const SETTINGS_FILE: String = "user://github.cfg"
## The repo for the issues where git can't tell.
const DEFAULT_REPO: String = "dubiouspotions/humanerror"
const _SECTION: String = "github"

var _host: Node
var _token: String
var _repo: String
var _agent: String


## Sends with [param token] (from [method read_token]) to [param repo] (owner/name; "" is
## [method repo_slug]). Each request runs on an HTTPRequest under [param host], which must
## be in the tree, and says [param agent] as its User-Agent.
func _init(host: Node, token: String, repo_name: String, agent: String) -> void:
	_host = host
	_token = token
	_repo = repo_name if repo_name != "" else repo_slug()
	_agent = agent


## {"token", "source"} from [param env] (the environment variable), else [param repo_file], else
## the token that the debug menu's GitHub tab saved in [param settings_file]; "source" names the
## one used. Or {"error"} that names all three places, or why one doesn't read.
static func read_token(env: String = TOKEN_ENV, repo_file: String = repo_dir().path_join(TOKEN_FILE), settings_file: String = SETTINGS_FILE) -> Dictionary:
	var token := OS.get_environment(env).strip_edges()
	if token != "":
		return {"token": token, "source": env}
	if FileAccess.file_exists(repo_file):
		var file := FileAccess.open(repo_file, FileAccess.READ)
		if file == null:
			return {"error": "cannot read %s: %s" % [repo_file, error_string(FileAccess.get_open_error())]}
		token = file.get_line().replace("\ufeff", "").strip_edges()
		if token == "":
			return {"error": "%s is empty" % repo_file}
		return {"token": token, "source": repo_file}
	var saved := _setting(settings_file, "token")
	if saved.has("error"):
		return saved
	if saved["value"] != "":
		return {"token": saved["value"], "source": "the GitHub tab"}
	return {"error": "no token: add one in the debug menu's GitHub tab (F2), put one in %s, or set %s (see docs/working-together.md)" % [repo_file, env]}


## {"value"}: the token that the GitHub tab saved, "" when there is none; or {"error"} when
## [param settings_file] doesn't read.
static func saved_token(settings_file: String = SETTINGS_FILE) -> Dictionary:
	return _setting(settings_file, "token")


## Saves [param token] in [param settings_file] and reads it back; "" removes it. Returns "" or
## what failed.
static func save_token(token: String, settings_file: String = SETTINGS_FILE) -> String:
	return _set_setting(settings_file, "token", token.strip_edges())


## The reporter name that the GitHub tab saved, or "" when there is none.
static func saved_reporter(settings_file: String = SETTINGS_FILE) -> String:
	var saved := _setting(settings_file, "reporter")
	if saved.has("error"):
		push_error("GitHub settings: " + String(saved["error"]))
		return ""
	return saved["value"]


## Saves [param name] as the reporter name in [param settings_file]; "" removes it. Returns "" or
## what failed.
static func save_reporter(name: String, settings_file: String = SETTINGS_FILE) -> String:
	return _set_setting(settings_file, "reporter", name.strip_edges())


## The name of the person who reports or sends: git's user.name, else the GitHub tab's reporter
## name, else the login; "" when none is known.
static func reporter_name(settings_file: String = SETTINGS_FILE) -> String:
	var name := git(["config", "user.name"])
	if name != "unknown" and name != "":
		return name
	name = saved_reporter(settings_file)
	if name != "":
		return name
	return OS.get_environment("USER") if OS.has_environment("USER") else OS.get_environment("USERNAME")


## {"value"} of [param key] ("" when unset), or {"error"} when [param file] doesn't read.
static func _setting(file: String, key: String) -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(file)
	if err == ERR_FILE_NOT_FOUND:
		return {"value": ""}
	if err != OK:
		return {"error": "cannot read %s: %s" % [file, error_string(err)]}
	return {"value": String(config.get_value(_SECTION, key, ""))}


static func _set_setting(file: String, key: String, value: String) -> String:
	var config := ConfigFile.new()
	var err := config.load(file)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		return "cannot read %s: %s" % [file, error_string(err)]
	if value == "":
		if config.has_section_key(_SECTION, key):
			config.erase_section_key(_SECTION, key)
	else:
		config.set_value(_SECTION, key, value)
	err = config.save(file)
	if err != OK:
		return "cannot write %s: %s" % [file, error_string(err)]
	var back := _setting(file, key)
	if back.has("error"):
		return back["error"]
	return "" if back["value"] == value else "%s read back different from what was written" % file


## The repo root: the folder above the Godot project.
static func repo_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


## True when [method repo_dir] is a git checkout (.git is a folder, or a file in a worktree). An
## export, and every iOS build, has none.
static func in_checkout() -> bool:
	var dot_git := repo_dir().path_join(".git")
	return DirAccess.dir_exists_absolute(dot_git) or FileAccess.file_exists(dot_git)


## The trimmed output of git with [param arguments] in the repo, or "unknown" when there is no
## checkout, or git is missing or fails.
static func git(arguments: PackedStringArray) -> String:
	if not in_checkout():
		return "unknown"
	var output: Array = []
	var args := PackedStringArray(["-C", repo_dir()])
	args.append_array(arguments)
	var code := OS.execute("git", args, output, true)
	if code != 0 or output.is_empty():
		return "unknown"
	return String(output[0]).strip_edges()


## owner/name from git's remote "origin", [constant DEFAULT_REPO] when git or the remote is
## missing, or "" when the remote is not a GitHub URL.
static func repo_slug() -> String:
	return slug_of_remote(git(["remote", "get-url", "origin"]))


## owner/name from [param remote] (the output of [method git], "unknown" when it failed).
static func slug_of_remote(remote: String) -> String:
	if remote == "unknown":
		return DEFAULT_REPO
	var regex := RegEx.create_from_string("github\\.com[:/]([^/]+)/([^/]+?)(?:\\.git)?$")
	var found := regex.search(remote)
	return "%s/%s" % [found.get_string(1), found.get_string(2)] if found != null else ""


## The repo as owner/name, or "" when it is unknown.
func repo() -> String:
	return _repo


## Reads the repo with the token: {"text"} that says it was reached and whether the token can
## write to it, or {"error"} with the HTTP status and GitHub's message.
func check_repo() -> Dictionary:
	if _repo == "":
		return {"error": "cannot find the GitHub repo: check git's remote origin"}
	var reply := await api(HTTPClient.METHOD_GET, "/repos/%s" % _repo)
	if reply.has("error"):
		return {"error": reply["error"]}
	var data: Dictionary = reply["data"] if reply["data"] is Dictionary else {}
	var permissions: Dictionary = data.get("permissions", {})
	var write := "unknown" if not permissions.has("push") else ("yes" if permissions["push"] else "no")
	return {"text": "Reached %s (HTTP %d). Can write: %s." % [_repo, reply["code"], write]}


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
