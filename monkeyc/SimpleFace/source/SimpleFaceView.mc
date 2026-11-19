import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Liquid Glass watch face.
//  - Black & white watches (Instinct): frosted dotted glass panels.
//  - Color watches: gradient background, tinted glass panels, bright rims.
//  - AMOLED watches: simple dim screen in always-on mode (burn-in safe).
class SimpleFaceView extends WatchUi.WatchFace {

    var mono as Boolean = false;
    var sleeping as Boolean = false;
    var cPanel as Number = 0x1f4f7a;
    var cRim as Number = 0xa8dcff;
    var cFill as Number = 0x2d8fc0;

    function initialize() {
        WatchFace.initialize();
    }

    function onEnterSleep() as Void {
        sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        sleeping = false;
        WatchUi.requestUpdate();
    }

    // Mix color a toward color b. t is 0..100.
    function blend(a as Number, b as Number, t as Number) as Number {
        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF;
        var bg = (b >> 8) & 0xFF;
        var bb = b & 0xFF;
        var r = ar + ((br - ar) * t) / 100;
        var g = ag + ((bg - ag) * t) / 100;
        var bl = ab + ((bb - ab) * t) / 100;
        return (r << 16) | (g << 8) | bl;
    }

    function getProp(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v != null && v instanceof Number) {
            return v;
        }
        return def;
    }

    // First font in the list where every text fits. Returns -1 if none do.
    function fitFont(dc as Dc, texts as Array<String>, fonts as Array<Number>,
                     maxW as Number, maxH as Number) as Number {
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i];
            var ok = (dc.getFontHeight(f) <= maxH);
            for (var j = 0; j < texts.size(); j++) {
                if (dc.getTextWidthInPixels(texts[j], f) > maxW) {
                    ok = false;
                }
            }
            if (ok) {
                return f;
            }
        }
        return -1;
    }

    // One glass panel.
    //   frost: black & white watches, how much of the panel is frosted (0..100)
    //   fill:  color watches, how much of the panel is tinted (0..100, -1 = none)
    function glass(dc as Dc, x as Number, y as Number, pw as Number, ph as Number,
                   pen as Number, step as Number, frost as Number, fill as Number) as Void {
        var r = ph / 4;
        var g = pen * 2;
        dc.setPenWidth(pen);

        if (mono) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (frost > 0) {
                var xEnd = x + (pw * frost) / 100;
                var row = 0;
                for (var yy = y + r / 2; yy < y + ph - r / 2; yy += step) {
                    var off = (row % 2 == 0) ? 0 : step / 2;
                    for (var xx = x + r / 2 + off; xx < xEnd - r / 2; xx += step) {
                        dc.fillRectangle(xx, yy, pen, pen);
                    }
                    row++;
                }
            }
        } else {
            dc.setColor(cPanel, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, pw, ph, r);
            if (fill > 0) {
                dc.setColor(cFill, Graphics.COLOR_TRANSPARENT);
                dc.setClip(x, y, (pw * fill) / 100, ph);
                dc.fillRoundedRectangle(x, y, pw, ph, r);
                dc.clearClip();
            }
            dc.setColor(cRim, Graphics.COLOR_TRANSPARENT);
        }

        // glass edge (outer and inner rim)
        dc.drawRoundedRectangle(x, y, pw, ph, r);
        dc.drawRoundedRectangle(x + g, y + g, pw - 2 * g, ph - 2 * g, r - g);
        // shine
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + r, y + g * 2, x + pw / 3, y + g * 2);
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var ds = System.getDeviceSettings();
        var round = (ds.screenShape == System.SCREEN_SHAPE_ROUND);
        // Every black & white Instinct has a semi-octagon screen
        mono = (ds.screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON);

        var burnIn = false;
        if (ds has :requiresBurnInProtection) {
            burnIn = ds.requiresBurnInProtection;
        }

        // ----- time -----
        var clock = System.getClockTime();
        var hours = clock.hour;
        if (!ds.is24Hour) {
            hours = hours % 12;
            if (hours == 0) { hours = 12; }
        }
        var timeStr = hours.format("%02d") + ":" + clock.min.format("%02d");
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var bigFonts = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT,
                        Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];

        // always-on mode for AMOLED: dim, small, no big bright areas
        if (sleeping && burnIn) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            var sf = fitFont(dc, [timeStr], bigFonts, (w * 0.5).toNumber(), (h * 0.25).toNumber());
            if (sf < 0) { sf = Graphics.FONT_NUMBER_MILD; }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, sf, timeStr, just);
            return;
        }

        // ----- theme and background -----
        var themes = [
            [0x061a33, 0x0b5c7a, 0x1f4f7a, 0xa8dcff, 0x37c8ff],   // Ocean
            [0x2a0a3a, 0xd0502e, 0x7a2f55, 0xffc9a8, 0xffb347],   // Sunset
            [0x07211b, 0x1e8f6b, 0x1d6a55, 0xc9ffe9, 0x7dffc1],   // Mint
            [0x111111, 0x3a3f47, 0x2c3139, 0xd0d5dc, 0xffffff]    // Graphite
        ];
        var themeId = getProp("Theme", 0);
        if (themeId < 0 || themeId >= themes.size()) { themeId = 0; }
        var t = themes[themeId] as Array<Number>;
        cPanel = t[2];
        cRim = t[3];
        cFill = blend(cPanel, t[4], 55);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (!mono) {
            var bands = 32;
            for (var i = 0; i < bands; i++) {
                dc.setColor(blend(t[0], t[1], (i * 100) / (bands - 1)), Graphics.COLOR_BLACK);
                var y0 = (i * h) / bands;
                var y1 = ((i + 1) * h) / bands;
                dc.fillRectangle(0, y0, w, y1 - y0 + 1);
            }
        }

        // ----- data -----
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateLong = today.day_of_week + " " + today.month + " " + today.day.toString();
        var dateShort = today.day_of_week + " " + today.day.toString();

        var info = ActivityMonitor.getInfo();
        var steps = 0;
        if (info.steps != null) { steps = info.steps; }
        var goal = 10000;
        if (info.stepGoal != null && info.stepGoal > 0) { goal = info.stepGoal; }
        var stepPct = (steps * 100) / goal;
        if (stepPct > 100) { stepPct = 100; }

        var batPct = System.getSystemStats().battery.toNumber();

        var hrStr = "--";
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            var sample = it.next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hrStr = sample.heartRate.toString();
            }
        }

        var field = getProp("Field", 0);
        var fieldLabel = "CAL";
        var fieldVal = "--";
        if (field == 0) {
            if (info.calories != null) { fieldVal = info.calories.toString(); }
        } else if (field == 1) {
            if (info.distance != null) {
                if (ds.distanceUnits == System.UNIT_METRIC) {
                    fieldLabel = "KM";
                    fieldVal = (info.distance / 100000.0).format("%.1f");
                } else {
                    fieldLabel = "MI";
                    fieldVal = (info.distance / 160934.0).format("%.1f");
                }
            }
        } else if (field == 2) {
            fieldLabel = "FL";
            if ((info has :floorsClimbed) && info.floorsClimbed != null) {
                fieldVal = info.floorsClimbed.toString();
            }
        } else {
            fieldLabel = "MSG";
            fieldVal = ds.notificationCount.toString();
        }

        // ----- layout (round screens are centered, others keep the top-right corner free) -----
        var pen = w / 160;
        if (pen < 1) { pen = 1; }
        var g = pen * 2;
        var step = w / 40;
        if (step < 3) { step = 3; }

        var dx = (w * 0.08).toNumber();
        var dw = (w * 0.50).toNumber();
        var lx = (w * 0.09).toNumber();
        var rx = (w * 0.53).toNumber();
        var pw = (w * 0.38).toNumber();
        if (round) {
            dx = (w * 0.30).toNumber();
            dw = (w * 0.40).toNumber();
            lx = (w * 0.20).toNumber();
            rx = (w * 0.52).toNumber();
            pw = (w * 0.28).toNumber();
        }
        var dy = (h * 0.07).toNumber();
        var dh = (h * 0.12).toNumber();
        var ty = (h * 0.22).toNumber();
        var th = (h * 0.34).toNumber();
        var tx = (w * 0.10).toNumber();
        var tw = (w * 0.80).toNumber();
        var r1 = (h * 0.60).toNumber();
        var r2 = (h * 0.77).toNumber();
        var ph = (h * 0.13).toNumber();

        // ----- pick fonts -----
        var smallFonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL,
                          Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var pillW = pw - 4 * g - 2;
        var pillH = ph - 2 * pen;
        var labeled = ["HR " + hrStr, "ST " + steps.toString(),
                       batPct.toString() + "%", fieldLabel + " " + fieldVal];
        var plain = [hrStr, steps.toString(), batPct.toString() + "%", fieldVal];
        var pillText = labeled;
        var pf = fitFont(dc, labeled, smallFonts, pillW, pillH);
        if (pf < 0) {
            pillText = plain;
            pf = fitFont(dc, plain, smallFonts, pillW, pillH);
        }
        if (pf < 0) { pf = Graphics.FONT_XTINY; }

        var dotR = pen * 2;
        var dateW = dw - 4 * g - dotR * 3;
        var dateText = dateLong;
        var df = fitFont(dc, [dateLong], smallFonts, dateW, dh - 2 * pen);
        if (df < 0) {
            dateText = dateShort;
            df = fitFont(dc, [dateShort], smallFonts, dateW, dh - 2 * pen);
        }
        if (df < 0) { df = Graphics.FONT_XTINY; }

        var tf = fitFont(dc, [timeStr], bigFonts, (tw * 0.9).toNumber(), (th * 0.92).toNumber());
        if (tf < 0) { tf = Graphics.FONT_NUMBER_MILD; }

        // ----- draw the glass -----
        glass(dc, dx, dy, dw, dh, pen, step, 0, -1);
        glass(dc, tx, ty, tw, th, pen, step, 100, -1);
        glass(dc, lx, r1, pw, ph, pen, step, 0, -1);                  // heart rate
        glass(dc, rx, r1, pw, ph, pen, step, stepPct, stepPct);        // steps fill up
        var savedFill = cFill;
        if (batPct <= 20 && !mono) {
            cFill = blend(cPanel, 0xFF3B30, 70);                       // low battery: red
        }
        glass(dc, lx, r2, pw, ph, pen, step, batPct, batPct);          // battery fills up
        cFill = savedFill;
        glass(dc, rx, r2, pw, ph, pen, step, 0, -1);                   // extra field

        // ----- text on top -----
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dx + dw / 2 - dotR, dy + dh / 2, df, dateText, just);
        dc.drawText(tx + tw / 2, ty + th / 2, tf, timeStr, just);
        dc.drawText(lx + pw / 2, r1 + ph / 2, pf, pillText[0], just);
        dc.drawText(rx + pw / 2, r1 + ph / 2, pf, pillText[1], just);
        dc.drawText(lx + pw / 2, r2 + ph / 2, pf, pillText[2], just);
        dc.drawText(rx + pw / 2, r2 + ph / 2, pf, pillText[3], just);

        // phone connection dot: filled = connected, ring = not connected
        var dotX = dx + dw - g - dotR * 2;
        var dotY = dy + dh / 2;
        dc.setColor(mono ? Graphics.COLOR_WHITE : t[4], Graphics.COLOR_TRANSPARENT);
        if (ds.phoneConnected) {
            dc.fillCircle(dotX, dotY, dotR);
        } else {
            dc.setPenWidth(pen);
            dc.drawCircle(dotX, dotY, dotR);
        }
    }
}
