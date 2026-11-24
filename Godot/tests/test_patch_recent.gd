extends "res://tests/test.gd"
## A setup patch that sets recently_opened changes Start > Documents (recent_documents), also for a
## file that the same patch puts on the computer.


func run() -> void:
	var text := "set recently_opened: PackedStringArray(\"C:\\\\NOTES\\\\TODO.TXT\")\n\nfolder C:\\NOTES\n\nfile C:\\NOTES\\TODO.TXT\n\tcontents: \"buy milk\"\n"
	var parsed := SetupPatch.parse(text, "res://story/computers/test.setup")
	check("the patch parses", parsed.errors, PackedStringArray())
	var running := Win95Setup.new().copy()
	check("a stock computer starts with no recent documents", running.recent_documents.size(), 0)
	(parsed.value as SetupPatch).apply(running)
	check("the patch's file is in Start > Documents", running.recent_documents.map(func(f: Win95File) -> String: return f.name), ["TODO.TXT"])
	check("and it is the file on drive C", running.recent_documents[0] == running.file_at("C:\\NOTES\\TODO.TXT"), true)
