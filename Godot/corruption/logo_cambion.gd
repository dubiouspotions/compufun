extends CorruptionSign
## The CompuFun logo signs read "CambIon", in the same style and colour.


func _apply(shown_stage: int) -> void:
	for logo: LogoSign in LogoSign.every(get_tree()):
		logo.cambion = shown_stage >= 1
