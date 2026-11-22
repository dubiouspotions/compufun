extends "res://tests/test.gd"
## The Dialogue tab edits a conversation tree: add a choice, its reply, a follow-up, and move and
## delete them. Nothing is saved.

const DialogueEditor := preload("res://addons/dialogue_editor/dialogue_editor.gd")


func run() -> void:
	var tab := DialogueEditor.new()
	root.add_child(tab)
	await process_frame
	tab.show_customer("res://customers/skater_bro.tres")
	await process_frame
	var talk: Conversation = tab._conversation
	var before := talk.choices.size()
	tab._add_choice(talk)
	await process_frame
	var added: Choice = talk.choices[-1]
	check("a choice with one reply, selected", [talk.choices.size(), added.replies.size(), tab._node == added], [before + 1, 1, true])
	added.text = "Did you install anything?"
	tab._add_choice(added.replies[0])
	await process_frame
	check("a follow-up under the reply", added.replies[0].choices.size(), 1)
	tab._add_reply(added)
	await process_frame
	check("a second reply, selected", [added.replies.size(), tab._node == added.replies[1]], [2, true])
	tab._move_node(-1)
	await process_frame
	check("moved up", added.replies[0] == tab._node, true)
	tab._delete_node()
	await process_frame
	check("deleted; the choice is selected again", [added.replies.size(), tab._node == added], [1, true])
	check("the tree shows the choice", tab._tree_item(added).get_text(0), "> Did you install anything?")
	check("the outline has it", Story.outline(tab._customer).contains("> Player: Did you install anything?"), true)
