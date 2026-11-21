extends CorruptionSign
## In a computer that runs Cambion (Computer.cambion), the Calculator shows 666 for every result
## (wiki: In-world - Corruption Signs).

const _CALCULATOR := preload("res://win95/calculator.gd")

## The number that every result shows.
@export var result: int = 666


func _apply(shown_stage: int) -> void:
	_CALCULATOR.cambion_result = str(result) if shown_stage > 0 else ""


func _exit_tree() -> void:
	_CALCULATOR.cambion_result = ""  # the static outlives the shop
