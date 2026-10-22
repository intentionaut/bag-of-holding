![Bag of Holding: +1 to morale on a rainy day](docs/banner.png)

# Bag of Holding

Reach into it for praise and reminders of your work on a rainy day.

## Credits

The name comes from the bag of holding in the System Reference Document 5.1.

This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.

## What it does

A small macOS menu bar app. Drop in screenshots (PNG, JPG), text, markdown,
transcripts (.txt, .vtt, .srt) and PDFs. Each one is copied into a folder you
choose (say, Bag of Holding on your Desktop), filed as
`2026/10 October/2026-10-22 name.png`. Click the bag icon and one item comes out at random.

- **Another** shows a different one. Never the same item twice in a row.
- **I'm having a bad day** shows three at once.
- **Daily reminder** sends one notification at a time you set. Off by default.
- **Edit** any card to set the praise in clean words, who it was from, and what
  it was about. The text read from a screenshot is kept alongside your version.
- **Search** finds words in screenshots (read on your Mac by Apple's Vision
  framework), in text and PDFs, and in the tags you give each item.

## Three promises

Each one has a check. Run `scripts/verify.sh` after building to see all three.

1. **No network.** ✓ The app is sandboxed with no network entitlement, so
   macOS itself blocks any connection. The script reads the signed
   entitlements and also checks that the source has no networking code.
2. **No analytics, no accounts.** ✓ The script checks the source has no
   analytics, tracking, login or cloud code. This check reads the code; the
   network block in promise 1 is what stops anything leaving.
3. **Your originals are never changed, and it reads only what you hand it.** ✓
   macOS only lets the app reach the folder you choose for the bag and the
   files you drop or pick. The script confirms those are the only
   entitlements, and that only `Bag.swift` writes or deletes files, inside
   the bag folder.

## Build from source

Needs macOS 14 or later and Xcode (for the Swift toolchain). No dependencies.

```
./build.sh
open "build/Bag of Holding.app"
swift test
scripts/verify.sh
```

`build.sh` signs the app ad hoc. The first time you open it, it asks
where the bag should live. **Show bag** opens that folder in Finder;
right-click it to change folder. `samples/` holds made-up files to try it with.

## Support

If the bag helps, you can buy me a coffee on [Ko-fi](https://ko-fi.com/intentionaut). **Tip ☕** in the app opens the same page in your browser; the app itself still has no network access.

## Licence

MIT © 2026 Saielle DaSilva. See `LICENSE`.
