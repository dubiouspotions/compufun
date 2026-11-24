extends "res://tests/test.gd"
## A post-it, on the counter and in the Workview, shows the exclamation mark and "Needs testing" while
## its computer is fixed but not tested, the check once it is tested, and the X and "Failed to pickup"
## once a call about it rang out; also after a restore.


func run() -> void:
	var post_it: Node3D = (load("res://props/post_it_3d.tscn") as PackedScene).instantiate()  # untyped: both scripts name Game, which -s scripts can't compile
	var label: Control = (load("res://ui/post_it_label.tscn") as PackedScene).instantiate()
	root.add_child(post_it)
	root.add_child(label)
	var testing: Node3D = post_it.get_node("%Testing")
	var done: Node3D = post_it.get_node("%Done")
	var label_testing: Label = label.get_node("%Testing")
	var label_pickup: Label = label.get_node("%Pickup")
	var failed: Node3D = post_it.get_node("%Failed")
	var label_failed: Label = label.get_node("%Failed")
	for fixed: bool in [false, true]:
		check("restore a computer, fixed %s, untested" % fixed, game.restore({"day": 1, "jobs": [{"customer": "res://customers/skater_bro.tres",
			"problem": "dust_overheat", "slot": 0, "hardware_fixed": fixed, "tested": false}]}), "")
		var job: Job = game.jobs[0]
		post_it.set("job", job)
		label.set("job", job)
		check("fixed %s: Needs testing shows only when fixed, with no check" % fixed,
			[testing.visible, label_testing.visible, done.visible, label_pickup.visible], [fixed, fixed, false, false])
	check("it reads Needs testing", [(post_it.get_node("%TestingText") as Label3D).text, label_testing.text.replace("\n", " ")], ["Needs testing", "Needs testing"])
	game.set_tested(game.jobs[0])
	check("tested: the check and the pickup prompt replace it", [testing.visible, label_testing.visible, done.visible, label_pickup.visible],
		[false, false, true, true])
	check("no X yet", [failed.visible, label_failed.visible], [false, false])

	var state: Dictionary = game.snapshot()
	state["jobs"][0]["unanswered"] = true
	check("restore it after its call rang out", game.restore(state), "")
	post_it.set("job", game.jobs[0])
	label.set("job", game.jobs[0])
	check("the X and Failed to pickup replace the check", [failed.visible, label_failed.visible, done.visible, label_pickup.visible, testing.visible, label_testing.visible],
		[true, true, false, false, false, false])
	check("it reads Failed to pickup", [(post_it.get_node("%FailedText") as Label3D).text, label_failed.text.replace("\n", " ")], ["Failed to pickup", "Failed to pickup"])
	game.jobs[0].tested = false
	game.changed.emit()
	check("also when it needs testing again", [failed.visible, label_failed.visible, testing.visible, label_testing.visible], [true, true, false, false])
	post_it.free()
	label.free()
