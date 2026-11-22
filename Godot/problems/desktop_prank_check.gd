class_name DesktopPrankCheck
extends SoftwareCheck
## The screenshot prank: a picture of the desktop becomes the wallpaper, and every icon goes into
## one folder in a corner, so the icons on the screen are only a picture. Fixed when the wallpaper
## is another and those icons are on the desktop again. The system icons stay, over their pictures.

const _FOLDER_ICON := preload("res://win95/theme/icons/folder_closed_32.png")

@export var folder_name := "New Folder"
## Where the folder stands, in pixels from the top left of the desktop. The default is the bottom
## right corner, above the taskbar.
@export var folder_position := Vector2(566, 378)


func apply_break(setup: Win95Setup) -> void:
	if setup.desktop_screenshot != null and setup.wallpaper == setup.desktop_screenshot:
		return
	var shot := DesktopScreenshot.new()
	shot.wallpaper = setup.wallpaper
	shot.icons.assign(setup.desktop)
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


func is_fixed(setup: Win95Setup) -> bool:
	var shot := setup.desktop_screenshot
	return shot == null or (setup.wallpaper != shot and shot.icons.all(func(file: Win95File) -> bool: return setup.desktop.has(file)))
