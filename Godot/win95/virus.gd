class_name Virus
extends BackgroundTask
## A background task that is a virus, such as BIZOPP.EXE. A program file whose scene root is one is
## infected: CompuFun AntiVirus finds it by what it is ([method infects]), whatever problem put it
## there, and cleans it off (ComputerState.remove_viruses).

## The name that a virus scanner reports, such as "Bizopp.A".
@export var virus_name: String = ""


## True when [param file] is a program file whose scene root is a Virus. Reads the scene without
## making it.
static func infects(program: Win95File) -> bool:
	return program.program != null and Win95File.root_extends(program.program, Virus)


## The [member virus_name] of [param file]'s program (see [method infects]); "" when it is no virus.
static func name_of(program: Win95File) -> String:
	return str(Win95File.root_property(program.program, &"virus_name")) if infects(program) else ""
