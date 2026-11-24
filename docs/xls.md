# Excel's .xls files

The in-game Excel 97 (`Godot/win95/office/excel.tscn`) opens and saves `.xls` files in a plain text format of our own, not Microsoft's binary one, so that writers can write a customer's spreadsheet in any text editor. `XlsSheet` (`Godot/win95/office/xls_sheet.gd`) reads and writes it. A file holds one worksheet, Sheet1.

## The format

One line per cell: the cell's name, its formatting words, a colon, a space and the value.

```
# Taxes, 1995
A width: 24
A1 bold underline: Income
A2: Pension
B2 currency: 14200
A3: Interest
B3 currency: 312.5
C3 percent 1: 0.042
A5 bold: Note
B5: '1040 goes in by April 15
```

- **Cell:** a column letter (A to IV) and a row number (1 to 65536), in any case: `B2`, `iv65536`.
- **Value:** everything after the colon and its one space, kept as written. A value that is a number (`12`, `-1.5`, `.5`, `3E+2`) is a number: it lines up on the right and takes a number format. Anything else is text, a leading `=` too: this Excel has no formulas. A leading apostrophe keeps a number as text (`'007` shows `007`).
- **Formatting words**, in any order, separated by spaces:
  - `bold`, `italic`, `underline`.
  - `left`, `center`, `right`. Without one, numbers line up on the right and text on the left, and text runs on into empty cells to its right.
  - A number format, optionally followed by its decimals: `number` (`1234.50`, 2 decimals), `currency` (`$1,234.50`, 2), `accounting` (Excel's Currency Style button: the `$` at the cell's left edge, negatives in brackets, zero as a dash; 2), `comma` (Comma Style: `1,234.50 `, 2), `percent` (`0.042` shows `4%`, 0). `currency 0` shows `$14,200`; `percent 1` shows `4.2%`.
- **Column width:** `B width: 12`, in characters of Arial 10, as Excel's Column Width dialog counts them. A column without one is 8.43 characters (64 pixels) wide.
- **Comments:** a line that starts with `#` is skipped, and so are blank lines. Excel drops comments when it saves.

A number that doesn't fit its column shows as `#######`, as in Excel.

## Mistakes in a file

Excel opens what it can read. Each line that it can't read (an unknown word, a cell beyond IV65536, no colon) is left out; Excel shows a message box naming the first such line, and the game logs them all with the file's path.

## Saving

File > Save writes the file back in this format: column widths first, then the cells row by row, with the formatting words in a fixed order and the decimals only where they differ from the format's own. Typing `$5` makes a `currency 0` cell; `12%` a `percent` cell holding `0.12`; `1,234` a `comma 0` cell.
