extends "res://tests/test.gd"
## The taped note says to start CompuFunDB until the sign logo_cambion starts, then CambionDB, at
## the moment that the logo signs read CambIon, and across a restore.


func run() -> void:
	var shop: Node = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(shop)
	await process_frame
	var note: Label3D = shop.get_node("Room/TapedNote/Text")
	var logo: Node = shop.get_node("Room/Sign")
	var says := func() -> Array: return [note.text.contains("Start CompuFunDB"), note.text.contains("Start CambionDB"), logo.get(&"cambion")]

	check("restore on day 6", game.restore({"day": 6, "arrivals": game.day_of(6).codes().size()}), "")
	check("before the sign: CompuFunDB", says.call(), [true, false, false])

	game.close_shop()
	check("closing day 6 starts the sign", game.flag(&"sign_logo_cambion"), 1)
	for frame: int in 120:
		var now_says: Array = says.call()
		if now_says[1] != now_says[2]:
			check("the note and the logo change together, frame %d" % frame, now_says, [now_says[0], now_says[2], now_says[2]])
		await process_frame
	check("after the sign: CambionDB, with the logo", says.call(), [false, true, true])

	check("restore with the sign", game.restore({"day": 7, "phase": "OPEN", "flags": {"sign_logo_cambion": 1}}), "")
	check("after a restore with the sign: CambionDB", says.call(), [false, true, true])
	check("restore without it", game.restore({"day": 7, "phase": "OPEN"}), "")
	check("after a restore without it: CompuFunDB", says.call(), [true, false, false])
	shop.queue_free()
	await process_frame
