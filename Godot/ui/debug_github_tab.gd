extends VBoxContainer
## The GitHub tab of the debug menu: the issues token and the reporter name that F9 and the Story
## Lab's Send use on a device without a checkout (GitHubIssues). It shows only whether a token is
## saved and its last 4 characters.

const GOOD: Color = Color(0.55, 1.0, 0.55)
const BAD: Color = Color(1.0, 0.5, 0.5)
const HINT_COLOR: Color = Color(0.62, 0.62, 0.7)

## Where the token and the name are saved.
var settings_file: String = GitHubIssues.SETTINGS_FILE

var _saved: Label
var _token: LineEdit
var _reporter: LineEdit
var _result: Label
var _check: Button


func _ready() -> void:
	var note := Label.new()
	note.text = "The token stays on this device, in the game's user folder, and is never part of a build. F9 and the Story Lab's Send use it when there is no %s and no %s in a checkout." % [GitHubIssues.TOKEN_ENV, GitHubIssues.TOKEN_FILE]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override(&"font_color", HINT_COLOR)
	add_child(note)
	_saved = Label.new()
	add_child(_saved)
	var token_row := HBoxContainer.new()
	_token = LineEdit.new()
	_token.secret = true
	_token.placeholder_text = "github_pat_..."
	_token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_row.add_child(_token)
	token_row.add_child(_button("Paste", paste))
	add_child(token_row)
	_reporter = LineEdit.new()
	_reporter.placeholder_text = "Your name in reports"
	add_child(_reporter)
	var buttons := HBoxContainer.new()
	buttons.add_child(_button("Save", save))
	buttons.add_child(_button("Forget token", forget))
	_check = _button("Check", check)
	buttons.add_child(_check)
	add_child(buttons)
	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_result)
	visibility_changed.connect(_refresh)
	_refresh()


## Puts the clipboard's text in the token field.
func paste() -> void:
	_token.text = DisplayServer.clipboard_get().strip_edges()
	_show("Pasted %d characters. Save keeps them." % _token.text.length() if _token.text != "" else "The clipboard has no text.", _token.text != "")


## Saves the token in the field (an empty field keeps the saved one) and the reporter name.
func save() -> void:
	var failed := GitHubIssues.save_reporter(_reporter.text, settings_file)
	if failed == "" and _token.text.strip_edges() != "":
		failed = GitHubIssues.save_token(_token.text, settings_file)
	if failed != "":
		push_error("Debug menu, GitHub: " + failed)
		_show("Not saved: " + failed, false)
		return
	_token.text = ""
	_refresh()
	_show("Saved.", true)


## Removes the saved token.
func forget() -> void:
	var failed := GitHubIssues.save_token("", settings_file)
	if failed != "":
		push_error("Debug menu, GitHub: " + failed)
		_show("Not forgotten: " + failed, false)
		return
	_refresh()
	_show("The token is forgotten.", true)


## Reads the repo on GitHub with the token in the field, or else the one that F9 uses.
func check() -> void:
	var token := {"token": _token.text.strip_edges(), "source": "the field"}
	if token["token"] == "":
		token = GitHubIssues.read_token(GitHubIssues.TOKEN_ENV, GitHubIssues.repo_dir().path_join(GitHubIssues.TOKEN_FILE), settings_file)
	if token.has("error"):
		_show(token["error"], false)
		return
	_check.disabled = true
	_show("Checking with the token from %s..." % token["source"], true)
	var result := await GitHubIssues.new(self, token["token"], "", "HumanError-F2").check_repo()
	_check.disabled = false
	if result.has("error"):
		_show("Can't reach the repo with the token from %s: %s" % [token["source"], result["error"]], false)
	else:
		_show(result["text"], true)


## What the tab says about the saved token: "No token saved." or its last 4 characters.
func saved_text() -> String:
	return _saved.text


func _refresh() -> void:
	var saved := GitHubIssues.saved_token(settings_file)
	if saved.has("error"):
		_saved.text = String(saved["error"])
		_saved.add_theme_color_override(&"font_color", BAD)
	else:
		var token: String = saved["value"]
		_saved.text = "Token saved, ending in %s." % token.right(4) if token != "" else "No token saved."
		_saved.remove_theme_color_override(&"font_color")
	_reporter.text = GitHubIssues.saved_reporter(settings_file)


func _show(text: String, ok: bool) -> void:
	_result.text = text
	_result.add_theme_color_override(&"font_color", GOOD if ok else BAD)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button
