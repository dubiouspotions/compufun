class_name Day
extends Resource
## One day of the week in the shop: the customers in the order they come in.

## The day of the week, 1 to 7.
@export_range(1, 7) var number: int = 1
@export var customers: Array[Customer] = []
## How far Win95 "Cambion" has changed the shop, 0 to 1. Not used in the wireframe.
@export_range(0.0, 1.0) var warp: float = 0.0
