# Win95 icons

`Godot/win95/theme/icons_extracted/` holds every icon that ships in a Windows 95 install, extracted from its files and named by what it shows: 484 icons, 704 images. `Godot/win95/theme/icons/` is the set that the scenes use today, with Aseprite sources; leave its files in place, because scenes load them by name or number.

## Finding an icon

Look up `manifest.json` in the folder. Each entry has:

- `name`: the icon's name. Its files are `<name>_32.png` and `<name>_16.png`, plus `<name>_32_1bit.png` where Windows also ships a black-and-white version, and odd sizes such as `lights_99`'s `modem_lights_panel_256x96.png`.
- `source` and `group`: the file on C: and the icon group's resource id, e.g. `WINDOWS/SYSTEM/SHELL32.DLL` and `4`.
- `duplicates`: other files that carry the same icon group (`<path>#<group id>`). The kept copy is the live one, never the `SYSBCKUP` backup.
- `theme_icons` on each image: the files in `theme/icons/` with the same pixels, such as `4.png` and `folder_closed_32.png` for `folder_closed_32.png`.

Names follow `theme/icons/` where the icons match (`my_computer`, `start_run`, `control_panel`, `desktop`). Names of the MS-DOS program icons in MORICONS.DLL and PROGMAN.EXE describe the picture (`dos_toolbox`, `wordperfect_envelope`); where the picture shows a product name, the icon is named after it (`quattro_pro`).

Every image is 16-colour (4-bit) or black and white (1-bit); none of the install's icons has 256 colours.

## Re-extracting

The script reads any copy of a Windows 95 C: drive. The set here comes from the disk of the win95ctl research VM (`~/Dev/win95ctl/vm/disk.qcow2` on the Macs that have it). Reading that disk needs no VM lock: `qemu-img convert -U` copies it while the VM runs, and mtools reads the copy.

```bash
scratch=$(mktemp -d)
qemu-img convert -U -O raw ~/Dev/win95ctl/vm/disk.qcow2 "$scratch/disk.raw"
mcopy -i "$scratch/disk.raw@@8704" -s -n -Q ::/ "$scratch/c/"    # the FAT partition starts at sector 17
python3 tools/extract_win95_icons.py "$scratch/c" Godot/win95/theme/icons_extracted \
    --theme-icons Godot/win95/theme/icons --sheet "$scratch/sheet.png"
```

The script reads the names from the existing `manifest.json`, so a re-run keeps them. An icon that is new on the disk comes out as `<file>_<group id>`, e.g. `shell32_17`; rename it with `--names names.json` (`{"WINDOWS/SYSTEM/SHELL32.DLL#17": "new_name"}`), and delete the PNGs with the old name, which the script lists. `--sheet` draws every icon with its name; `--sheet-names a,b,c` draws only those.

The script reads `.ICO` files and the icon resources of NE (16-bit) and PE (32-bit) executables: `.EXE`, `.DLL`, `.CPL`, `.SCR`, `.MOD` and `.DRV`. VxDs (LE) carry no icons.
