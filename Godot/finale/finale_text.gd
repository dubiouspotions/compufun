class_name FinaleText
extends Resource
## The text that the finale shows: the Win95 error boxes that pile up, the errors of the player's
## own computer as it fails to restart, and the credits.

## The title of every error box.
@export var popup_title: String = "Cambion"
## The messages of the error boxes; each box picks one at random.
@export var popup_messages: PackedStringArray = []
## Windows: the text under the spinning dots before the error.
@export var windows_repair: String = ""
## Windows: the heading of the error screen.
@export var windows_title: String = ""
## Windows: the error.
@export_multiline var windows_error: String = ""
## macOS: the error under the prohibitory sign.
@export_multiline var macos_error: String = ""
## Linux: the boot log that scrolls up before it hangs, one line per line.
@export_multiline var linux_boot: String = ""
## Linux: the error after the boot log.
@export_multiline var linux_error: String = ""
## The heading of the credits.
@export var thanks: String = ""
## The line above the row of portraits.
@export var cast_heading: String = ""
## The credits under the portraits.
@export_multiline var credits: String = ""
## The line at the bottom of the credits.
@export var restart_hint: String = ""
