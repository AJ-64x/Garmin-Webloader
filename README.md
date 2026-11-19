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

## Notes

- It doesn’t build apps. Build your `.prg` with the Connect IQ SDK first.
- Everything happens in your browser. Your files never leave your computer.
- If your Garmin shows up as a media device instead of a drive, your computer may not expose it to the browser. Copy the file into `GARMIN/Apps` by hand.

By [AJ 64](https://github.com/aj-64x)
