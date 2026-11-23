extends "res://tests/test.gd"
## Where the issues token and the reporter name come from (ui/github_issues.gd), and the debug
## menu's GitHub tab, which saves them and shows only the token's last 4 characters. Fabricated
## tokens and paths only; nothing reaches GitHub.

const TOKEN := "github_pat_TEST0000"
const OTHER := "github_pat_TEST1111"


func run() -> void:
	var env := "HUMANERROR_TEST_TOKEN_%d" % OS.get_process_id()
	var repo_file := user_dir() + "issues-token.txt"
	var settings := user_dir() + "github.cfg"
	OS.unset_environment(env)

	var none := GitHubIssues.read_token(env, repo_file, settings)
	var message: String = none.get("error", "")
	check("no token: the error names all three places", [message.contains("GitHub tab (F2)"), message.contains(repo_file), message.contains(env)], [true, true, true])

	check("the tab's token saves", GitHubIssues.save_token(" %s \n" % TOKEN, settings), "")
	check("it reads back trimmed", GitHubIssues.saved_token(settings), {"value": TOKEN})
	check("the saved token is the last resort", GitHubIssues.read_token(env, repo_file, settings), {"token": TOKEN, "source": "the GitHub tab"})
	_write(repo_file, "﻿%s\n" % OTHER)
	check("the repo file comes before the saved token", GitHubIssues.read_token(env, repo_file, settings), {"token": OTHER, "source": repo_file})
	OS.set_environment(env, " github_pat_TEST2222 ")
	check("the environment comes first", GitHubIssues.read_token(env, repo_file, settings), {"token": "github_pat_TEST2222", "source": env})
	OS.unset_environment(env)
	_write(repo_file, "\n")
	check("an empty repo file is an error, not a fall-through", GitHubIssues.read_token(env, repo_file, settings), {"error": "%s is empty" % repo_file})
	DirAccess.remove_absolute(repo_file)

	check("the reporter name saves", GitHubIssues.save_reporter("Pierre R", settings), "")
	check("and reads back", GitHubIssues.saved_reporter(settings), "Pierre R")
	check("forget removes the token", GitHubIssues.save_token("", settings), "")
	check("and keeps the name", [GitHubIssues.saved_token(settings), GitHubIssues.saved_reporter(settings)], [{"value": ""}, "Pierre R"])

	_write(settings, "[github]\ntoken = \"unterminated\n")
	check("a broken settings file is an error", GitHubIssues.read_token(env, repo_file, settings).get("error", "").begins_with("cannot read %s" % settings), true)
	DirAccess.remove_absolute(settings)

	check("a GitHub remote names the repo", GitHubIssues.slug_of_remote("git@github.com:someone/humanerror.git"), "someone/humanerror")
	check("without git or a remote, the default repo", GitHubIssues.slug_of_remote("unknown"), GitHubIssues.DEFAULT_REPO)
	check("a remote elsewhere names none", GitHubIssues.slug_of_remote("https://gitlab.com/someone/humanerror.git"), "")

	await _tab_shows_only_the_last_four(settings)

	var screen: Object = load("res://ui/feedback_screen.gd").new()  # by path: FeedbackScreen names Game
	check("a report in user:// is named from user://", screen.call("_shown", ProjectSettings.globalize_path("user://feedback/2026_x")), "user://feedback/2026_x")
	check("a report in the checkout is named from feedback/", screen.call("_shown", "/repo/feedback/2026_x"), "feedback/2026_x")
	screen.free()


func _tab_shows_only_the_last_four(settings: String) -> void:
	var tab := VBoxContainer.new()
	tab.set_script(load("res://ui/debug_github_tab.gd"))
	tab.set(&"settings_file", settings)
	root.add_child(tab)
	await process_frame
	check("no token yet", tab.call("saved_text"), "No token saved.")
	var field: LineEdit = tab.get_child(2).get_child(0)
	check("the token field hides what it holds", field.secret, true)
	field.text = TOKEN
	(tab.get_child(3) as LineEdit).text = "Pierre"
	tab.call("save")
	check("save keeps the token and the name", [GitHubIssues.saved_token(settings), GitHubIssues.saved_reporter(settings)], [{"value": TOKEN}, "Pierre"])
	check("the field empties", field.text, "")
	check("the tab shows the last 4 characters", tab.call("saved_text"), "Token saved, ending in 0000.")
	var shown := PackedStringArray()
	for node: Node in tab.find_children("*", "Label", true, false):
		shown.append((node as Label).text)
	check("no label holds the token", "\n".join(shown).contains(TOKEN), false)
	tab.call("forget")
	check("forget shows none saved", tab.call("saved_text"), "No token saved.")
	tab.queue_free()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
