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

    private var _imageMMamaKvaMiniKvaFenix7x as WatchUi.BitmapResource?;
    private var _imageMMamaKvaMiniKvaFR265s as WatchUi.BitmapResource?;

    private var _heartIcon as WatchUi.BitmapResource?;
    private var _stepIcon as WatchUi.BitmapResource?;
    private var _metabolismIcon as WatchUi.BitmapResource?;
    private var _bluetoothIcon as WatchUi.BitmapResource?;
    
    private var _isAwake as Boolean = true;
    
    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    
        var view = View.findDrawableById("TimeLabel") as Text;
        var batY = dc.getHeight() * 0.1;
        var batHeight = 14;
        var spacing = -5; 
        view.locY = (batY + batHeight + spacing).toNumber();

        // Loading icons
        _heartIcon = WatchUi.loadResource(Rez.Drawables.IconHeartStandard) as WatchUi.BitmapResource;
        _stepIcon = WatchUi.loadResource(Rez.Drawables.IconSteps) as WatchUi.BitmapResource;
        _metabolismIcon = WatchUi.loadResource(Rez.Drawables.IconMetabolism) as WatchUi.BitmapResource;
        _bluetoothIcon = WatchUi.loadResource(Rez.Drawables.IconBluetooth) as WatchUi.BitmapResource;
        
        // Loading specific images for "MamaKvaMiniKva" ONLY
        _imageMMamaKvaMiniKvaFenix7x = WatchUi.loadResource(Rez.Drawables.FrogImageFenix7x) as WatchUi.BitmapResource;
        _imageMMamaKvaMiniKvaFR265s = WatchUi.loadResource(Rez.Drawables.FrogImageFR265s) as WatchUi.BitmapResource;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // --- 1. TIME ---
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        var timeView = View.findDrawableById("TimeLabel") as Text;
        timeView.setText(timeString);

        View.onUpdate(dc);

        var screenW = dc.getWidth();
        var screenH = dc.getHeight();

        // --- DISPLAY RECOGNITION ---
        var isHighRes = (screenW >= 360); 

        // --- 2. SECONDS (ONLY FOR FR265s / HighRes) ---
        if (_isAwake && isHighRes) {
            var secString = clockTime.sec.format("%02d");
            var secX = screenW * 0.74;
            var secY = screenH * 0.36;
            
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(secX, secY, Graphics.FONT_XTINY, secString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- 3. BATTERY, PERCENTAGE AND BLUETOOTH ---
        var stats = System.getSystemStats();
        var battery = stats.battery; 

        var batWidth = isHighRes ? 36 : 30; 
        var batHeight = isHighRes ? 18 : 14; 
        var batX = (screenW - batWidth) / 2; 
        var batY = screenH * 0.1; 

        // A) Drawing the battery
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(batX, batY, batWidth, batHeight);
        dc.fillRectangle(batX + batWidth, batY + (batHeight / 4), 3, batHeight / 2);

        var fillWidth = (batWidth - 4) * (battery / 100.0); 
        if (battery <= 20.0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(batX + 2, batY + 2, fillWidth, batHeight - 4);

        // B) Drawing percentage
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var textX = batX + batWidth + 8; 
        var batFont = Graphics.FONT_XTINY; 
        var textCenterY = batY + (batHeight / 2);
        dc.drawText(textX, textCenterY, batFont, battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // C) Drawing Bluetooth
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings.phoneConnected && _bluetoothIcon != null) {
            var btX = batX - _bluetoothIcon.getWidth() - 8; 
            var btY = batY + (batHeight - _bluetoothIcon.getHeight()) / 2; 
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
        
        var leftCenter = screenW * 0.15; 
        var rightCenter = screenW * 0.85; 

        var topIconY, topTextY, bottomIconY, bottomTextY;

        if (isHighRes) {
            topIconY = screenH * 0.35;   
            topTextY = screenH * 0.42;   
            bottomIconY = screenH * 0.54; 
            bottomTextY = screenH * 0.61; 
        } else {
            var midY = screenH / 2; 
            topIconY = midY - 45;
            topTextY = midY - 20;
            bottomIconY = midY + 5;
            bottomTextY = midY + 30;
        }

        // -- LEFT SIDE --
        if (_stepIcon != null) {
            dc.drawBitmap(leftCenter - (_stepIcon.getWidth() / 2), topIconY, _stepIcon);
        }
        dc.drawText(leftCenter, topTextY, sideFont, steps.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dc.drawText(leftCenter, bottomIconY, sideFont, today.day.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(leftCenter, bottomTextY, sideFont, today.month.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        // -- RIGHT SIDE --
        if (_heartIcon != null) {
            dc.drawBitmap(rightCenter - (_heartIcon.getWidth() / 2), topIconY, _heartIcon);
        }
        dc.drawText(rightCenter, topTextY, sideFont, heartRateString, Graphics.TEXT_JUSTIFY_CENTER);

        if (_metabolismIcon != null) {
            dc.drawBitmap(rightCenter - (_metabolismIcon.getWidth() / 2), bottomIconY, _metabolismIcon);
        }
        dc.drawText(rightCenter, bottomTextY, sideFont, calories.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // --- 6. FROG IMAGE (MAMAKVAMINIKVA) ---
        var currentImage = null;

        if (isHighRes) {
            currentImage = _imageMMamaKvaMiniKvaFR265s;
        } else {
            currentImage = _imageMMamaKvaMiniKvaFenix7x;
        }

        if (currentImage != null) {
            var imgW = currentImage.getWidth();
            var imgH = currentImage.getHeight();
            var imgX = (screenW - imgW) / 2;
            
            // Positioning: 0.68 for FR265s, 0.65 for Fenix
            var imgY = isHighRes ? (screenH * 0.68) - (imgH / 2) : (screenH * 0.65) - (imgH / 2); 
            
            dc.drawBitmap(imgX, imgY, currentImage);
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