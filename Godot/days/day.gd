class_name Day
extends Resource
## One day of the week in the shop: the errands in the order the customers come in, at most
## Game.MAX_CUSTOMERS, as the timeline on the wiki's Storyline page says. A day may have none.

## The day of the week, 1 to 7.
@export_range(1, 7) var number: int = 1
@export var errands: Array[Errand] = []
## How far Win95 "Cambion" has changed the shop, 0 to 1. The corruption signs, such as the
## Pipedream, grow with it.
@export_range(0.0, 1.0) var warp: float = 0.0
## It rains outside the shop all day, from the closed morning to the evening (see Outside).
@export var rain: bool = false
## The flags that the day sets as it starts: name to number, where 0 clears the flag. A day starts a
## corruption sign with sign_<id>.
@export var set_flags: Dictionary[StringName, int] = {}
## The flags that the day sets when the player closes the shop, and that stay: name to number, where
## 0 clears the flag. For a sign that lasts the rest of the week, such as &"sign_logo_blue".
@export var close_flags: Dictionary[StringName, int] = {}
## The seconds from the player opening the shop until the first customer comes in: a random time from x
## to y, picked each day.
@export var first_wait_seconds: Vector2 = Vector2(5.0, 8.0)
## The seconds of open shop between a visitor leaving and the next customer coming in: a random time
## from x to y, picked at each wait. The wait pauses while the counter is full.
@export var gap_seconds: Vector2 = Vector2(20.0, 40.0)
## The corruption signs that start when the player closes the shop on this day, by id, such as
## &"posters_bounce": their flags go to 1, and back to 0 when the next day starts.
@export var close_signs: Array[StringName] = []
