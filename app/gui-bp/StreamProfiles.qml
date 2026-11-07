import QtQuick
import QtQuick.Window

import StreamingPreferences 1.0
import SystemProperties 1.0

// Stream profiles for the Big Picture UI.
//
// A profile is a set of video options that is applied only for the duration
// of one stream: apply() snapshots the user's saved settings, and restore()
// puts them back once the session ends. Nothing here calls
// StreamingPreferences.save(), so profiles never overwrite the settings.
//
// Sources:
//   "device"    the display's current resolution and refresh rate
//   "settings"  whatever is configured in the settings (no change)
//   "preset:N"  a user preset saved from the settings page
QtObject {
    id: profiles

    // Persisted by BigPicture.qml (QtCore Settings)
    property string mode: "ask"            // "ask" | "device" | "settings"
    property string presetsJson: "[]"
    property string lastChoice: "settings"

    readonly property var presets: {
        try {
            var list = JSON.parse(presetsJson)
            return Array.isArray(list) ? list : []
        } catch (e) {
            return []
        }
    }

    // The window we're shown on, to pick the matching display
    property var hostWindow: null

    // Snapshot of the user's settings while a profile is applied
    property var savedSettings: null

    readonly property var fields: ["width", "height", "fps", "bitrateKbps", "autoAdjustBitrate",
                                   "videoCodecConfig", "enableHdr", "enableVsync", "framePacing"]

    function defaultBitrate(width, height, fps) {
        return StreamingPreferences.getDefaultBitrate(width, height, fps, StreamingPreferences.enableYUV444)
    }

    // Current mode of the display the UI is on
    function deviceProfile() {
        SystemProperties.waitForAsyncLoad()
        SystemProperties.refreshDisplays()

        // Find the SDL display that matches our window's screen (in native pixels)
        var index = 0
        if (hostWindow && hostWindow.screen) {
            // Screen info (width/height) or a QScreen (geometry), depending on Qt version
            var s = hostWindow.screen
            var dpr = s.devicePixelRatio || 1
            var w = Math.round((s.width !== undefined ? s.width : s.geometry.width) * dpr)
            var h = Math.round((s.height !== undefined ? s.height : s.geometry.height) * dpr)
            for (var i = 0; ; i++) {
                var rect = SystemProperties.getNativeResolution(i)
                if (rect.width === 0) {
                    break
                }
                if (rect.width === w && rect.height === h) {
                    index = i
                    break
                }
            }
        }

        var nativeRect = SystemProperties.getNativeResolution(index)
        var refresh = SystemProperties.getRefreshRate(index)

        var width = nativeRect.width > 0 ? nativeRect.width : StreamingPreferences.width
        var height = nativeRect.height > 0 ? nativeRect.height : StreamingPreferences.height
        var fps = refresh > 0 ? refresh : StreamingPreferences.fps

        return {
            "width": width,
            "height": height,
            "fps": fps,
            // Respect a manually chosen bitrate, otherwise scale it to the mode
            "bitrateKbps": StreamingPreferences.autoAdjustBitrate ? defaultBitrate(width, height, fps)
                                                                  : StreamingPreferences.bitrateKbps
        }
    }

    function settingsProfile() {
        var p = {}
        for (var i = 0; i < fields.length; i++) {
            p[fields[i]] = StreamingPreferences[fields[i]]
        }
        return p
    }

    function profileFor(key) {
        if (key === "device") {
            return deviceProfile()
        }
        if (key.indexOf("preset:") === 0) {
            var name = key.substring(7)
            for (var i = 0; i < presets.length; i++) {
                if (presets[i].name === name) {
                    return presets[i]
                }
            }
        }
        return null   // "settings": nothing to change
    }

    function describe(p) {
        if (!p) {
            p = settingsProfile()
        }
        var parts = [p.width + "×" + p.height, p.fps + " FPS"]
        if (p.bitrateKbps) {
            parts.push((p.bitrateKbps / 1000).toFixed(p.bitrateKbps < 10000 ? 1 : 0) + " Mbps")
        }
        if (p.enableHdr) {
            parts.push("HDR")
        }
        return parts.join("  ·  ")
    }

    function suggestedPresetName() {
        return StreamingPreferences.height + "p " + StreamingPreferences.fps
    }

    // ---- Presets ----------------------------------------------------------

    function savePreset(name) {
        var p = settingsProfile()
        p.name = name
        var list = presets.filter(function(x) { return x.name !== name })
        list.push(p)
        presetsJson = JSON.stringify(list)
    }

    function deletePreset(name) {
        presetsJson = JSON.stringify(presets.filter(function(x) { return x.name !== name }))
        if (lastChoice === "preset:" + name) {
            lastChoice = "settings"
        }
    }

    // ---- Applying ---------------------------------------------------------

    function apply(profile) {
        restore()
        if (!profile) {
            return
        }

        savedSettings = settingsProfile()
        for (var i = 0; i < fields.length; i++) {
            var f = fields[i]
            if (profile[f] !== undefined) {
                StreamingPreferences[f] = profile[f]
            }
        }
    }

    function restore() {
        if (savedSettings === null) {
            return
        }
        for (var i = 0; i < fields.length; i++) {
            StreamingPreferences[fields[i]] = savedSettings[fields[i]]
        }
        savedSettings = null
    }

    // Options for the picker: [{ key, title, detail, deletable }]
    function pickerOptions() {
        var options = [
            { "key": "device", "title": qsTr("This device"), "detail": describe(deviceProfile()), "deletable": false },
            { "key": "settings", "title": qsTr("My settings"), "detail": describe(null), "deletable": false }
        ]
        for (var i = 0; i < presets.length; i++) {
            options.push({ "key": "preset:" + presets[i].name, "title": presets[i].name,
                           "detail": describe(presets[i]), "deletable": true })
        }
        return options
    }

    // Asks (or not, depending on `mode`) and calls fn(profile) with the
    // profile to apply, or null to use the settings as they are.
    function choose(appName, fn) {
        if (mode === "device") {
            fn(deviceProfile())
            return
        }
        if (mode === "settings") {
            fn(null)
            return
        }

        hostWindow.openModal(pickerComponent, {
            "appName": appName,
            "profiles": profiles,
            "acceptedFn": function(key) {
                lastChoice = key
                fn(profileFor(key))
            }
        })
    }

    property Component pickerComponent: Component { StreamProfilePicker {} }
}
