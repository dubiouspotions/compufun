extends "res://tests/test.gd"
## The software problems: Noimages breaks and fixes by a file name, a defrag finishes overnight
## only while the computer stays on, and an overheating computer switches itself off.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var noimages: Problem = load("res://problems/noimages.tres")
	var setup := Win95Setup.new()
	setup.drive_c = [folder("WINDOWS", [file("PBRUSH.EXE")])]
	noimages.software_check.apply_break(setup)
	check("Noimages renames Paint", [setup.file_at("C:\\WINDOWS\\PBRUSH.EXE"), setup.file_at("C:\\WINDOWS\\PBRUSH.EX_") != null], [null, true])
	setup.file_at("C:\\WINDOWS\\PBRUSH.EX_").name = "PBRUSH.EXE"
	check("the .EXE back fixes it", noimages.software_check.is_fixed(setup), true)

	var defrag: Problem = load("res://problems/defrag.tres")
	var left_on := job_with(defrag, 0)
	var switched_off := job_with(defrag, 1)
	game.jobs = [left_on, switched_off] as Array[Job]
	for job: Job in game.jobs:
		var running := game.setup_for(job) as Win95Setup
		check("fragmented at boot", running.fragmented, true)
		running.defragmenting = true
	left_on.powered = true
	game.start_day(make_day([customer(defrag)]))
	check("left on overnight: defragmented, fixed", [game.setups[left_on.customer.computer].fragmented, left_on.software_fixed], [false, true])
	check("switched off: still fragmented", [game.setups[switched_off.customer.computer].fragmented, switched_off.software_fixed], [true, false])

	var overheat := (load("res://problems/dust_overheat.tres") as Problem).duplicate() as Problem
	check("dust_overheat switches the computer off", overheat.shuts_down_after > 0.0, true)
	overheat.shuts_down_after = 0.05
	var hot := job_with(overheat, 2)
	hot.powered = true
	game.jobs = [hot] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = hot
	root.add_child(state)
	await process_frame
	state.reached_desktop()
	await create_timer(0.2).timeout
	check("an overheating computer switches itself off", hot.powered, false)
	hot.hardware_fixed = true
	game.set_powered(hot, true)
	await process_frame
	state.reached_desktop()
	await create_timer(0.2).timeout
	check("with a new fan it stays on", hot.powered, true)
	state.free()
	game.jobs = [] as Array[Job]


func job_with(problem: Problem, slot: int) -> Job:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	return Job.new(customer(problem, computer), slot, slot)


func customer(problem: Problem, computer: Computer = null) -> Customer:
	var c := Customer.new()
	c.display_name = "C%d" % randi()
	c.problem = problem
	c.computer = computer
	return c


func make_day(customers: Array[Customer]) -> Day:
	var d := Day.new()
	d.number = 2
	d.customers = customers
	return d


func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := file(folder_name)
	f.is_folder = true
	f.children = children
	return f
