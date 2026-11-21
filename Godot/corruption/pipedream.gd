extends CorruptionSign
## The Pipedream (rooms/shop/pipedream.tscn, group pipedream) grows out of the corner behind the
## player. Stage 1: it grows with the day's warp; stage 2: it spreads to all of its pipes.


func _apply(shown_stage: int) -> void:
	var found := get_tree().get_nodes_in_group(&"pipedream")
	if found.is_empty():
		push_error("pipedream: no Pipedream in the group pipedream")
	for pipes: Pipedream in found:
		pipes.stage = shown_stage
