class_name StoryIssue
extends RefCounted
## The GitHub issue that the Story Lab's Send makes of a writer's drafts (docs/dialogue.md, "Change
## it"): per file the whole new text and a unified diff against the checkout's file, the commit
## that each draft started from, and the writer.

const LABEL: Dictionary = {"name": "story", "color": "5319E7", "description": "A writer's drafts from the Story Lab"}
const TEST_LABEL: Dictionary = {"name": "test", "color": "C5DEF5", "description": "A trial send: the issue builder leaves it"}
## A note that starts with this marks a trial send.
const TEST_MARK: String = "[test]"


## The labels of a Send with [param note]: story, and feedback so that the issue builder builds it;
## test too when the note starts with [constant TEST_MARK].
static func labels(note: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = [LABEL, GitHubIssues.FEEDBACK_LABEL]
	if note.strip_edges().to_lower().begins_with(TEST_MARK):
		found.append(TEST_LABEL)
	return found
## The unchanged lines around each change in a diff.
const CONTEXT: int = 3
const TITLE_LENGTH: int = 110


## The drafts of [param drafts] as files to send: each {"path", "text" (the draft; "" removes the
## file), "old" (the checkout's text; "" when there is no file), "commit" (where the draft started)}.
static func files(drafts: StoryDrafts) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for path: String in drafts.paths():
		found.append({"path": path, "text": drafts.texts()[path], "old": drafts.checkout_text(path), "commit": drafts.start_commit(path)})
	return found


## "Story: " and what changed (errand codes, "day 3", other file names), then the writer's
## [param note].
static func title(changed: Array[Dictionary], note: String) -> String:
	var names := PackedStringArray()
	for file: Dictionary in changed:
		var path: String = file["path"]
		var name := path.get_file()
		if path.begins_with(StoryFiles.ERRANDS_DIR) and StoryLabBoard.code_of(path) != "":
			name = StoryLabBoard.code_of(path)
		elif path.begins_with(StoryFiles.DAYS_DIR):
			name = path.get_file().get_basename().replace("_", " ")
		if name not in names:
			names.append(name)
	var text := "Story: " + ", ".join(names)
	var line := note.strip_edges().get_slice("\n", 0)
	if line != "":
		text += ": " + line
	return text if text.length() <= TITLE_LENGTH else text.left(TITLE_LENGTH - 3) + "..."


## The issue text in Markdown for [param changed] (from [method files]), with the writer's
## [param note] on top and [param writer]'s name.
static func body(changed: Array[Dictionary], note: String, writer: String) -> String:
	var out := PackedStringArray()
	out.append(note.strip_edges() if note.strip_edges() != "" else "_No note._")
	out.append("")
	out.append("From the Story Lab, by %s. Apply it as docs/dialogue.md (\"Change it\") says." % writer)
	for file: Dictionary in changed:
		var path: String = file["path"]
		var text: String = file["text"]
		var old: String = file["old"]
		var what := "removed" if text == "" else ("new" if old == "" else "changed")
		out.append("")
		out.append("### `%s` (%s, started from `%s`)" % [StoryDrafts.repo_path(path), what, file["commit"]])
		if text != "":
			out.append("")
			var fence := _fence(text)
			out.append(fence)
			out.append(text.trim_suffix("\n"))
			out.append(fence)
		out.append("")
		out.append("Diff against the file in the writer's checkout:")
		out.append("")
		out.append("```diff")
		out.append("--- a/" + StoryDrafts.repo_path(path) if old != "" else "--- /dev/null")
		out.append("+++ b/" + StoryDrafts.repo_path(path) if text != "" else "+++ /dev/null")
		out.append(diff(old, text).trim_suffix("\n"))
		out.append("```")
	return "\n".join(out) + "\n"


## The hunks of a unified diff from [param old] to [param new], line by line, with
## [constant CONTEXT] unchanged lines around each change; "" when they are the same.
static func diff(old: String, new: String) -> String:
	var a := _lines(old)
	var b := _lines(new)
	var n := a.size()
	var m := b.size()
	# common[i * (m + 1) + j]: the longest common run of lines of a from i and b from j.
	var common := PackedInt32Array()
	common.resize((n + 1) * (m + 1))
	for i: int in range(n - 1, -1, -1):
		for j: int in range(m - 1, -1, -1):
			if a[i] == b[j]:
				common[i * (m + 1) + j] = common[(i + 1) * (m + 1) + j + 1] + 1
			else:
				common[i * (m + 1) + j] = maxi(common[(i + 1) * (m + 1) + j], common[i * (m + 1) + j + 1])
	var ops: Array[Array] = []  # [mark, text, old index, new index], each index before the line
	var i := 0
	var j := 0
	while i < n or j < m:
		if i < n and j < m and a[i] == b[j]:
			ops.append([" ", a[i], i, j])
			i += 1
			j += 1
		elif j >= m or (i < n and common[(i + 1) * (m + 1) + j] >= common[i * (m + 1) + j + 1]):
			ops.append(["-", a[i], i, j])
			i += 1
		else:
			ops.append(["+", b[j], i, j])
			j += 1
	var out := PackedStringArray()
	var k := 0
	while k < ops.size():
		if ops[k][0] == " ":
			k += 1
			continue
		var start := maxi(k - CONTEXT, 0)
		var end := k
		while end < ops.size():
			if ops[end][0] != " ":
				end += 1
				continue
			var run := end
			while run < ops.size() and ops[run][0] == " ":
				run += 1
			if run >= ops.size() or run - end > CONTEXT * 2:
				end = mini(end + CONTEXT, ops.size())
				break
			end = run
		var old_count := 0
		var new_count := 0
		for op: Array in ops.slice(start, end):
			old_count += 1 if op[0] != "+" else 0
			new_count += 1 if op[0] != "-" else 0
		var old_start: int = ops[start][2] + (1 if old_count > 0 else 0)
		var new_start: int = ops[start][3] + (1 if new_count > 0 else 0)
		out.append("@@ -%d,%d +%d,%d @@" % [old_start, old_count, new_start, new_count])
		for op: Array in ops.slice(start, end):
			out.append(op[0] + op[1])
		k = end
	return "\n".join(out) + ("\n" if not out.is_empty() else "")


static func _lines(text: String) -> PackedStringArray:
	if text == "":
		return PackedStringArray()
	var lines := text.split("\n")
	if text.ends_with("\n"):
		lines.remove_at(lines.size() - 1)
	return lines


# A code fence longer than any run of backticks in [param text].
static func _fence(text: String) -> String:
	var longest := 0
	var run := 0
	for character: String in text:
		run = run + 1 if character == "`" else 0
		longest = maxi(longest, run)
	return "`".repeat(maxi(3, longest + 1))
