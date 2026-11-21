# Code standard

How GDScript is written in this repo. Where this file is silent, follow the official
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

## Typing

- Typed GDScript everywhere: every variable, parameter and return type. The project warns on
  `untyped_declaration`; treat that warning as an error.
- Use `:=` only where the type is obvious from the right-hand side. A value read from a
  `Dictionary` or an untyped `Array` needs an explicit type (`var x: T = dict.key`); `:=`
  doesn't compile there.
- Give a script a `class_name` when other scripts refer to its type; otherwise leave it out.

## Naming and layout

- Files and folders: `snake_case` (`player_controller.gd`, `main_menu.tscn`). Keep a script
  next to the scene that uses it, with the same base name.
- Classes and nodes: `PascalCase`. Functions, variables and signals: `snake_case`. Constants
  and enum values: `CONSTANT_CASE`.
- Signals are named in the past tense for what happened (`door_opened`), not as a command.
- Private members start with `_`. Other scripts don't touch them.
- Indent with tabs. `[editor_overrides]` in `project.godot` sets this for Godot's script editor,
  and `.editorconfig` for external editors.

## Scenes and nodes

- Get child nodes with `%UniqueName` or `@onready var x: T = $Path`, never with a path string
  repeated across functions.
- Call down, signal up: a node calls methods on its children and emits signals to its parent.
  Reaching up the tree with `get_parent()` chains couples scenes together.
- Tunables are `@export`s or Resource fields, so that teammates who don't code can change them
  in the inspector. A new kind of content is a scene or a `.tres`, not a new branch in code.
- Autoloads hold state that really is global (settings, save data, audio). Everything else
  belongs to a scene.

## Errors

GDScript has no exceptions, so failures arrive as values, and they're easy to drop:

- Check every `Error` return value. Report a failure with `push_error()` and the failing input:
  `push_error("Couldn't load %s: %s" % [path, error_string(err)])`.
- `load()` and `ResourceLoader.load()` return `null` on failure. `FileAccess.open()` returns
  `null`; the reason is in `FileAccess.get_open_error()`.
- `assert()` runs only in debug builds and the editor; exported release builds skip it.
  Use it for programmer errors only, never for a check the release build depends on.

## Comments

- `##` doc comments on members that other scripts use: units, ranges, when a signal fires,
  what `null` means.
- Inline comments explain the unexpected in one line, or there is no comment.
