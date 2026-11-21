class_name Win95File
extends Resource
## A file or folder on a customer's computer, on the desktop or on drive C.

## The name with its extension, for example "PBRUSH.EXE".
@export var name: String = ""
## A 32 x 32 texture.
@export var icon: Texture2D
@export var is_folder: bool = false
## The files in this folder. Empty for a file.
@export var children: Array[Win95File] = []
