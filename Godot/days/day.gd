class_name Day
extends Resource
## One day of the week in the shop: the customers in the order they come in, at most
## Game.MAX_CUSTOMERS.

## The day of the week, 1 to 7.
@export_range(1, 7) var number: int = 1
@export var customers: Array[Customer] = []
## How far Win95 "Cambion" has changed the shop, 0 to 1. The corruption signs, such as the
## Pipedream, grow with it.
@export_range(0.0, 1.0) var warp: float = 0.0
## It rains outside the shop all day, from the closed morning to the evening (see Outside).
@export var rain: bool = false
## The seconds from the player opening the shop until the first customer comes in: a random time from x
## to y, picked each day.
@export var first_wait_seconds: Vector2 = Vector2(5.0, 8.0)
## The seconds of open shop between a visitor leaving and the next customer coming in: a random time
## from x to y, picked at each wait. The wait pauses while the counter is full.
@export var gap_seconds: Vector2 = Vector2(20.0, 40.0)
