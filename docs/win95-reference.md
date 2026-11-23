# Windows 95 reference

When the game copies how Windows 95 looks, sounds or behaves (a screensaver, an applet, a sound, a dialog), compare against the real thing, not memory.

## The install CD

Windows 95B OSR2 (4.00.1111), English:

- **Archive:** `~/Dev/HumanError/win95-reference/Microsoft Windows 95B (4.00.1111) (OSR2) [English] (CD).7z` on Gideon. SHA-256 `d02167793b1e66077c19e9342a249cc85421c204be6f960b95f2a9886505680f`. Nevyn has the same file on Alecto; other machines ask him for a copy.
- **Extracted:** `~/Dev/HumanError/scratch-win95-cd/` on Alecto and Gideon. The `cab/` folder holds the CABs; `win95_18.cab` has the screensavers (`*.scr`).
- Unpack a CAB with `cabextract` (`brew install cabextract`).

## The running system

The win95ctl research VM (`~/Dev/win95ctl`) runs this Windows 95 headless; its README says how. On Gideon, its snapshot `savers` has every screensaver installed.

## Licence

Everything on the CD is (C) Microsoft and not licensed to us. It is reference. If a file from it ships in the game, credit it in the README like the other Windows 95 files.
