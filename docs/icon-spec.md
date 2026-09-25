# App icon: specs

The icon for Beta 3 is designed by the user. This page is everything it needs to meet so
it builds, signs and looks right on iOS 26, with no Mac.

## What to deliver

| File | Required? | What it is |
|---|---|---|
| `icon-1024.png` | **Yes** | The icon itself. |
| `icon-1024-dark.png` | Optional | The version iOS shows when the Home Screen is set to *Dark*. |
| `icon-1024-tinted.png` | Optional | The version iOS shows when the Home Screen is set to *Tinted*. |

Put them in `App/Breviarium/Assets.xcassets/AppIcon.appiconset/`, replacing the current
`icon-1024.png`, or send them in chat. The `Contents.json` entries for the dark and tinted
versions are added when they arrive.

## Every file

- **1024 × 1024 pixels**, PNG, 8 bits per channel, sRGB (Display P3 also works).
- **Square, with square corners.** iOS cuts the rounded shape itself; drawing your own
  rounded corners leaves dark slivers at the edges.
- **Nothing important near the edges.** The rounded mask cuts about 10% off each corner.
  Keep the main shape inside the central 820 × 820 px, roughly, and let only the
  background run to the edges.
- **Readable when small.** The icon is 180 px on the Home Screen, 120 px in Spotlight and
  87 px in Settings. Lines thinner than about 12 px at 1024 disappear, and so does small
  text. A single strong shape reads best.

## The main icon (`icon-1024.png`)

- **Fully opaque: no transparency at all**, and preferably no alpha channel. A
  transparent pixel shows up black or causes a build warning.
- It's what the Home Screen shows in the default, light appearance.

## Dark version (optional)

- **The background is transparent**, and iOS puts its own dark background behind it. Draw
  only the foreground shape.
- Keep the shape's colours bright enough to stand out on near-black.

## Tinted version (optional)

- **Greyscale only.** iOS colours it with the tint the user picks.
- Transparent background, like the dark version. Lighter greys take more of the tint.
- Without one, iOS makes a tinted version from the main icon automatically.

## Matching the app

The app is night mode only. Its palette (`CLAUDE.md`, *Colours*):

| Colour | Used for |
|---|---|
| `#000000` | Background (pure black) |
| `#FFFFFF` | Text, headings, rules |
| `#FF8080` | Rubrics, the date line |
| `#FF4D33` | Icons, such as the table-of-contents button |
| `#B2B2B2` | Chrome text |

The icon doesn't have to use them, but a black ground with white and `#FF4D33`/`#FF8080`
will look like it belongs to the app.

## Why no Icon Composer

iOS 26's layered "Liquid Glass" icons are made in Apple's Icon Composer, which runs only
on a Mac. A plain 1024 px PNG in the asset catalog is still fully supported, and iOS 26
adds its glass edge on its own. So this route needs no Mac.

## How it's checked

- App CI compiles the asset catalog, so a wrong size or format fails the build.
- The UI tests can take a screenshot of the Home Screen in the simulator, so the icon
  can be checked before it's on the phone.
- The bundle identifier doesn't change, so a new icon costs no extra free-tier App ID.
