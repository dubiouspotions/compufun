extends "res://tests/test.gd"
## Customers never say the name that the dialogue shows for them (Customer.spoken_name()):
## not in their errands' conversations, the shared ones (the phone's greeting too), their call-outs
## and everyone's.

const SHARED: String = "res://customers/conversations/"


func run() -> void:
	var shared: Array[Conversation] = []
	for file: String in ResourceLoader.list_directory(SHARED):
		shared.append(load(SHARED + file) as Conversation)
	shared.append_array(game.week.call_outs[CallOuts.EVERYONE].sets)
	var errands: Array[Errand] = []
	for d: Day in game.week.days:
		errands.append_array(d.errands)
	check("found the errands and the shared conversations", [errands.size() > 3, shared.size() > 1, null in shared], [true, true, false])
	var phone: Node = load("res://ui/phone_call.tscn").instantiate()
	check("the phone's greeting is a shared conversation", phone.greeting in shared, true)
	phone.free()
	for errand: Errand in errands:
		var who := errand.customer
		var lines: Array[DialogueLine] = []
		var own: CallOuts = game.week.call_outs.get(StringName(who.resource_path.get_file().get_basename()))
		var call_outs: Array[Conversation] = []
		if own != null:
			call_outs.assign(own.sets)
		for c: Conversation in errand.conversations + shared + call_outs:
			lines.append_array(c.all_lines())
		for name: String in [who.spoken_name()]:
			for line: DialogueLine in lines:
				if name != "" and line.text.containsn(name):
					check("%s doesn't call %s %s" % [errand.file, who.resource_path, name], line.text, "")
