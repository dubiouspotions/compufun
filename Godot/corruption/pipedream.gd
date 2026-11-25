extends CorruptionSign
## The Pipedream (rooms/shop/pipedream.tscn, group pipedream) grows out of the trash can by the work
## desk. Stage 1: it grows with the day's warp; stage 2: it spreads to all of its pipes. While it
## shows, the trash can takes a click only to throw something in: the player can't look down into it.


func _apply(shown_stage: int) -> void:
	var found := get_tree().get_nodes_in_group(&"pipedream")
	if found.is_empty():
		push_error("pipedream: no Pipedream in the group pipedream")
	for pipes: Pipedream in found:
		pipes.stage = shown_stage
	for can: TrashCan in get_tree().get_nodes_in_group(TrashCan.GROUP):
		can.looks_in = shown_stage == 0
