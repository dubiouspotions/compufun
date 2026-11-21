extends CorruptionSign
## The CompuFun logo signs turn from red to Windows blue.


func _apply(shown_stage: int) -> void:
	for logo: LogoSign in LogoSign.every(get_tree()):
		logo.blue = shown_stage >= 1
