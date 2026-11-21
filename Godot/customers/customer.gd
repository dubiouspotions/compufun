class_name Customer
extends Resource
## One customer: who they are, what they say at the counter, and what is wrong with the computer.

## The name in the game.
@export var display_name: String = ""
@export var person: Person
## What the customer says at the counter, one line per entry.
@export var lines: PackedStringArray = []
## The replies that the player can choose after the last line.
@export var replies: PackedStringArray = []
@export var problem: Problem
## The trousers colour of the 3D customer. It tints the denim texture.
@export var trousers_color: Color = Color(0.46, 0.56, 0.74)
