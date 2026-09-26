import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.Weather;
import Toybox.Time.Gregorian;
import Toybox.Time;

class FrogTimeView extends WatchUi.WatchFace {

    // Resources
    private var _frogImage as WatchUi.BitmapResource?;
    private var _heartIcon as WatchUi.BitmapResource?;
    private var _stepIcon as WatchUi.BitmapResource?;
    private var _metabolismIcon as WatchUi.BitmapResource?;
    private var _bluetoothIcon as WatchUi.BitmapResource?;
    
    // State variables
    private var _isAwake as Boolean = true;
    private var _isHighRes as Boolean = false;
    private var _isFenix8 as Boolean = false; // Pridaná premenná na detekciu Fenix 8

    // Coordinates (pre-calculated)
    private var _screenW, _screenH;
    private var _secX, _secY;
    private var _batX, _batY, _batWidth, _batHeight;
    private var _leftCenter, _rightCenter;
    private var _topIconY, _topTextY, _bottomIconY, _bottomTextY;
    private var _frogX, _frogY;

    // Icon sizes, fitted to the side-panel font height
    private var _sideFont;
    private var _stepIconW, _stepIconH;
    private var _heartIconW, _heartIconH;
    private var _metabolismIconW, _metabolismIconH;
    private var _bluetoothIconW, _bluetoothIconH;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));

        // 1. Get dimensions and determine display type only ONCE
        _screenW = dc.getWidth();
        _screenH = dc.getHeight();
        _isHighRes = (_screenW >= 360);
        _isFenix8 = (_screenW >= 416); // Ak je šírka 416 alebo 454, je to Fenix 8

        // 2. Adjust TimeLabel position and font (custom SF-alike font per device size)
        var view = View.findDrawableById("TimeLabel") as Text;
        var batRefY = _screenH * 0.1;
        var batRefHeight = 14;
        var spacing = -5;
        view.locY = (batRefY + batRefHeight + spacing).toNumber();

        // var timeFont;
        // if (_screenW >= 454) {
        //     timeFont = WatchUi.loadResource(Rez.Fonts.TimeFontFenix8);
        // } else if (_screenW >= 360) {
        //     timeFont = WatchUi.loadResource(Rez.Fonts.TimeFontFR265s);
        // } else {
        //     timeFont = WatchUi.loadResource(Rez.Fonts.TimeFontFenix7x);
        // }
        // view.setFont(timeFont);
    

        // 3. Load icons
        _heartIcon = WatchUi.loadResource(Rez.Drawables.IconHeartStandard) as WatchUi.BitmapResource;
        _stepIcon = WatchUi.loadResource(Rez.Drawables.IconSteps) as WatchUi.BitmapResource;
        _metabolismIcon = WatchUi.loadResource(Rez.Drawables.IconMetabolism) as WatchUi.BitmapResource;
        _bluetoothIcon = WatchUi.loadResource(Rez.Drawables.IconBluetooth) as WatchUi.BitmapResource;

        // 3b. Fit icon sizes to the side-panel font height (instead of using
        // each PNG's native pixel size), so icons and metric numbers scale together.
        _sideFont = Graphics.FONT_XTINY;
        var iconTargetH = dc.getFontHeight(_sideFont);
        if (_stepIcon != null) {
            var dims = fitIconToHeight(_stepIcon, iconTargetH);
            _stepIconW = dims[0]; _stepIconH = dims[1];
        }
        if (_heartIcon != null) {
            var dims = fitIconToHeight(_heartIcon, iconTargetH);
            _heartIconW = dims[0]; _heartIconH = dims[1];
        }
        if (_metabolismIcon != null) {
            var dims = fitIconToHeight(_metabolismIcon, iconTargetH);
            _metabolismIconW = dims[0]; _metabolismIconH = dims[1];
        }
        // Status row (battery + bluetooth) reads as a compact indicator, not body
        // text, so it's sized smaller than the side-panel icons instead of matching them 1:1.
        var statusIconH = (iconTargetH * 0.6).toNumber();
        if (_bluetoothIcon != null) {
            var dims = fitIconToHeight(_bluetoothIcon, statusIconH);
            _bluetoothIconW = dims[0]; _bluetoothIconH = dims[1];
        }

        // 4. Optimized frog image loading (only one!)
        if (_screenW >= 454) {
            // Pre Fenix 8 51mm (rozlíšenie 454x454)
            _frogImage = WatchUi.loadResource(Rez.Drawables.FrogImageFenix8) as WatchUi.BitmapResource;
        } 
        else if (_screenW >= 360) {
            // Pre stredne veľké AMOLED displeje (napr. FR265s s 360px)
            _frogImage = WatchUi.loadResource(Rez.Drawables.FrogImageFR265s) as WatchUi.BitmapResource;
        } 
        else {
            // Pre menšie displeje (napr. Fenix 7x)
            _frogImage = WatchUi.loadResource(Rez.Drawables.FrogImageFenix7x) as WatchUi.BitmapResource;
        }

        // 5. Pre-calculate coordinates (to avoid CPU load in onUpdate)
        
        // Seconds
        _secX = _screenW * 0.74;
        _secY = _screenH * 0.36;

        // Battery - sized to match the bluetooth status icon height
        _batHeight = statusIconH;
        _batWidth = _batHeight * 2;
        _batX = (_screenW - _batWidth) / 2;
        _batY = _screenH * 0.1;

        // Side panels
        _leftCenter = _screenW * 0.15; 
        _rightCenter = _screenW * 0.85; 

        if (_isHighRes) {
            _topIconY = _screenH * 0.35;   
            _topTextY = _screenH * 0.42;   
            _bottomIconY = _screenH * 0.54; 
            _bottomTextY = _screenH * 0.61; 
        } else {
            var midY = _screenH / 2; 
            _topIconY = midY - 45;
            _topTextY = midY - 20;
            _bottomIconY = midY + 5;
            _bottomTextY = midY + 30;
        }

        // Frog position
        if (_frogImage != null) {
            var imgW = _frogImage.getWidth();
            var imgH = _frogImage.getHeight();
            _frogX = (_screenW - imgW) / 2;
            // Positioning: 0.68 for FR265s, 0.65 for Fenix
            _frogY = _isHighRes ? (_screenH * 0.68) - (imgH / 2) : (_screenH * 0.65) - (imgH / 2); 
        }
    }

    // Returns [width, height] for an icon scaled to targetH, preserving aspect ratio.
    private function fitIconToHeight(icon as WatchUi.BitmapResource, targetH as Number) as Array<Number> {
        var nativeW = icon.getWidth();
        var nativeH = icon.getHeight();
        var scaledW = (nativeW * targetH / nativeH).toNumber();
        return [scaledW, targetH];
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // --- 1. TIME ---
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        var timeView = View.findDrawableById("TimeLabel") as Text;
        timeView.setText(timeString);

        // Draw background and TimeLabel from layout
        View.onUpdate(dc);

        // --- NOVÉ: Hrubší font času pre Fenix 8 ---
        if (_isFenix8) {
            var origX = timeView.locX;
            var origY = timeView.locY;
            
            timeView.locX = origX + 1;
            timeView.draw(dc);
            
            timeView.locX = origX + 2;
            timeView.draw(dc);

            timeView.locY = origY + 1;
            timeView.locX = origX + 1;
            timeView.draw(dc);
            
            // Vrátenie pôvodných súradníc
            timeView.locX = origX;
            timeView.locY = origY;
        }

        // --- 2. SECONDS (Zobrazené iba na FR265s / HighRes, odstránené pre Fenix 8) ---
        if (_isAwake && _isHighRes && !_isFenix8) {
            var secString = clockTime.sec.format("%02d");
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_secX, _secY, Graphics.FONT_XTINY, secString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- 3. BATTERY, PERCENTAGE AND BLUETOOTH ---
        var stats = System.getSystemStats();
        var battery = stats.battery; 

        // A) Drawing the battery
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_batX, _batY, _batWidth, _batHeight);
        dc.fillRectangle(_batX + _batWidth, _batY + (_batHeight / 4), 3, _batHeight / 2);

        var fillWidth = (_batWidth - 4) * (battery / 100.0); 
        if (battery <= 20.0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(_batX + 2, _batY + 2, fillWidth, _batHeight - 4);

        // B) Drawing percentage
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var textX = _batX + _batWidth + 8;
        var textCenterY = _batY + (_batHeight / 2);
        dc.drawText(textX, textCenterY, _sideFont, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // C) Drawing Bluetooth
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.phoneConnected && _bluetoothIcon != null) {
            var btX = _batX - _bluetoothIconW - 8;
            var btY = _batY + (_batHeight - _bluetoothIconH) / 2;
            dc.drawScaledBitmap(btX, btY, _bluetoothIconW, _bluetoothIconH, _bluetoothIcon);
        }

        // --- 4. HEALTH DATA ---
        var steps = 0;
        var calories = 0; 
        var activityInfo = ActivityMonitor.getInfo();
        if (activityInfo != null) {
            if (activityInfo.steps != null) { steps = activityInfo.steps; }
            if (activityInfo.calories != null) { calories = activityInfo.calories; }
        }

        var heartRateString = "--";
        var actInfo = Activity.getActivityInfo();
        var hr = null;
        if (actInfo != null && actInfo.currentHeartRate != null) {
            hr = actInfo.currentHeartRate;
        } else {
            var hrHistory = ActivityMonitor.getHeartRateHistory(1, true);
            var hrSample = hrHistory.next();
            if (hrSample != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hr = hrSample.heartRate;
            }
        }
        if (hr != null && hr > 0) {
            heartRateString = hr.toString();
        }

        // --- 5. SIDE PANELS ---
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var sideFont = _sideFont;

        // -- LEFT SIDE --
        if (_stepIcon != null) {
            dc.drawScaledBitmap(_leftCenter - (_stepIconW / 2), _topIconY, _stepIconW, _stepIconH, _stepIcon);
        }
        dc.drawText(_leftCenter, _topTextY, sideFont, steps.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dc.drawText(_leftCenter, _bottomIconY, sideFont, today.day.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_leftCenter, _bottomTextY, sideFont, today.month.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        // -- RIGHT SIDE --
        if (_heartIcon != null) {
            dc.drawScaledBitmap(_rightCenter - (_heartIconW / 2), _topIconY, _heartIconW, _heartIconH, _heartIcon);
        }
        dc.drawText(_rightCenter, _topTextY, sideFont, heartRateString, Graphics.TEXT_JUSTIFY_CENTER);

        if (_metabolismIcon != null) {
            dc.drawScaledBitmap(_rightCenter - (_metabolismIconW / 2), _bottomIconY, _metabolismIconW, _metabolismIconH, _metabolismIcon);
        }
        dc.drawText(_rightCenter, _bottomTextY, sideFont, calories.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // --- 6. FROG IMAGE ---
        if (_frogImage != null) {
            dc.drawBitmap(_frogX, _frogY, _frogImage);
        }
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }
}