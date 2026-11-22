extends "res://tests/test.gd"
## The software problems: Noimages breaks and fixes every program's file name, a defrag finishes overnight
## only while the computer stays on, and an overheating computer hangs and reboots.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var noimages: Problem = load("res://problems/noimages.tres")
	var programs := ["NOTEPAD", "WORDPAD", "PBRUSH", "CALC", "EXCHNG32", "SNDVOL32", "DEFRAG", "SOL", "MPLAYER"]
	var setup := Win95Setup.new()
	var exes: Array[Resource] = []
	for each: String in programs:
		exes.append(file(each + ".EXE"))
	setup.drive_c = [folder("WINDOWS", exes)]
	noimages.software_check.apply_break(setup)
	check("Noimages takes .EXE off every program", [setup.file_at("C:\\WINDOWS\\PBRUSH.EXE"), setup.file_at("C:\\WINDOWS\\NOTEPAD") != null], [null, true])
	for each: String in programs.slice(1):
		setup.file_at("C:\\WINDOWS\\" + each).name = each + ".EXE"
	check("one program still without .EXE: not fixed", noimages.software_check.is_fixed(setup), false)
	setup.file_at("C:\\WINDOWS\\NOTEPAD").name = "NOTEPAD.EXE"
	check("every .EXE back fixes it", noimages.software_check.is_fixed(setup), true)

	var defrag: Problem = load("res://problems/defrag.tres")
	var left_on := job_with(defrag, 0)
	var switched_off := job_with(defrag, 1)
	game.jobs = [left_on, switched_off] as Array[Job]
	for job: Job in game.jobs:
		var running := game.setup_for(job) as Win95Setup
		check("fragmented at boot", running.fragmented, true)
		running.defragmenting = true
	left_on.powered = true
	game.start_day(make_day(2, [[customer(), defrag]]))
	check("left on overnight: defragmented, fixed", [game.setups[left_on.customer.computer].fragmented, left_on.software_fixed], [false, true])
	check("switched off: still fragmented", [game.setups[switched_off.customer.computer].fragmented, switched_off.software_fixed], [true, false])

	var overheat := (load("res://problems/dust_overheat.tres") as Problem).duplicate() as Problem
	check("dust_overheat hangs Windows", overheat.hangs_after > 0.0, true)
	overheat.hangs_after = 0.05
	overheat.hang_seconds = 0.05
	var hot := job_with(overheat, 2)
	hot.powered = true
	game.jobs = [hot] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = hot
	root.add_child(state)
	await process_frame
	var events: Array[String] = []
	state.hanging.connect(func(_seconds: float) -> void: events.append("hang"))
	state.booted.connect(func() -> void: events.append("boot"))
	state.reached_desktop()
	await create_timer(0.3).timeout
	check("an overheating computer hangs, then reboots", events, ["hang", "boot"])
	check("the reboot keeps the power on", hot.powered, true)
	events.clear()
	overheat.hang_seconds = 0.2
	state.reached_desktop()
	await create_timer(0.1).timeout
	hot.hardware_fixed = true
	await create_timer(0.3).timeout
	check("a hang still reboots when the fan is fixed meanwhile", events, ["hang", "boot"])
	events.clear()
	state.reached_desktop()
	await create_timer(0.3).timeout
	check("with a new fan it stays up", events, [])
	check("and staying up tests it", [hot.tested, hot.done], [true, true])
	game.set_powered(hot, false)
	game.turn_screw(hot, 0)
	game.turn_screw(hot, 0)
	check("switched off, a screw out and back in needs a new test", [hot.fixed, hot.tested], [true, false])
	state.free()
	game.jobs = [] as Array[Job]


func job_with(problem: Problem, slot: int) -> Job:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	return Job.new(customer(computer), problem, slot, slot)


func customer(computer: Computer = null) -> Customer:
	var c := Customer.new()
	c.display_name = "C%d" % randi()
	c.computer = computer
	return c



func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := file(folder_name)
	f.is_folder = true
	f.children = children
	return f
