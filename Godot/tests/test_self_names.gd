extends "res://tests/test.gd"
## Customers never say the name that the dialogue shows for them (Customer.spoken_name()):
## not in their errands' conversations, the shared ones, or the phone's greeting.

const SHARED: String = "res://customers/conversations/"


func run() -> void:
	var shared: Array[Conversation] = []
	for file: String in ResourceLoader.list_directory(SHARED):
		shared.append(load(SHARED + file) as Conversation)
	var errands: Array[Errand] = []
	for d: Day in game.week.days:
		errands.append_array(d.errands)
	check("found the errands and the shared conversations", [errands.size() > 3, shared.size() > 1, null in shared], [true, true, false])
	var phone: Node = load("res://ui/phone_call.tscn").instantiate()
	var greeting := DialogueLine.new()
	greeting.text = phone.greeting
	check("the phone greeting fills in no name", greeting.text.contains("%"), false)
	phone.free()
	for errand: Errand in errands:
		var who := errand.customer
		var lines: Array[DialogueLine] = [greeting]
		for c: Conversation in errand.conversations + shared:
			lines.append_array(c.all_lines())
		for name: String in [who.spoken_name()]:
			for line: DialogueLine in lines:
				if name != "" and line.text.containsn(name):
					check("%s doesn't call %s %s" % [errand.file, who.resource_path, name], line.text, "")
