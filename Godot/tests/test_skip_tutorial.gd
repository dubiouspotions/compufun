extends "res://tests/test.gd"
## Day 1's tutorial (the middle manager, who comes before opening): main holds his talk while
## talk_held is set, as the loading screen does until its zoom is part way; then the box starts with
## his first line and the Skip tutorial button shows. Skip jumps to where the tutorial leaves the
## player: nobody in, the shop CLOSED and ready to open, no walk out.

const FIRST_LINE: String = "...so as mentioned I'm off for vacation. I'll need you to mind the store for me until I'm back."


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	main.set(&"talk_held", true)
	root.add_child(main)
	await process_frame
	var box: Control = main.get_node("%DialogueOverlay")
	var calling: Control = main.get_node("%CustomerCalling")
	var skip: Button = main.get_node("%SkipTutorial")
	check("held: he is in and talking, but no box, no call-out and no Skip yet",
		[game.phase, game.visitor_state, game.can_skip_before_opening(), box.visible, calling.visible, skip.visible],
		[game.Phase.CLOSED, game.VisitorState.TALKING, true, false, false, false])

	main.set(&"talk_held", false)
	await process_frame
	var line: DialogueLine = box.call(&"shown_line")
	check("let go: the box starts at his first line, and Skip shows", [box.visible, line.text if line != null else "", skip.visible], [true, FIRST_LINE, true])

	var jump: int = game.jump
	skip.pressed.emit()
	await process_frame
	check("skipped: nobody in, the shop ready to open, by a jump", [game.visitor, game.visitor_state, game.phase, game.can_open(), game.jump == jump + 1],
		[null, game.VisitorState.NONE, game.Phase.CLOSED, true, true])
	check("the box and Skip are gone; the tutorial counts as seen", [box.visible, skip.visible, game.seen.has("0101/drop-off/1"), game.arrivals], [false, false, true, 1])
	check("nothing to skip any more", game.can_skip_before_opening(), false)
	game.skip_before_opening()
	check("a second skip changes nothing", game.jump, jump + 1)

	game.open_shop()
	tick(game.day.first_wait_seconds.y + 0.1)
	check("after opening, the day's second errand comes", [game.phase, game.arrivals, game.errand.code], [game.Phase.OPEN, 2, "0102"])
	check("Skip stays hidden on a drop-off after opening", skip.visible, false)
	main.queue_free()
	await process_frame
