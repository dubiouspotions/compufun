extends "res://tests/test.gd"
## The taped note on the counter front reads well from the Main view, so it takes no click: nothing in
## the shop goes to the Note view (the bleak trailer still uses it).


func run() -> void:
	var shop: Node3D = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var note: Node3D = shop.get_node("Room/TapedNote")
	check("the taped note has no hotspot", note.find_children("*", "Area3D", true, false).size(), 0)
	var to_note: Array[String] = []
	for hotspot: Hotspot in shop.find_children("*", "Hotspot", true, false):
		if hotspot.view == &"Note":
			to_note.append(str(shop.get_path_to(hotspot)))
	check("no hotspot goes to the Note view", to_note, [])
	check("the Note view stays for the trailer", shop.get_node_or_null("Views/Note") != null, true)
	shop.queue_free()
