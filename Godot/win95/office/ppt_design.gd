class_name PptDesign
extends Resource
## A PowerPoint design template, as Format > Apply Design lists it: the slides' background and the
## colours and fonts of their title and text. One .tres per design in win95/office/designs/.

## The name that Apply Design and the status bar show, such as "High Voltage"; a .ppt file names its
## design by it.
@export var name: String = ""
## Drawn over the whole slide, stretched; null shows [member background_color] alone.
@export var background: Texture2D
@export var background_color: Color = Color.WHITE
@export var title_color: Color = Color.BLACK
@export var text_color: Color = Color.BLACK
## The bullets' colour.
@export var bullet_color: Color = Color.BLACK
## How the title lines up in its placeholder: centred in the Default Design, left in Dadstie,
## right in Fireball.
@export var title_align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## How far right the placeholders start, in fractions of the slide's width, past a strip that the
## background draws down its left edge.
@export_range(0.0, 0.3) var left_inset: float = 0.0
@export var title_font: Font = preload("res://win95/theme/fonts/liberation_serif_regular.ttf")
@export var text_font: Font = preload("res://win95/theme/fonts/liberation_serif_regular.ttf")
