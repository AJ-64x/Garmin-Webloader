# Garmin Webloader (command line)

Copy Connect IQ `.prg` apps onto a Garmin that's plugged in over USB. It's the command-line companion to the [Garmin Webloader website](https://aj-64x.github.io/Garmin-Webloader/).

```bash
pip install garmin-webloader

garmin-webloader app.prg          # load a file onto your Garmin
garmin-webloader list             # see what's already on it
garmin-webloader remove app.prg   # take an app off it
```

It finds your Garmin on its own, and asks which one if you have several plugged in. Add `-d PATH` to point at the `GARMIN` folder or drive yourself, `-y` to skip the questions, and `--no-verify` to skip the double-check after copying.

Needs Python 3.8 or newer. Nothing else to install. Eject your Garmin safely before unplugging it.

Source and help: https://github.com/AJ-64x/Garmin-Webloader
