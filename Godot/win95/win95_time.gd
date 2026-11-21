class_name Win95Time
## Dates and times as Win95 writes them, from Time's datetime dictionaries (year, month, day,
## weekday, hour, minute, second; the parts that a format uses).

const _WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const _MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


## "9:05 PM", as the taskbar clock shows it; with [param seconds], "9:05:12 PM".
static func clock(t: Dictionary, seconds := false) -> String:
	var hour: int = t.hour
	var text := "%d:%02d" % [(hour + 11) % 12 + 1, t.minute]
	if seconds:
		text += ":%02d" % t.second
	return text + (" PM" if hour >= 12 else " AM")


## "5/28/96", as lists show a date.
static func short_date(t: Dictionary) -> String:
	return "%d/%d/%02d" % [t.month, t.day, t.year % 100]


## "Tuesday, May 28, 1996", as Properties and Exchange show a date.
static func long_date(t: Dictionary) -> String:
	return "%s, %s %d, %d" % [_WEEKDAYS[t.weekday], _MONTHS[t.month - 1], t.day, t.year]


## [param text], "1996-05-28 21:14" with optional seconds, as a datetime dictionary with its weekday.
## An empty dictionary, with an error, when it isn't such a date.
static func parse(text: String) -> Dictionary:
	var iso := text.replace(" ", "T")
	if iso.count(":") == 1:
		iso += ":00"  # Time wants the seconds
	var t := Time.get_datetime_dict_from_datetime_string(iso, true)
	if t.is_empty() or t.year == 0:
		push_error("Win95Time: '%s' is not a date such as 1996-05-28 21:14" % text)
		return {}
	return t
