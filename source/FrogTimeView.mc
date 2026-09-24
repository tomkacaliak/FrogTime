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

        // 2. Adjust TimeLabel position
        var view = View.findDrawableById("TimeLabel") as Text;
        var batRefY = _screenH * 0.1;
        var batRefHeight = 14;
        var spacing = -5; 
        view.locY = (batRefY + batRefHeight + spacing).toNumber();

        // 3. Load icons
        _heartIcon = WatchUi.loadResource(Rez.Drawables.IconHeartStandard) as WatchUi.BitmapResource;
        _stepIcon = WatchUi.loadResource(Rez.Drawables.IconSteps) as WatchUi.BitmapResource;
        _metabolismIcon = WatchUi.loadResource(Rez.Drawables.IconMetabolism) as WatchUi.BitmapResource;
        _bluetoothIcon = WatchUi.loadResource(Rez.Drawables.IconBluetooth) as WatchUi.BitmapResource;
        
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

        // Battery
        _batWidth = _isHighRes ? 36 : 30; 
        _batHeight = _isHighRes ? 18 : 14; 
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
        dc.drawText(textX, textCenterY, Graphics.FONT_XTINY, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // C) Drawing Bluetooth
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.phoneConnected && _bluetoothIcon != null) {
            var btX = _batX - _bluetoothIcon.getWidth() - 8; 
            var btY = _batY + (_batHeight - _bluetoothIcon.getHeight()) / 2; 
            dc.drawBitmap(btX, btY, _bluetoothIcon);
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
        var sideFont = Graphics.FONT_XTINY; 
        
        // -- LEFT SIDE --
        if (_stepIcon != null) {
            dc.drawBitmap(_leftCenter - (_stepIcon.getWidth() / 2), _topIconY, _stepIcon);
        }
        dc.drawText(_leftCenter, _topTextY, sideFont, steps.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dc.drawText(_leftCenter, _bottomIconY, sideFont, today.day.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_leftCenter, _bottomTextY, sideFont, today.month.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        // -- RIGHT SIDE --
        if (_heartIcon != null) {
            dc.drawBitmap(_rightCenter - (_heartIcon.getWidth() / 2), _topIconY, _heartIcon);
        }
        dc.drawText(_rightCenter, _topTextY, sideFont, heartRateString, Graphics.TEXT_JUSTIFY_CENTER);

        if (_metabolismIcon != null) {
            dc.drawBitmap(_rightCenter - (_metabolismIcon.getWidth() / 2), _bottomIconY, _metabolismIcon);
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