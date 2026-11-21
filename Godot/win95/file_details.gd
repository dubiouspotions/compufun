class_name FileDetails
## The columns of Explorer's Details view, and their texts for one file, by the kind of listing
## (win95.gd's Listing.kind): My Computer, the Control Panel and the Recycle Bin have their own columns.

const _PROPERTIES := preload("res://win95/properties_window.gd")
const _DRIVE_TYPES := {"(A:)": "3½ Inch Floppy Disk", "(C:)": "Local Disk", "(D:)": "CD-ROM Disc"}


## The columns for a listing of [param kind], Name first, with Win95's widths.
static func columns(kind: StringName) -> Array[ReportList.Column]:
	match kind:
		&"my_computer":
			return [ReportList.Column.new("Name", 120), ReportList.Column.new("Type", 150), ReportList.Column.new("Total Size", 90, null, true),
				ReportList.Column.new("Free Space", 90, null, true)]
		&"control_panel":
			return [ReportList.Column.new("Name", 120), ReportList.Column.new("Description", 380)]
		&"recycle_bin":
			return [ReportList.Column.new("Name", 120), ReportList.Column.new("Original Location", 120), ReportList.Column.new("Date Deleted", 108),
				ReportList.Column.new("Type", 120), ReportList.Column.new("Size", 48, null, true)]
	return [ReportList.Column.new("Name", 120), ReportList.Column.new("Size", 60, null, true), ReportList.Column.new("Type", 120), ReportList.Column.new("Modified", 120)]


## The texts of [param file] in the columns after Name. The sizes of drives and the date deleted
## are blank: the setup doesn't hold them.
static func cells(kind: StringName, file: Win95File, state: ComputerState) -> PackedStringArray:
	match kind:
		&"my_computer":
			return [_drive_type(file), "", ""]
		&"recycle_bin":
			return [state.original_location(file), "", _PROPERTIES.type_name(file), _size(file)]
	return [_size(file), _PROPERTIES.type_name(file), _modified(file)]


static func _drive_type(file: Win95File) -> String:
	for drive: String in _DRIVE_TYPES:
		if file.name.ends_with(drive):
			return _DRIVE_TYPES[drive]
	return "System Folder"


# Win95 rounds up to whole KB: 1 byte is "1KB".
static func _size(file: Win95File) -> String:
	return "%dKB" % ceili(file.size_in_bytes() / 1024.0) if _PROPERTIES.has_size(file) else ""


static func _modified(file: Win95File) -> String:
	if file.modified == "":
		return ""
	var t := Win95Time.parse_long(file.modified)
	if t.is_empty():
		push_error("FileDetails: %s has Modified '%s', not a date such as 'Thursday, May 30, 1996 11:12:44 PM'" % [file.name, file.modified])
		return ""
	return "%s %s" % [Win95Time.short_date(t), Win95Time.clock(t)]
