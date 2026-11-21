class_name Day
extends Resource
## One day of the week in the shop: the customers in the order they come in, at most
## Game.MAX_CUSTOMERS.

## The day of the week, 1 to 7.
@export_range(1, 7) var number: int = 1
@export var customers: Array[Customer] = []
## How far Win95 "Cambion" has changed the shop, 0 to 1. Not used in the wireframe.
@export_range(0.0, 1.0) var warp: float = 0.0
## The seconds of open shop between a visitor leaving and the next customer coming in. The wait
## pauses while the counter is full.
@export_range(0.0, 600.0, 1.0, "suffix:s") var gap_seconds: float = 60.0
