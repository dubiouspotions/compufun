extends "res://tests/test.gd"
## Customers never say the names that the player gave them (display_name, the person's nickname):
## not in their own conversations, the shared ones, or the phone's greeting.

const CUSTOMERS: String = "res://customers/%s"


func run() -> void:
	var customers: Array[Customer] = []
	var shared: Array[Conversation] = []
	for file: String in ResourceLoader.list_directory(CUSTOMERS % ""):
		if file.ends_with(".tres"):
			customers.append(load(CUSTOMERS % file) as Customer)
	for file: String in ResourceLoader.list_directory(CUSTOMERS % "conversations/"):
		shared.append(load(CUSTOMERS % "conversations/" + file) as Conversation)
	check("found the customers and the shared conversations", [customers.size() > 3, shared.size() > 1, null in customers, null in shared], [true, true, false, false])
	var phone: Node = load("res://ui/phone_call.tscn").instantiate()
	var greeting := DialogueLine.new()
	greeting.text = phone.greeting
	check("the phone greeting fills in no name", greeting.text.contains("%"), false)
	phone.free()
	for who: Customer in customers:
		var lines: Array = [greeting]
		for c: Conversation in who.conversations + shared:
			lines.append_array(c.lines)
		for name: String in [who.display_name, who.spoken_name()]:
			for line: DialogueLine in lines:
				if name != "" and line.text.containsn(name):
					check("%s doesn't call themselves %s" % [who.resource_path, name], line.text, "")
