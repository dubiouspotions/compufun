# Windows 95 reference

When the game copies how Windows 95 looks, sounds or behaves (a screensaver, an applet, a sound, a dialog), compare against the real thing, not memory.

## The install CD

Windows 95B OSR2 (4.00.1111), English:

- **Archive:** `~/Dev/HumanError/win95-reference/Microsoft Windows 95B (4.00.1111) (OSR2) [English] (CD).7z` on Gideon. SHA-256 `d02167793b1e66077c19e9342a249cc85421c204be6f960b95f2a9886505680f`. Nevyn has the same file on Alecto; other machines ask him for a copy.
- **Extracted:** `~/Dev/HumanError/scratch-win95-cd/` on Alecto and Gideon. The `cab/` folder holds the CABs; `win95_18.cab` has the screensavers (`*.scr`).
- Unpack a CAB with `cabextract` (`brew install cabextract`).

## The running system

The win95ctl research VM (`~/Dev/win95ctl`) runs this Windows 95 headless; its README says how. On Gideon, its snapshot `savers` has every screensaver installed.

## Office 97

Microsoft Office 97 Standard, US English, no service release, from archive.org (https://archive.org/details/office97standard_201912, `Office 97 Standard.ISO`, MD5 `c17161c8e458609c3bda04901d13f0aa`; the item's text file has the CD key). The ISO is at `~/Dev/HumanError/scratch/w2/278/download/office97std.iso` on Gideon.

The win95ctl VM's snapshot `office97` has it installed: Word, Excel and the Office Assistant with all its actors, on a desktop right after the install and a reboot. Word and Excel were never started in it, so the first-run Clippy entrance and the User Name dialog play each time the snapshot loads. The VM's disk is 68 MB, so this is a minimal Custom install: no Help, no Proofing Tools (spelling), no Office fonts, no Find Fast. The guest runs the generic VGA driver, so every shot is 640 x 480 in 16 colours.

Reference shots and notes from it are in `~/Dev/HumanError/scratch/w2/278/` on Gideon. What the reference shows:

- **Install:** Start gets "New Office Document" and "Open Office Document" above Programs. Start > Programs gets "Microsoft Excel" and "Microsoft Word" straight in Programs, with no Office folder, and StartUp gets "Office Startup". The programs are `C:\Program Files\Microsoft Office\Office\WINWORD.EXE` and `EXCEL.EXE`.
- **Word:** opens maximized, as "Microsoft Word - Document1", in Normal view, with Times New Roman 10 pt. Menus: File Edit View Insert Format Tools Table Window Help. The File menu: New... Ctrl+N, Open... Ctrl+O, Close, Save Ctrl+S, Save As..., Versions..., Page Setup..., Print Preview, Print... Ctrl+P, Send To, Properties, Exit. Status bar: Page 1, Sec 1, 1/1, At 1", Ln 1, Col 1, then REC TRK EXT OVR WPH greyed.
- **Excel:** "Microsoft Excel - Book1"; menus File Edit View Insert Format Tools Data Window Help; Arial 10.
- **Toolbars:** the Standard and Formatting toolbars, in the order that `win95/office/word.gd` builds them. Buttons are flat until the mouse is over them; a button that stays pushed in (Bold, Align Left) is sunken with a dithered face.
- **Office Assistant:** a 100 x 91 window in the bottom right corner of the app, above the horizontal scroll bar, with a navy title bar that holds only a close button.

Not confirmed, because the install is minimal or the display has 16 colours: the red spelling squiggles and Tools > "Spelling and Grammar..." (this install has only "Spelling... F7"), the Help balloon with Help installed, and the colours in 256 colours.

## Licence

Everything on the CD is (C) Microsoft and not licensed to us. It is reference. If a file from it ships in the game, credit it in the README like the other Windows 95 files.
