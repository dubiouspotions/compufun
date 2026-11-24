# PowerPoint's .ppt files

The in-game PowerPoint 97 (`Godot/win95/office/powerpoint.tscn`) opens and saves `.ppt` files in a plain text format of our own, not Microsoft's binary one, so that writers can write a customer's presentation in any text editor. `PptDeck` (`Godot/win95/office/ppt_deck.gd`) reads and writes it.

## The format

```
# The young entrepreneur's pitch
design: Highvolt

slide: Title Slide
title: IMPORT & EXPORT
text: Mostly import

slide: Bulleted List
title: The idea
text: Buy things where they are cheap
text:   Repeat

slide: 2 Column Text
title: Why now?
text: Time is money
right: Cutting edge software
```

- **`design:`** the design template by the name that Office 97 gives it, its file name: `Dadstie`, `Fireball` or `Highvolt`. Without it, the presentation has the Default Design: white, with black Times New Roman.
- **`slide:`** starts a slide with an AutoLayout: `Title Slide`, `Bulleted List`, `2 Column Text`, `Title Only` or `Blank`.
- **`title:`** the title placeholder. A second `title:` line is a second line of the title.
- **`text:`** a paragraph of the body: the sub-title on a Title Slide, a bullet on a Bulleted List, the left column on 2 Column Text. Two spaces after `text: ` make a second-level bullet, four a third, and so on.
- **`right:`** a paragraph of 2 Column Text's right column.
- A line that starts with `#` is skipped, and so are blank lines. PowerPoint drops comments when it saves.

A file with no slides opens as one Title Slide.

## Mistakes in a file

PowerPoint opens what it can read. Each line that it can't read (an unknown key, a `title:` before the first `slide:`) is left out, and an unknown layout becomes a Bulleted List. PowerPoint shows a message box naming the first such line, and the game logs them all with the file's path.

## Designs

Each design is a `PptDesign` in `Godot/win95/office/designs/`: its background picture, its colours and fonts, where its title lines up and how far its placeholders start from the left. `tools/make_ppt_designs.py` draws the backgrounds after Office 97's own designs, as Apply Design previews them. A new design is a new `.tres` there, listed in `designs` on `powerpoint.tscn`.

## Against the reference

PowerPoint 97 is on the Office 97 Standard CD (docs/win95-reference.md, "Office 97"), but the `office97` VM's minimal install left it out. Run from the CD (`D:\Office\Powerpnt.exe`) in that VM, it shows what the game copies: the start dialog, New Slide with its 24 AutoLayouts (the game builds 5), Slide Layout ("Reapply the current master styles:" and Reapply for the slide's own layout, "Change the layout of the slide to:" and Apply for another), the toolbars, Common Tasks, the view buttons, Slide Sorter, Apply Design's file list of the CD's 17 designs, and a Slide Show that ends after the last slide without a black end slide. The window's title is "Microsoft PowerPoint - [Presentation1]".

Not built: AutoContent wizard, templates from the start dialog, Outline and Notes Page views, the Drawing toolbar's buttons (it shows as a picture), Slide Sorter's own toolbar, transitions and animations, and the 19 other AutoLayouts.
