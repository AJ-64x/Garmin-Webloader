#!/usr/bin/env python3
"""
Garmin Webloader (command line, Python)

Copy Connect IQ .prg files onto a Garmin that's plugged in over USB.

    python3 webloader.py app.prg            load a file onto your Garmin
    python3 webloader.py list               see what's already on it
    python3 webloader.py remove app.prg     take an app off it

Options:
    -d, --device PATH   the GARMIN folder, the Apps folder, or the whole drive
    -y, --yes           don't ask before replacing or removing
    --no-verify         skip the double-check after copying

Needs Python 3.8 or newer. Nothing to install.
"""
import argparse
import hashlib
import os
import platform
import string
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

COMMANDS = {"load", "list", "remove"}


def fail(message):
    print("Oops: " + message, file=sys.stderr)
    sys.exit(1)


def child(parent, name):
    """Find a folder inside `parent`, ignoring upper and lower case."""
    try:
        with os.scandir(parent) as entries:
            for entry in entries:
                if entry.name.lower() == name.lower() and entry.is_dir():
                    return Path(entry.path)
    except OSError:
        pass
    return None


def subfolders(path):
    try:
        with os.scandir(path) as entries:
            return [Path(e.path) for e in entries if e.is_dir()]
    except OSError:
        return []


def drive_roots():
    system = platform.system()
    if system == "Windows":
        roots = []
        for letter in string.ascii_uppercase:
            p = Path(letter + ":\\")
            try:
                if p.exists():
                    roots.append(p)
            except OSError:
                pass
        return roots
    if system == "Darwin":
        return subfolders(Path("/Volumes"))
    user = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    roots = []
    for base in (Path("/media") / user, Path("/run/media") / user, Path("/media"), Path("/mnt")):
        roots += subfolders(base)
    return roots


class Device:
    def __init__(self, garmin, apps=None):
        self.garmin = garmin
        self.apps = apps or child(garmin, "Apps")
        self.name = self._read_name()

    def _read_name(self):
        try:
            xml_path = self.garmin / "GarminDevice.xml"
            root = ET.parse(xml_path).getroot()
            for el in root.iter():
                if el.tag.split("}")[-1] == "Model":
                    for sub in el.iter():
                        if sub.tag.split("}")[-1] == "Description" and (sub.text or "").strip():
                            return sub.text.strip()
        except (OSError, ET.ParseError):
            pass
        return None

    def label(self):
        return (self.name + " " if self.name else "") + "(" + str(self.garmin) + ")"

    def apps_dir(self):
        if self.apps is None:
            self.apps = self.garmin / "Apps"
            self.apps.mkdir(exist_ok=True)
            print("Made a new Apps folder on your Garmin.")
        return self.apps

    def programs(self):
        if self.apps is None:
            return []
        return sorted((p for p in self.apps.iterdir() if p.is_file() and p.suffix.lower() == ".prg"),
                      key=lambda p: p.name.lower())


def device_from_path(text):
    path = Path(text).expanduser()
    if not path.is_dir():
        fail("“" + text + "” isn't a folder.")
    lower = path.name.lower()
    if lower == "apps":
        return Device(path.parent, path)
    if lower == "garmin":
        return Device(path)
    inside = child(path, "GARMIN")
    if inside is None:
        fail("There's no GARMIN folder inside “" + text + "”. Is that your Garmin's drive?")
    return Device(inside)


def pick_device(args):
    if args.device:
        return device_from_path(args.device)
    found, seen = [], set()
    for root in drive_roots():
        garmin = root if root.name.upper() == "GARMIN" else child(root, "GARMIN")
        if garmin and garmin not in seen:
            seen.add(garmin)
            found.append(Device(garmin))
    if not found:
        fail("Couldn't find a Garmin. Plug it in and wait for it to show up as a drive. "
             "If it only appears as a media device, copy the file into GARMIN/Apps yourself, "
             "or point me at it with --device.")
    if len(found) == 1:
        return found[0]
    print("I found more than one Garmin:")
    for i, d in enumerate(found, 1):
        print("  " + str(i) + ") " + d.label())
    answer = input("Which one? [1-" + str(len(found)) + "] ").strip()
    if not answer.isdigit() or not 1 <= int(answer) <= len(found):
        fail("That wasn't one of the choices.")
    return found[int(answer) - 1]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def size_text(n):
    return str(n) + " B" if n < 1024 else (("%.1f" % (n / 1024)) + " KB" if n < 1048576 else ("%.1f" % (n / 1048576)) + " MB")


def yes(question, assume_yes):
    return assume_yes or input(question + " [y/N] ").strip().lower() in ("y", "yes")


def cmd_load(args):
    files = [Path(f) for f in args.files]
    for f in files:
        if not f.is_file():
            fail("Can't find “" + str(f) + "”.")
        if f.suffix.lower() != ".prg":
            fail("“" + f.name + "” isn't a .prg file. Only .prg files work here.")
        if f.stat().st_size == 0:
            fail("“" + f.name + "” is empty.")
    device = pick_device(args)
    print("Connected to " + device.label())
    target = device.apps_dir()
    for f in files:
        dest = target / f.name
        if dest.exists() and not yes(f.name + " is already on your Garmin. Replace it?", args.yes):
            print("Skipped " + f.name)
            continue
        print("Copying " + f.name + " (" + size_text(f.stat().st_size) + ")...")
        with open(f, "rb") as src, open(dest, "wb") as out:
            for chunk in iter(lambda: src.read(1 << 18), b""):
                out.write(chunk)
            out.flush()
            os.fsync(out.fileno())
        if not args.no_verify and sha256(f) != sha256(dest):
            fail(f.name + " didn't copy cleanly. Give it another try.")
        print("  done" + ("" if args.no_verify else ", checked and good"))
    print("All done! Eject your Garmin safely before you unplug it, then look for the new app on it.")


def cmd_list(args):
    device = pick_device(args)
    print("Connected to " + device.label())
    programs = device.programs()
    if not programs:
        print("Nothing installed from a file yet.")
        return
    for p in programs:
        st = p.stat()
        print("  " + p.name.ljust(36) + size_text(st.st_size).rjust(9) + "   " +
              datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d"))


def cmd_remove(args):
    device = pick_device(args)
    print("Connected to " + device.label())
    for name in args.files:
        match = next((p for p in device.programs() if p.name.lower() == Path(name).name.lower()), None)
        if match is None:
            print("Couldn't find " + name + " on your Garmin.")
            continue
        if yes("Remove " + match.name + " from your Garmin?", args.yes):
            match.unlink()
            print("Removed " + match.name)


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if argv and argv[0] not in COMMANDS and not argv[0].startswith("-"):
        argv = ["load"] + argv  # `webloader.py app.prg` is a shortcut for `load`
    parser = argparse.ArgumentParser(description="Copy Connect IQ .prg files onto a Garmin.")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, func, takes_files in (("load", cmd_load, True), ("list", cmd_list, False), ("remove", cmd_remove, True)):
        p = sub.add_parser(name)
        if takes_files:
            p.add_argument("files", nargs="+")
        p.add_argument("-d", "--device")
        p.add_argument("-y", "--yes", action="store_true")
        if name == "load":
            p.add_argument("--no-verify", action="store_true")
        p.set_defaults(func=func)
    args = parser.parse_args(argv)
    try:
        args.func(args)
    except KeyboardInterrupt:
        print("\nStopped.")
    except PermissionError as e:
        fail("The Garmin wouldn't let me write there (" + str(e) + ").")


if __name__ == "__main__":
    main(sys.argv[1:])
