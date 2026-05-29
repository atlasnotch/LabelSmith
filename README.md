# LabelSmith for macOS

LabelSmith is a native macOS app for quickly reviewing and editing image captions in
Ostris AI Toolkit-style datasets.

Drop in a folder of training images, move through the set with the keyboard, edit the
caption, and let LabelSmith save the matching `.txt` sidecar file for you.

![LabelSmith screenshot](docs/images/labelsmith-screenshot.png)

## Features

- Native SwiftUI macOS interface.
- Drag-and-drop folder loading, with an Open Folder command as a fallback.
- Strict Ostris-style dataset support:
  - top-level `.jpg`, `.jpeg`, and `.png` files
  - same-basename `.txt` caption files
- Large image preview with a fast caption editor.
- Thumbnail/sidebar navigation.
- Search across filenames and captions.
- Missing-caption filter and dataset summary.
- Autosaves caption edits to sidecar `.txt` files.
- Unit-tested scanner and caption persistence logic.

## Dataset Format

LabelSmith currently expects a flat folder:

```text
dataset/
  image001.jpg
  image001.txt
  image002.png
  image002.txt
  image003.jpeg
```

Each `.txt` file contains the caption for the image with the same base name. If a
caption file does not exist yet, LabelSmith creates it when you edit and save that
image's caption.

For now, LabelSmith intentionally ignores subfolders and non-Ostris image extensions
such as `.webp`, `.gif`, and `.tiff`.

## Requirements

- macOS 14 or newer.
- Xcode 26 or newer for local development.
- Swift 6 toolchain.

## Build and Run

Open the project in Xcode:

```sh
open LabelSmith.xcodeproj
```

Then select the `LabelSmith` scheme and run the app.

You can also build and test from the command line:

```sh
xcodebuild test \
  -project LabelSmith.xcodeproj \
  -scheme LabelSmith \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData
```

The debug app bundle is produced under:

```text
DerivedData/Build/Products/Debug/LabelSmith.app
```

## Usage

1. Launch LabelSmith.
2. Drag a dataset folder into the window, or use File > Open Folder.
3. Select an image in the sidebar.
4. Edit the caption in the caption field.
5. Move to the next image; edits autosave after a short delay.

Useful shortcuts:

- `Command-O`: open a folder.
- `Command-S`: save the current caption immediately.
- `Up` / `Down`: move to the previous or next visible image.
