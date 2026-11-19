<p align="center">
  <img src="assets/banner.svg" alt="Garmin Webloader: load Connect IQ apps onto your Garmin, right from your browser." width="100%">
</p>

# Garmin Webloader

Load Connect IQ apps (`.prg` files) onto your Garmin straight from your browser. No installs, no drivers.

**Use it:** https://aj-64x.github.io/Garmin-Webloader/

## How it works

1. **Files:** drop in your `.prg` file(s).
2. **Watch:** plug in your Garmin and choose its `GARMIN` folder (or the whole drive). It reads your watch’s model and shows what’s already installed.
3. **Load:** press the button. It copies the files into `GARMIN/Apps` and can double-check the copy.

When it’s done, use **Eject safely**, unplug, and look for the new app on your Garmin.

## Browsers

Needs the browser’s folder-access feature:

- Chrome, Edge, Opera, Vivaldi and Arc on Windows, Mac and Linux
- Chrome for Android 132 or newer
- Brave, after turning on `brave://flags/#file-system-access-api`

Firefox, Safari, Samsung Internet and iPhones/iPads can’t do it.

## No browser? Use the command line

Same job, no browser needed. Both do the same things and need nothing installed beyond Python or Node.

```bash
# Python 3.8+
python3 cli/webloader.py app.prg          # load a file onto your Garmin
python3 cli/webloader.py list             # see what's already on it
python3 cli/webloader.py remove app.prg   # take an app off it

# Node 16+
node cli/webloader.js app.prg
```

They find your Garmin on their own. If you have more than one plugged in, they ask which. Add `-d PATH` to point at the `GARMIN` folder or drive yourself, `-y` to skip the questions, and `--no-verify` to skip the double-check.

## Example app: a Monkey C watch face

`monkeyc/SimpleFace` is a small watch face written in Monkey C, Garmin’s own language: big time, date, heart rate, steps, battery and one extra field, with a frosted “glass” look. Open the folder in VS Code with Garmin’s Monkey C extension, pick your watch with **Monkey C: Edit Products**, then build it to get a `.prg` to load.

## Notes

- It doesn’t build apps. Build your `.prg` with the Connect IQ SDK first.
- Everything happens in your browser. Your files never leave your computer.
- If your Garmin shows up as a media device instead of a drive, your computer may not expose it to the browser. Copy the file into `GARMIN/Apps` by hand.

By [AJ 64](https://github.com/aj-64x), built with help from Claude (Anthropic).
