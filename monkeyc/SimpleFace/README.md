# Simple Face

A small watch face for Garmin, written in Monkey C. Use it as-is or as a starting point for your own.

**What it shows:** time, date, heart rate, steps (the panel fills toward your goal), battery (fills up, turns red when low), whether your phone is connected, and one extra field you can choose.

**How it looks:** frosted “glass” panels. Color watches get a gradient background and four themes. Black-and-white watches (Instinct) get frosted dots instead.

## Build it

You only set this up once.

1. Install [Visual Studio Code](https://code.visualstudio.com).
2. Install Garmin’s [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/), download the newest SDK, and tick your watch on its **Devices** tab.
3. In VS Code, install the **Monkey C** extension by Garmin.

Then, for this watch face:

1. **File → Open Folder** and choose this `SimpleFace` folder.
2. Press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac), run **Monkey C: Edit Products**, and tick your watch.
3. Run **Monkey C: Generate a Developer Key** and save it somewhere safe. Never share it or put it in Git.
4. Press `F5` to try it in the simulator.
5. Run **Monkey C: Build for Device**, pick your watch, and choose where to save. You’ll get `SimpleFace.prg`.
6. Load that file onto your watch with [Webloader](https://aj-64x.github.io/Garmin-Webloader/).

The project is set up for the Instinct 2S by default. Build once per watch model.

## Change the theme or extra field

Open `resources/properties.xml` and change the numbers, then rebuild and load it again.

| Setting | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| `Theme` (color watches) | Ocean | Sunset | Mint | Graphite |
| `Field` | Calories | Distance | Floors climbed | Notifications |

Faces loaded from a file can’t be changed in the Garmin phone app, which is why this is done in the project.

## If something goes wrong

- **“Unknown product” when building:** use **Monkey C: Edit Products** and pick your watch from the list.
- **Text looks cramped:** try the simulator for your exact model and tweak the layout numbers in `source/SimpleFaceView.mc`.
