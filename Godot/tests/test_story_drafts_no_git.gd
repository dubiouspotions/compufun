extends "res://tests/test.gd"
## The Story Lab's drafts where git doesn't run, as on a device (dev/story_lab/story_drafts.gd):
## the start commit is the build's, a draft from this build starts from the build's own file, and
## "changed on main" stays unknown.

const PATH := "res://story/days/day_1.day"


func run() -> void:
	var asked := PackedStringArray()
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(arguments: PackedStringArray) -> Dictionary:
		asked.append(" ".join(arguments))
		return {"code": StoryDrafts.NO_GIT, "out": "no git checkout"}
	var build := ["abc1234"]  # an Array: a lambda captures a String by value
	drafts.build_commit = func() -> String: return build[0]
	var original := FileAccess.get_file_as_string(PATH)
	check("the build has the story file", original != "", true)

	check("a draft saves", drafts.put(PATH, original + "\n# a writer's line\n"), "")
	check("it starts from the build's commit", drafts.start_commit(PATH), "abc1234")
	check("its start text is the build's own file", drafts.start_text(PATH), {"text": original})
	check("main didn't change it, as far as anyone can tell", drafts.main_changed(PATH), false)
	check("git was asked, and no more than that", asked.size() > 0, true)

	build[0] = "def5678"
	check("a draft from another build has no start text", drafts.start_text(PATH), {})
	check("and no change on main shows", drafts.main_changed(PATH), false)

	var reread := StoryDrafts.new(drafts.dir)
	reread.git = drafts.git
	reread.build_commit = drafts.build_commit
	check("the drafts read back", reread.load_drafts(), PackedStringArray())
	check("with their start commit", reread.start_commit(PATH), "abc1234")
	check("discard works without git", reread.discard(PATH), "")
