extends CorruptionSign
## In [member target]'s computer, while it runs Cambion (Game.runs_cambion), the Calculator shows 666
## for every result (wiki: In-world - Corruption Signs).

const _CALCULATOR := preload("res://win95/calculator.gd")

## The number that every result shows.
@export var result: int = 666
## The one customer whose computer shows it; null shows it in nobody's.
@export var target: Customer


func _apply(shown_stage: int) -> void:
	var results := {target: str(result)} if shown_stage > 0 and target != null else {}
	get_tree().root.set_meta(_CALCULATOR.CAMBION_RESULT_META, results)


func _exit_tree() -> void:
	get_tree().root.remove_meta(_CALCULATOR.CAMBION_RESULT_META)  # the root outlives the shop
