extends CorruptionSign
## Clippy is gone from every computer: every WordPad shows the assistant's empty frame, as a
## computer with the NoClippy problem does (wiki: In-world - Corruption Signs).

const _WORDPAD := preload("res://win95/wordpad.gd")


func _apply(shown_stage: int) -> void:
	_WORDPAD.assistant_taken = shown_stage > 0


func _exit_tree() -> void:
	_WORDPAD.assistant_taken = false  # the static outlives the shop
