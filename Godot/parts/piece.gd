class_name Piece
extends RefCounted
## One real part: which Part it is, and whether it is broken. It sits in a computer, lies on a job's
## mat, or is in the player's hand.

var part: Part
var broken: bool = false


func _init(piece_part: Part, piece_broken: bool = false) -> void:
	part = piece_part
	broken = piece_broken
