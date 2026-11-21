extends PropertyPage
## Date/Time > Date & Time: the computer's clock, ticking, with the month, year, day and time that
## the player sets. Apply moves the computer's clock (Win95Setup.clock_offset_seconds) to the date
## and time shown.

const _MonthCalendar := preload("res://win95/applets/month_calendar.gd")

var _computer: ComputerState
## How far the shown clock runs ahead of the computer's, in seconds: the change that Apply makes.
var _shift: int = 0
var _shown_day: Dictionary = {}

@onready var _month: OptionButton = %Month
@onready var _year: SpinBox = %Year
@onready var _calendar: _MonthCalendar = %Calendar
@onready var _clock: Control = %Clock
@onready var _time: Control = %Time


func _ready() -> void:
	set_process(false)


func load_from(computer: ComputerState) -> void:
	_computer = computer
	_shift = 0
	_refresh(true)
	set_process(true)
	_month.item_selected.connect(func(index: int) -> void: _set_date(shown().year, index + 1, shown().day))
	_year.value_changed.connect(func(value: float) -> void: _set_date(int(value), shown().month, shown().day))
	_calendar.day_picked.connect(func(day: int) -> void: _set_date(shown().year, shown().month, day))
	_time.time_edited.connect(_set_time)


func pending() -> Dictionary[StringName, Variant]:
	if _computer == null or _shift == 0:
		return {}
	return {&"clock_offset_seconds": _computer.offset_for(shown())}


func apply(computer: ComputerState) -> void:
	super(computer)
	_shift = 0


## The date and time on the page: the computer's clock and the pending change. A Time datetime
## dictionary.
func shown() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(_computer.now()) + _shift)


func _process(_delta: float) -> void:
	_refresh(false)


# A day that the month lacks, as 31 in April, becomes the month's last.
func _set_date(year: int, month: int, day: int) -> void:
	var from := shown()
	var to := from.duplicate()
	to.merge({year = year, month = month, day = mini(day, _MonthCalendar.days_in(year, month))}, true)
	_move(from, to)


func _set_time(hour: int, minute: int, second: int) -> void:
	var from := shown()
	var to := from.duplicate()
	to.merge({hour = hour, minute = minute, second = second}, true)
	_move(from, to)


func _move(from: Dictionary, to: Dictionary) -> void:
	_shift += Time.get_unix_time_from_datetime_dict(to) - Time.get_unix_time_from_datetime_dict(from)
	_refresh(true)
	edited.emit()


# The date controls change only with the date, so the clock's ticking never resets a year that the
# player is typing.
func _refresh(date_too: bool) -> void:
	var t := shown()
	_clock.show_time(t.hour, t.minute, t.second)
	_time.show_time(t.hour, t.minute, t.second)
	var day := {year = t.year, month = t.month, day = t.day}
	if not date_too and day == _shown_day:
		return
	_shown_day = day
	_month.select(t.month - 1)
	_year.set_value_no_signal(t.year)
	_calendar.show_month(t.year, t.month, t.day)
