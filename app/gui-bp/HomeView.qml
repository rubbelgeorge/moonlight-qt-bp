import QtQuick
import QtQuick.Controls

import ComputerModel 1.0
import AppModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import BpInput 1.0
import "."

// Home screen: host tabs on top, a horizontal shelf of games below.
//   LB/RB      switch host           Up/Down   switch between tab bar and shelf
//   A          start / resume        X         options for the focused item
//   Start      settings              B         exit Moonlight
FocusScope {
    id: home

    property ComputerModel computerModel: createComputerModel()
    property AppModel appModel: null

    property int hostIndex: 0
    property string zone: "apps"        // "tabs" or "apps"
    property int tabIndex: 0            // hosts..., then "add", then "settings"
    property var pairDialog: null

    readonly property int hostCount: hostRepeater.count
    readonly property int addTabIndex: hostCount
    readonly property int settingsTabIndex: hostCount + 1
    // Bumped whenever host delegates are (re)created, e.g. on a model reset,
    // so `host` never points at a destroyed delegate
    property int hostRevision: 0
    readonly property var host: (hostRevision, hostCount > 0 && hostIndex < hostCount) ? hostRepeater.itemAt(hostIndex) : null
    readonly property bool hostReady: host !== null && host.online && host.paired && host.serverSupported
    readonly property var focusedApp: appList.currentItem

    // Collapse the state of the selected host into one string for the UI
    readonly property string hostState: {
        if (hostCount === 0) return "none"
        if (host === null) return "none"
        if (host.statusUnknown) return "connecting"
        if (!host.online) return "offline"
        if (!host.serverSupported) return "unsupported"
        if (!host.paired) return "unpaired"
        if (appModel !== null && appList.count === 0) return "loading"
        return "ready"
    }

    Binding {
        target: window
        property: "heroSource"
        value: home.hostReady && home.focusedApp ? home.focusedApp.boxart : ""
        when: home.StackView.status === StackView.Active
        restoreMode: Binding.RestoreNone
    }

    function createComputerModel() {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', home, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingCompleted)
        return model
    }

    function reloadApps() {
        var old = appModel
        appModel = null
        if (old !== null) {
            old.destroy()
        }

        if (hostReady) {
            var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', home, '')
            model.initialize(ComputerManager, hostIndex, false)
            appModel = model
            appList.currentIndex = 0
        }
    }

    onHostReadyChanged: reloadApps()
    onHostIndexChanged: reloadApps()

    StackView.onActivated: {
        if (appModel === null && hostReady) {
            reloadApps()
        }
    }

    // ---- Host actions ---------------------------------------------------

    function selectHost(index) {
        if (index < 0 || index >= hostCount || index === hostIndex) {
            return
        }
        hostIndex = index
        tabIndex = index
        window.focusMoved()
    }

    function pairingCompleted(error) {
        if (pairDialog !== null) {
            pairDialog.close()
            pairDialog = null
        }
        if (error !== undefined) {
            window.showMessage(qsTr("Pairing failed"), error)
        }
    }

    function pairHost(index) {
        var name = hostRepeater.itemAt(index).name
        var pin = computerModel.generatePinString()
        computerModel.pairComputer(index, pin)
        pairDialog = window.showPin(qsTr("Pair with %1").arg(name),
                                    qsTr("Enter this PIN on your host PC (Sunshine web UI or the GeForce Experience prompt). This closes automatically once pairing is done."),
                                    pin)
        pairDialog.closed.connect(function() { home.pairDialog = null })
    }

    function wakeHost(index) {
        computerModel.wakeComputer(index)
        window.showMessage(qsTr("Wake-on-LAN sent"),
                           qsTr("%1 should come online shortly.").arg(hostRepeater.itemAt(index).name))
    }

    function addHost() {
        window.showKeyboard(qsTr("Add PC: IP address or hostname"), "", function(address) {
            address = address.trim()
            if (address === "") {
                return
            }

            var busy = window.showBusy(qsTr("Adding PC"), address)
            var handler = function(success, detectedPortBlocking) {
                ComputerManager.computerAddCompleted.disconnect(handler)
                busy.close()
                if (!success) {
                    var text = qsTr("Unable to connect to %1.").arg(address)
                    if (detectedPortBlocking) {
                        text += "\n\n" + qsTr("This network seems to block Moonlight. Streaming over the Internet may not work here.")
                    }
                    window.showMessage(qsTr("Couldn't add PC"), text)
                }
            }
            ComputerManager.computerAddCompleted.connect(handler)
            ComputerManager.addNewHostManually(address)
        }, "192.168.1.10")
    }

    function openHostMenu(index) {
        var h = hostRepeater.itemAt(index)
        var items = []
        if (!h.online && h.wakeable) {
            items.push({ "text": qsTr("Wake PC"), "action": function() { wakeHost(index) } })
        }
        if (h.online && !h.paired) {
            items.push({ "text": qsTr("Pair"), "action": function() { pairHost(index) } })
        }
        items.push({ "text": qsTr("Rename"), "action": function() {
            window.showKeyboard(qsTr("Rename PC"), h.name, function(newName) {
                newName = newName.trim()
                if (newName !== "") {
                    computerModel.renameComputer(index, newName)
                }
            })
        }})
        items.push({ "text": qsTr("Delete"), "destructive": true, "action": function() {
            window.showConfirm(qsTr("Delete %1?").arg(h.name),
                               qsTr("You will have to pair again to stream from this PC."),
                               qsTr("Delete"),
                               function() {
                                   computerModel.deleteComputer(index)
                                   hostIndex = 0
                                   tabIndex = 0
                               }, true)
        }})
        window.showMenu(h.name, items)
    }

    // Primary action for a host that isn't ready to show games
    function hostPrimaryAction() {
        switch (hostState) {
        case "none": addHost(); break
        case "offline": if (host.wakeable) wakeHost(hostIndex); break
        case "unpaired": pairHost(hostIndex); break
        }
    }

    // ---- App actions ----------------------------------------------------

    // profile: from StreamProfiles.choose(); applied only for this stream
    function startStream(index, isResume, profile) {
        var app = appList.itemAtIndex(index)
        profiles.apply(profile)
        stack.push(streamComponent, {
            "appName": app.name,
            "session": appModel.createSessionForApp(index),
            "isResume": isResume
        })
    }

    function quitRunningApp(thenFn) {
        var busy = window.showBusy(qsTr("Quitting %1").arg(appModel.getRunningAppName()))
        var handler = function(error) {
            ComputerManager.quitAppCompleted.disconnect(handler)
            busy.close()
            if (error !== undefined) {
                window.showMessage(qsTr("Couldn't quit the game"), error)
            }
            else if (typeof thenFn === "function") {
                thenFn()
            }
        }
        ComputerManager.quitAppCompleted.connect(handler)
        appModel.quitRunningApp()
    }

    function launchApp(index) {
        var app = appList.itemAtIndex(index)
        if (app === null) {
            return
        }

        var appName = app.name
        var appId = app.appid

        // Pick resolution/frame rate first, then deal with a running game
        profiles.choose(appName, function(profile) {
            var runningId = appModel.getRunningAppId()
            if (runningId !== 0 && runningId !== appId) {
                window.showConfirm(qsTr("Switch games?"),
                                   qsTr("%1 is still running. Quit it and start %2?").arg(appModel.getRunningAppName()).arg(appName),
                                   qsTr("Quit and start"),
                                   function() { quitRunningApp(function() { startStream(index, false, profile) }) },
                                   true)
                return
            }

            startStream(index, runningId === appId, profile)
        })
    }

    function openAppMenu(index) {
        var app = appList.itemAtIndex(index)
        if (app === null) {
            return
        }

        var items = [{ "text": app.running ? qsTr("Resume") : qsTr("Start"),
                       "action": function() { launchApp(index) } }]
        if (app.running) {
            items.push({ "text": qsTr("Quit game"), "destructive": true,
                         "action": function() { quitRunningApp(null) } })
        }
        items.push({ "text": qsTr("Hide game"), "action": function() { appModel.setAppHidden(index, true) } })
        window.showMenu(app.name, items)
    }

    Component {
        id: streamComponent
        StreamView {}
    }

    Component {
        id: settingsComponent
        BpSettingsView {}
    }

    function openSettings() {
        stack.push(settingsComponent)
    }

    // ---- Input ----------------------------------------------------------

    function bpAction(action, isRepeat) {
        // Global shortcuts on the home screen
        switch (action) {
        case BpInput.PrevTab:
            selectHost(hostIndex - 1)
            return true
        case BpInput.NextTab:
            selectHost(hostIndex + 1)
            return true
        case BpInput.Menu:
            if (!isRepeat) openSettings()
            return true
        }

        if (zone === "tabs") {
            switch (action) {
            case BpInput.Left:
                if (tabIndex > 0) {
                    tabIndex--
                    window.focusMoved()
                }
                return true
            case BpInput.Right:
                if (tabIndex < settingsTabIndex) {
                    tabIndex++
                    window.focusMoved()
                }
                return true
            case BpInput.Down:
                if (tabIndex < hostCount) {
                    hostIndex = tabIndex
                }
                zone = "apps"
                window.focusMoved()
                return true
            case BpInput.Accept:
                if (isRepeat) return true
                if (tabIndex === addTabIndex) addHost()
                else if (tabIndex === settingsTabIndex) openSettings()
                else { hostIndex = tabIndex; zone = "apps" }
                return true
            case BpInput.Option:
                if (!isRepeat && tabIndex < hostCount) openHostMenu(tabIndex)
                return true
            case BpInput.Back:
                if (!isRepeat) zone = "apps"
                return true
            }
            return false
        }

        // zone === "apps"
        switch (action) {
        case BpInput.Up:
            zone = "tabs"
            tabIndex = hostCount > 0 ? hostIndex : addTabIndex
            window.focusMoved()
            return true
        case BpInput.Left:
            if (hostState === "ready" && appList.currentIndex > 0) {
                appList.currentIndex--
                window.focusMoved()
            }
            return true
        case BpInput.Right:
            if (hostState === "ready" && appList.currentIndex < appList.count - 1) {
                appList.currentIndex++
                window.focusMoved()
            }
            return true
        case BpInput.PageUp:
            if (hostState === "ready") appList.currentIndex = Math.max(0, appList.currentIndex - 6)
            return true
        case BpInput.PageDown:
            if (hostState === "ready") appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 6)
            return true
        case BpInput.Accept:
            if (isRepeat) return true
            if (hostState === "ready") launchApp(appList.currentIndex)
            else hostPrimaryAction()
            return true
        case BpInput.Option:
            if (isRepeat) return true
            if (hostState === "ready") openAppMenu(appList.currentIndex)
            else if (hostCount > 0) openHostMenu(hostIndex)
            return true
        case BpInput.View:
            if (!isRepeat && hostCount > 0) openHostMenu(hostIndex)
            return true
        case BpInput.Back:
            if (!isRepeat) {
                window.showConfirm(qsTr("Exit Moonlight?"), "", qsTr("Exit"), function() { Qt.quit() })
            }
            return true
        }
        return false
    }

    // ---- Top bar ----------------------------------------------------------

    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        anchors.topMargin: Theme.px(40)
        height: Theme.px(72)

        Row {
            id: tabs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(14)

            Repeater {
                id: hostRepeater
                model: home.computerModel
                onItemAdded: home.hostRevision++
                onItemRemoved: {
                    home.hostRevision++
                    if (home.hostIndex >= count) {
                        home.hostIndex = Math.max(0, count - 1)
                    }
                }

                HostTab {
                    // Exposed for home.host
                    readonly property string name: model.name
                    readonly property bool online: model.online
                    readonly property bool paired: model.paired
                    readonly property bool busy: model.busy
                    readonly property bool wakeable: model.wakeable
                    readonly property bool statusUnknown: model.statusUnknown
                    readonly property bool serverSupported: model.serverSupported

                    label: model.name
                    statusColor: model.statusUnknown ? Theme.textMuted
                                                     : (!model.online ? Theme.danger
                                                                      : (!model.paired ? Theme.warning : Theme.success))
                    selected: index === home.hostIndex
                    focused: home.zone === "tabs" && home.tabIndex === index
                    onClicked: { home.zone = "apps"; home.hostIndex = index; home.tabIndex = index }
                }
            }

            HostTab {
                label: "+"
                tooltip: qsTr("Add PC")
                focused: home.zone === "tabs" && home.tabIndex === home.addTabIndex
                onClicked: home.addHost()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(28)

            HostTab {
                anchors.verticalCenter: parent.verticalCenter
                icon: "qrc:/res/settings.svg"
                focused: home.zone === "tabs" && home.tabIndex === home.settingsTabIndex
                onClicked: home.openSettings()
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: BpInput.gamepadCount > 0
                source: "qrc:/res/ic_videogame_asset_white_48px.svg"
                width: Theme.px(36)
                height: width
                sourceSize.width: width
                sourceSize.height: height
                opacity: 0.8
            }

            Text {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeading
                text: Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat))

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: clock.text = Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat))
                }
            }
        }
    }

    // ---- Game shelf -------------------------------------------------------

    Column {
        id: titleBlock
        visible: home.hostState === "ready"
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.bottom: appList.top
        anchors.bottomMargin: Theme.px(56)
        spacing: Theme.px(8)

        Text {
            width: parent.width
            text: home.focusedApp ? home.focusedApp.name : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHero
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            text: home.focusedApp && home.focusedApp.running ? qsTr("Running on %1").arg(home.host ? home.host.name : "")
                                                             : (home.host ? home.host.name : "")
            color: home.focusedApp && home.focusedApp.running ? Theme.success : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
        }
    }

    ListView {
        id: appList

        visible: home.hostState === "ready"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.px(64)
        height: Theme.tileHeight * Theme.tileFocusScale + Theme.px(24)

        orientation: ListView.Horizontal
        spacing: Theme.px(28)
        model: home.appModel
        keyNavigationEnabled: false
        clip: false
        cacheBuffer: Theme.tileWidth * 4

        // Keep the focused tile anchored at the left margin, console-style
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: Theme.margin
        preferredHighlightEnd: Theme.margin + Theme.tileWidth
        highlightMoveDuration: Theme.animNormal
        highlightMoveVelocity: -1

        delegate: AppTile {
            // Exposed for home.focusedApp / launch
            readonly property int appid: model.appid

            y: appList.height - height - Theme.px(4)
            name: model.name
            boxart: model.boxart
            running: model.running
            focused: home.zone === "apps" && ListView.isCurrentItem
            onClicked: {
                appList.currentIndex = index
                home.zone = "apps"
                home.launchApp(index)
            }
        }
    }

    // ---- Host not ready ---------------------------------------------------

    Column {
        visible: home.hostState !== "ready"
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - Theme.margin * 2, Theme.px(1100))
        spacing: Theme.px(24)

        Text {
            width: parent.width
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHero
            font.bold: true
            wrapMode: Text.Wrap
            text: {
                var name = home.host ? home.host.name : ""
                switch (home.hostState) {
                case "none": return StreamingPreferences.enableMdns ? qsTr("Looking for PCs…") : qsTr("No PCs yet")
                case "connecting": return qsTr("Connecting to %1…").arg(name)
                case "offline": return qsTr("%1 is offline").arg(name)
                case "unsupported": return qsTr("%1 isn't supported").arg(name)
                case "unpaired": return qsTr("Pair %1").arg(name)
                case "loading": return qsTr("Loading games…")
                }
                return ""
            }
        }

        Text {
            width: parent.width
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            wrapMode: Text.Wrap
            text: {
                switch (home.hostState) {
                case "none": return qsTr("Make sure Sunshine is running on your PC and both devices are on the same network, or add the PC by its IP address.")
                case "offline": return home.host && home.host.wakeable ? qsTr("Send a Wake-on-LAN packet to turn it on.")
                                                                       : qsTr("Turn the PC on and make sure Sunshine is running.")
                case "unsupported": return qsTr("The host software on this PC is not supported by this version of Moonlight.")
                case "unpaired": return qsTr("This PC needs to be paired once before you can stream from it.")
                }
                return ""
            }
        }

        BusyDots {
            visible: home.hostState === "connecting" || home.hostState === "loading" ||
                     (home.hostState === "none" && StreamingPreferences.enableMdns)
        }

        BpButton {
            readonly property string label: {
                switch (home.hostState) {
                case "none": return qsTr("Add PC manually")
                case "offline": return home.host && home.host.wakeable ? qsTr("Wake PC") : ""
                case "unpaired": return qsTr("Pair now")
                }
                return ""
            }
            visible: label !== ""
            text: label
            focused: home.zone === "apps"
            onClicked: home.hostPrimaryAction()
        }
    }

    // ---- Footer -----------------------------------------------------------

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        anchors.bottomMargin: Theme.px(36)
        height: Theme.px(48)

        ButtonHintBar {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            hints: {
                var h = []
                if (home.zone === "apps" && home.hostState === "ready") {
                    h.push({ "action": BpInput.Accept,
                             "text": home.focusedApp && home.focusedApp.running ? qsTr("Resume") : qsTr("Start") })
                    h.push({ "action": BpInput.Option, "text": qsTr("Options") })
                }
                else if (home.zone === "tabs") {
                    h.push({ "action": BpInput.Accept, "text": qsTr("Select") })
                    if (home.tabIndex < home.hostCount) {
                        h.push({ "action": BpInput.Option, "text": qsTr("PC options") })
                    }
                }
                if (home.hostCount > 1) {
                    h.push({ "action": BpInput.NextTab, "text": qsTr("Switch PC") })
                }
                h.push({ "action": BpInput.Menu, "text": qsTr("Settings") })
                return h
            }
        }
    }
}
