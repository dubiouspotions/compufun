class_name Computer
extends Resource
## The computer that a customer brings to the counter.

## What Win95 looks like and holds when this computer boots.
@export var win95_setup: Win95Setup
## The material of the case; null is beige plastic.
@export var case_material: Material
## The sticker on the front of the case; null is none.
@export var sticker: Texture2D
