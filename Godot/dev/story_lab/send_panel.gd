class_name StorySendPanel
extends Control
## The Story Lab's Send, over the Lab: the drafted files and a one-line note, sent as one GitHub
## issue with the label story (StoryIssue). The drafts stay until main has them.

## Sending ended: [param text] says how, for the Lab's status line; [param ok] is false when no
## issue was made.
signal sent(text: String, ok: bool)

## The GitHub repo as owner/name; "" reads it from git's remote origin.
var github_repo: String = ""

var _drafts: StoryDrafts
var _files: Label
var _note: LineEdit
var _send: Button
var _status: Label
var _sending: bool = false


func _ready() -> void:
	_build()
	hide()


## Shows what Send would send of [param drafts].
func show_send(drafts: StoryDrafts) -> void:
	_drafts = drafts
	var names := PackedStringArray()
	for path: String in drafts.paths():
		names.append("%s (%s)" % [path.trim_prefix("res://story/"), StoryDraftsPanel.kind(drafts, path)])
	_files.text = "\n".join(names) if not names.is_empty() else "No drafts to send."
	_send.disabled = names.is_empty() or _sending
	_status.text = ""
	show()
	_note.grab_focus()


## The name that the issue gives the writer: git's user.name, or else the login.
static func writer() -> String:
	var name := GitHubIssues.git(["config", "user.name"])
	if name != "unknown" and name != "":
		return name
	return OS.get_environment("USER") if OS.has_environment("USER") else OS.get_environment("USERNAME")


func _send_now() -> void:
	if _sending or _drafts == null or _drafts.paths().is_empty():
		return
	var token := GitHubIssues.read_token()
	if token.has("error"):
		_done("Not sent: %s. Your drafts stay." % token["error"], false)
		return
	var github := GitHubIssues.new(self, token["token"], github_repo, "HumanError-StoryLab")
	var files := StoryIssue.files(_drafts)
	_sending = true
	_send.disabled = true
	_status.text = "Sending to GitHub..."
	var result := await github.create_issue(StoryIssue.title(files, _note.text), StoryIssue.body(files, _note.text, writer()), StoryIssue.labels(_note.text))
	_sending = false
	_send.disabled = false
	if result.has("error"):
		push_error("Story Lab: not sent to GitHub: %s" % result["error"])
		_done("Not sent: %s. Your drafts stay." % String(result["error"]).get_slice("\n", 0), false)
		return
	var text := "Issue #%s created" % String(result["url"]).get_file()
	print("Story Lab sent: %s" % result["url"])
	_note.text = ""
	_done(text + ". Your drafts stay until main has them.", true)


func _done(text: String, ok: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", LabUI.GOOD if ok else LabUI.BAD)
	sent.emit(text, ok)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and not _sending:
			hide())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(820, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(LabUI.label("Send your drafts to the team", 24))
	var about := LabUI.label("Send makes one GitHub issue with each file whole and what changed. Someone applies it to main; your drafts stay until then.", 14, LabUI.DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	_files = LabUI.label("", 14)
	box.add_child(_files)
	_note = LineEdit.new()
	_note.placeholder_text = "One line: what you changed and why. Start with [test] for a trial send."
	_note.text_submitted.connect(func(_t: String) -> void: _send_now())
	box.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_send = LabUI.button("Send", _send_now, &"AccentButton")
	row.add_child(_send)
	row.add_child(LabUI.button("Cancel", hide, &"FlatButton"))
	_status = LabUI.label("", 14, LabUI.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
