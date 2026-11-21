class_name Computer
extends Resource
## The computer that a customer brings to the counter.

## What Win95 looks like and holds when this computer boots.
@export var win95_setup: Win95Setup
## True when the computer runs Win95 Cambion, the possessed build (wiki: Storyline). Some corruption
## signs show only in such a computer.
@export var cambion: bool = false
## What its BIOS finds as it boots; null is the defaults of Hardware, a Pentium 100 from 1995.
@export var hardware: Hardware
## The material of the case; null is beige plastic.
@export var case_material: Material
## The stickers on the case, each with its face and place; empty is none.
@export var stickers: Array[Sticker] = []
