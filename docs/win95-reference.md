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
- **Excel:** "Microsoft Excel - Book1"; menus File Edit View Insert Format Tools Data Window Help; Arial 10. The File menu: New... Ctrl+N, Open... Ctrl+O, Close, Save Ctrl+S, Save As..., Save Workspace..., Page Setup..., Print Area, Print Preview, Print... Ctrl+P, Properties, Exit (no Versions or Send To). With nothing on the clipboard, Edit greys out Paste, Paste Special..., Paste as Hyperlink, Links... and Object. Below the toolbars: the Name Box (125 px, the cell name centred), then the formula bar with "="; while the player types into a cell, a red X and a green tick appear left of the "=", the status bar says Enter (Edit after F2), and the thick frame stays around the cell. Columns are 64 px (8.43 characters) and rows 17 px; text sits at the bottom of its cell. A selection is black with white text, the active cell white. With more than one cell selected, the status bar's second box shows "Sum=6.45". The sheet tabs Sheet1 to Sheet3 share the bottom row with the horizontal scroll bar. Typing "$5" gives "$5" (Currency, 0 decimals), "12%" gives 12%, "1,234" gives 1,234; the Currency Style button puts the "$" at the cell's left edge and shows a negative number as "(5.00)"; typing "=" starts a formula and the Name Box lists functions. Closing a changed book asks "Do you want to save the changes you made to 'Book1'?". The first start after the install also shows a Registration Wizard that asks for a modem.
- **Toolbars:** the Standard and Formatting toolbars, in the order that `win95/office/word.gd` builds them. Buttons are flat until the mouse is over them; a button that stays pushed in (Bold, Align Left) is sunken with a dithered face.
- **File > Properties:** "Document1 Properties", or the file's name without its extension ("Dear Sir Properties"), with the tabs General, Summary, Statistics, Contents and Custom; a new document opens on Summary. Summary: Title, Subject, Author (the User Name), Manager, Company, a rule, Category, Keywords, Comments, Hyperlink base, "Template: Normal" and "Save preview picture"; OK and Cancel. General shows Type, Location, Size, MS-DOS name, Created, Modified, Accessed and the greyed Attributes. The game builds General and Summary; Summary keeps its fields in `Win95File.summary`, where Office kept them inside the file.
- **Recent files:** File lists the last files above Exit, as "1 Dear Sir": the name without its extension, 4 by default. Saving a new file adds it there but not to Start > Documents. In the game both lists come from the computer's recent documents, which opening a file fills.
- **Shortcut Bar:** `MSOFFICE.EXE`, an optional part of this Custom install, run from the CD: a navy button with the Office logo, a thin magenta rule, then a button per shortcut ("My Documents" on a fresh bar), docked at the top right of the screen, left of a maximized window's caption buttons. The game's buttons open Word and Excel. It runs on the office girl's and the top hat man's computers, from their StartUp folders.
- **File types:** the setup registered .doc to Word, so Word opens it once Office is installed even though WordPad opens .doc too. The game gives Office apps `claims_file_types`, which `ComputerState.programs_for` puts first.
- **Dates:** the CD's files are from November 1996, after the game's week, so the game's Office files carry no date.
- **Office Assistant:** a 100 x 91 window in the bottom right corner of the app, above the horizontal scroll bar, with a navy title bar that holds only a close button.

The game's Excel differs on purpose: a leading "=" is text (there are no formulas), Comma Style and a typed "1,234" look the same, and the X and the tick only show. Not confirmed: the Comma Style button's look (assumed to be Currency Style without the "$"), and the X and tick colours outside 16 colours (`excel.gd` uses the reference's 16-colour pixels).

Not confirmed, because the install is minimal or the display has 16 colours: the red spelling squiggles and Tools > "Spelling and Grammar..." (this install has only "Spelling... F7"), the Help balloon with Help installed, and the colours in 256 colours.

## Licence

Everything on the CD is (C) Microsoft and not licensed to us. It is reference. If a file from it ships in the game, credit it in the README like the other Windows 95 files.
