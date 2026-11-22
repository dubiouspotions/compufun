extends "res://tests/test.gd"
## A post-it, on the counter and in the Workview, shows the exclamation mark and "Needs testing" while
## its computer is fixed but not tested, and the check once it is tested; also after a restore.


func run() -> void:
	var post_it: Node3D = (load("res://props/post_it_3d.tscn") as PackedScene).instantiate()  # untyped: both scripts name Game, which -s scripts can't compile
	var label: Control = (load("res://ui/post_it_label.tscn") as PackedScene).instantiate()
	root.add_child(post_it)
	root.add_child(label)
	var testing: Node3D = post_it.get_node("%Testing")
	var done: Node3D = post_it.get_node("%Done")
	var label_testing: Label = label.get_node("%Testing")
	var label_pickup: Label = label.get_node("%Pickup")
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
	post_it.free()
	label.free()
