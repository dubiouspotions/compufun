class_name DesktopPrankCheck
extends SoftwareCheck
## The screenshot prank: a picture of the desktop becomes the wallpaper, and every icon goes into
## one folder in a corner, so the icons on the screen are only a picture. Fixed when the wallpaper
## is another and those icons are on the desktop again. The system icons stay, over their pictures.

const _FOLDER_ICON := preload("res://win95/theme/icons/folder_closed_32.png")
const _BITMAP_ICON := preload("res://win95/theme/icons/bitmap_32.png")
const _WINDOWS := "C:\\WINDOWS"

@export var folder_name := "New Folder"
## Where the folder stands, in pixels from the top left of the desktop. The default hides it in
## the bottom right corner: a corner of the folder peeks out, its name behind the taskbar.
@export var folder_position := Vector2(601, 429)
## The file in C:\WINDOWS that the screenshot is saved as; Display Properties lists it.
@export var screenshot_name := "prank.bmp"
## How much colour the screenshot loses: the steps per channel (256 keeps them all) and the
## dither, as in psx_post.gdshader.
@export_range(2.0, 256.0) var color_levels := 24.0
@export_range(0.0, 2.0) var dither := 0.5


func apply_break(setup: Win95Setup) -> void:
	if setup.desktop_screenshot != null and setup.wallpaper == setup.desktop_screenshot:
		return
	var shot := DesktopScreenshot.new()
	shot.wallpaper = setup.wallpaper
	shot.icons.assign(setup.desktop)
	shot.color_levels = color_levels
	shot.dither = dither
	_save(setup, shot)
	var folder := Win95File.new()
	folder.name = folder_name
	folder.icon = _FOLDER_ICON
	folder.is_folder = true
	folder.desktop_position = folder_position
	folder.children.assign(setup.desktop)
	setup.desktop.clear()  # in place: the Recycle Bin remembers this Array
	setup.desktop.append(folder)
	setup.wallpaper = shot
	setup.desktop_screenshot = shot


func _save(setup: Win95Setup, shot: DesktopScreenshot) -> void:
	var windows := setup.file_at(_WINDOWS)
	if windows == null:
		push_error("DesktopPrankCheck: the computer has no %s to save %s in" % [_WINDOWS, screenshot_name])
		return
	for file: Win95File in windows.children:
		if file.name.nocasecmp_to(screenshot_name) == 0:
			file.picture = shot
			return
	var file := Win95File.new()
	file.name = screenshot_name
	file.icon = _BITMAP_ICON
	file.picture = shot
	windows.children.append(file)


func is_fixed(setup: Win95Setup) -> bool:
	var shot := setup.desktop_screenshot
	return shot == null or (setup.wallpaper != shot and shot.icons.all(func(file: Win95File) -> bool: return setup.desktop.has(file)))
