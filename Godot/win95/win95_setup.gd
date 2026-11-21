class_name Win95Setup
extends Resource
## The Win95 desktop that one customer's computer boots into. This is the starting state; at
## runtime, ComputerState changes its own copy, never this resource.

## "Windows theme": the system colours. The default is the stock Win95 palette.
@export var palette: Win95Palette = preload("res://win95/theme/palette.tres")
@export var wallpaper: Texture2D = preload("res://win95/wallpapers/win95-default.png")
## The icons on the desktop, in the order that they appear, after the system icons.
@export var desktop: Array[Win95File] = []
## The top folder of drive C.
@export var drive_c: Array[Win95File] = []
## Every email in every folder; each Email says which folder it is in.
@export var emails: Array[Email] = []
## The programs that the Start menu lists, by their name in the menu.
@export var installed_apps: PackedStringArray = []

@export_group("Sound")
## 0 to 100, as the tray volume slider shows it.
@export_range(0, 100) var volume: float = 75.0
@export var muted: bool = false
