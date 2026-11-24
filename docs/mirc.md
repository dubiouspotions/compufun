# mIRC

The activist's IRC client (`Godot/win95/mirc.tscn`) is mIRC 4.1, the version that was current on day 1 (May 31, 1996). mIRC 4.0 came out on March 20, 1996, 4.1 on April 27, and 4.5 on June 30.

## Sources

- The version history: https://www.mirc.co.uk/versions.txt
- The mIRC 4.0 package as it shipped, on a 1996 CD: https://discmaster.textfiles.com/browse/6748/cd.iso/PLANETE/MIRC40 . It holds README.TXT, the stock MIRC.INI, the help file (its text view, "HLP40" below) and the resources of MIRC32.EXE: the toolbar bitmap, the window icons and the About picture.
- The mIRC FAQ, v30 of January 9, 1997, which covers 4.72: https://discmaster.textfiles.com/view/17006/SuperHack%20CD.bin/SCRIPTZ/GS3.ZIP/GunSlinger3/MIRCFAQ.HLP?text=
- Fixedsys as mIRC's default font: https://forums.mirc.com/ubbthreads.php/topics/261129

Nobody found a screenshot of a 4.x version from 1996. The web.archive.org copies of mirc.com refused automated reading.

## Real

- **Menus** (HLP40): File, Tools, DCC, Windows and Help. File holds Connect, Setup, Options and Exit; the game greys out the rest, as offline mIRC needs none of it.
- **Setup** (HLP40): the tabs IRC Servers, Local Info, Options, Identd and Firewall; the server list with Add, Edit, Delete and Sort; Real Name, Email Address, Nickname and Alternate; Identd on port 113, a SOCKS firewall on port 1080.
- **No switchbar.** mIRC 4.7 (December 1996) added it.
- **MIRC.INI**: the `[Servers]` lines and their format, from the stock 4.0 file.
- **Logs** (HLP40, versions.txt): mIRC logs a window to a file named after the window, ending in `.log` from 4.1. Before 5.0 the logs sat in mIRC's own folder; 5.0 added a Logs folder. 4.1 added the list of log files with View and Delete to Options > Logging, which is how a user read them back. The files have no Session Start header: that came with 5.x.
- **No dialer.** mIRC 4.x connects through Winsock, which dials through Dial-Up Networking's AutoDial. A failed name lookup shows "Unable to resolve IRC server name" (HLP40).
- **About**: "Copyright (c) Khaled Mardam-Bey 1995,1996. All rights reserved." 4.0 and 4.1 were free for home users (README.TXT): no registration nag. The shareware nag came between 4.5 and 4.72.
- **Install**: 4.1 was a zip file without a setup program, which the user unpacked into a folder of his choice. The installer came with 4.5.

## Invented or unconfirmed

- **The toolbar**: our icons are drawn by `tools/make_mirc_art.py` after the toolbar bitmap of the 4.0 MIRC32.EXE, in its order. Which buttons 4.1 showed is unconfirmed; the game builds Connect, Setup and Options and greys out the rest.
- **The program icon**: our own drawing, in the style of the 4.0 icon (a window over the word mIRC).
- **The folder C:\MIRC** and the shortcuts named mIRC32: the activist made them himself.
- **Wording**: the title "mIRC32", "*** Connecting to irc.dal.net (6667)", and "*** Not connected to server" for text typed offline. Only "Unable to resolve IRC server name" comes from a source.
- **Setup's layout** and its "Connect!" button, which a 1997 document names. Setup doesn't save changes.
- **Options**: the game builds the pages IRC Switches, Logging and Extras. The real dialog also had Notify List, Control, Double-click, Event Beeps, Sound Requests, URL Catcher, Perform and Servers.
- **The Logging page's layout.** Its View button opens the log in Notepad, as Windows opens a .log file; what 4.1's View opened is unconfirmed. Delete is greyed out.
- **The font**: Px437 IBM VGA 8x16 stands in for Fixedsys in the Status window.
- **The logs' timestamps** look like `[23:01]`: `$timestamp` returned that format in 4.6, and 4.1's format is unconfirmed.
- **The `[mirc]` keys** of MIRC.INI (`user`, `email`, `nick`, `anick`, `host`) are from later versions.
- **The About box** shows our icon. The real one showed a photo of the author, which the game doesn't use.

## The logs

The logs' text lives in `Godot/customers/activist_guy/mirc_logs/*.log`, so that writers edit plain text. Each log on his drive C is a Win95File whose `contents_file` names its text file, and `Win95Setup.copy()` reads it into the running copy. The export presets include `customers/*.log`; a text file elsewhere needs its own pattern there.
