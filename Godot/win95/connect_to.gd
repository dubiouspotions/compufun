extends "res://win95/window.gd"
## Win95's Dial-Up Networking Connect To dialog, as AutoDial opens it when a program goes online on
## a computer with a dial-up connection (Win95Setup.dial_up_name). The modem is external and stayed
## at the customer's home, so on the bench Connect dials, gets no answer from the modem and comes
## back to the form; only Cancel ends it.

## The dialog closed: [param connected] is whether it got online, which on the bench it never does.
signal finished(connected: bool)

## Seconds that Windows waits for the modem before it gives up.
@export var dial_seconds := 3.0
## The frames of the dialing picture, a packet down the line to the phone, in order.
@export var dialing_frames: Array[Texture2D] = []
## Frames of the dialing picture per second.
@export var frames_per_second := 4.0

const _MESSAGE := preload("res://win95/message_box.tscn")
const _NO_MODEM := "The computer is not receiving a response from the modem. Check that the modem is plugged in, and if necessary, turn the modem off, and then turn it back on."

var _dial := 0  # counts the dials, so a cancelled one doesn't report
var _dialing_for := 0.0


## Goes online for [param program], a window on a Win95Desktop, as Winsock did: on a computer with a
## dial-up connection in [param setup], AutoDial's Connect To dialog, modal to the program, until the
## player cancels it; else [param seconds] of trying. Returns once it gave up, which on the bench it
## always does: no computer there has its modem.
static func autodial(program: Control, setup: Win95Setup, seconds: float) -> void:
	var desktop := program.get_parent() as Win95Desktop
	if desktop == null or setup == null or setup.dial_up_name == "":
		if seconds > 0.0:
			await program.get_tree().create_timer(seconds).timeout
		return
	var dialog: Node = desktop.open(load("res://win95/connect_to.tscn"), false)  # preloading its own scene would be a cycle
	dialog.show_connection(setup)
	dialog.belong_to(program)
	await dialog.finished
	dialog.queue_free()


func _ready() -> void:
	super()
	set_process(false)
	%Connect.pressed.connect(_connect)
	%Cancel.pressed.connect(close)
	%CancelDialing.pressed.connect(_show_form)
	for field: LineEdit in [%User, %Password, %Number]:
		field.text_submitted.connect(func(_text: String) -> void: _connect())
	for control in find_children("*", "Control", true, false):
		if (control as Control).focus_mode != Control.FOCUS_NONE:
			(control as Control).gui_input.connect(_on_key.bind(control))
	closed.connect(func() -> void: finished.emit(false), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_dialing_for += delta
	if not dialing_frames.is_empty():
		%Picture.texture = dialing_frames[int(_dialing_for * frames_per_second) % dialing_frames.size()]


## Shows [param setup]'s dial-up connection.
func show_connection(setup: Win95Setup) -> void:
	%Name.text = setup.dial_up_name
	%User.text = setup.dial_up_user
	%Number.text = setup.dial_up_number
	_show_form()


func _focus_default() -> void:
	(%CancelDialing if %Dialing.visible else %Connect).grab_focus()


func _connect() -> void:
	%Form.hide()
	%Dialing.show()
	%TitleBar.title = "Connecting to %s" % %Name.text
	%State.text = "Status: Dialing..."
	reset_size()
	_dialing_for = 0.0
	set_process(true)
	_focus_default()
	_dial += 1
	var dial := _dial
	await get_tree().create_timer(dial_seconds).timeout
	if dial != _dial or not visible:
		return
	_show_form()
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("Connect To: not on a Win95Desktop, so it can't say that the modem doesn't answer")
		return
	var box: Node = desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.show_message("Dial-Up Networking", _NO_MODEM)
	box.belong_to(self)


func _show_form() -> void:
	_dial += 1
	set_process(false)
	%Dialing.hide()
	%Form.show()
	%TitleBar.title = "Connect To"
	reset_size()
	_focus_default.call_deferred()


# Esc cancels: hanging up while it dials, else closing the dialog.
func _on_key(event: InputEvent, control: Control) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		control.accept_event()
		if %Dialing.visible:
			_show_form()
		else:
			close()
