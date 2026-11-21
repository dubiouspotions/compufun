class_name Applet
extends Resource
## One icon in the Control Panel. A .CPL file in C:\WINDOWS\SYSTEM holds it (Win95File.applets).

## The name under the icon, for example "Display".
@export var name: String = ""
## What the Details view says it does, for example "Changes settings for your display."
@export var description: String = ""
## A 32 x 32 texture; a 16 x 16 twin named like it (Win95File.small_icon) goes on the title bar.
@export var icon: Texture2D
## The property sheet that opening the icon shows. Null opens nothing, and Stub marks the icon.
@export var sheet: PackedScene
