import QtQuick
import QtQuick.Controls

import BpInput 1.0
import Session 1.0
import SystemProperties 1.0
import "."

// Launch screen shown while a stream starts, and while the app quits
// afterwards. Mirrors the session handling of gui/StreamSegue.qml.
FocusScope {
    id: streamView

    property Session session
    property string appName
    property bool isResume: false

    property string stageText: isResume ? qsTr("Resuming %1").arg(appName) : qsTr("Starting %1").arg(appName)
    property string errorText: ""
    property var warnings: []

    // Swallow all input while launching
    function bpAction(action, isRepeat) {
        return true
    }

    function stageStarting(stage) {
        stageText = qsTr("Starting %1…").arg(stage)
    }

    function stageFailed(stage, errorCode, failingPorts) {
        errorText = qsTr("Starting %1 failed: Error %2").arg(stage).arg(errorCode)
        if (failingPorts) {
            errorText += "\n\n" + qsTr("Check your firewall and port forwarding rules for port(s): %1").arg(failingPorts)
        }
    }

    function connectionStarted() {
        content.visible = false
        window.visible = false
    }

    function displayLaunchError(text) {
        errorText = text
        console.error(text)
    }

    function quitStarting() {
        // quitAppAfter is enabled: show progress while the host closes the game
        stageText = qsTr("Quitting %1…").arg(appName)
        content.visible = true
        window.visible = true
    }

    function sessionFinished(portTestResult) {
        if (portTestResult !== 0 && portTestResult !== -1 && errorText) {
            errorText += "\n\n" + qsTr("This network seems to block Moonlight. Streaming over the Internet may not work here.")
        }

        // Hand the gamepad back to the UI
        BpInput.enable()

        // Put back the user's settings if a stream profile was applied
        profiles.restore()

        stack.pop()
        window.visible = true

        // Show errors only once the UI is visible so the dialog gets focus
        if (errorText) {
            window.showMessage(qsTr("Stream ended with an error"), errorText)
        }
    }

    function sessionReadyForDeletion() {
        session = null
        gc()
    }

    StackView.onActivated: {
        session.stageStarting.connect(stageStarting)
        session.stageFailed.connect(stageFailed)
        session.connectionStarted.connect(connectionStarted)
        session.displayLaunchError.connect(displayLaunchError)
        session.quitStarting.connect(quitStarting)
        session.sessionFinished.connect(sessionFinished)
        session.readyForDeletion.connect(sessionReadyForDeletion)

        // The async SystemProperties probe may be using SDL video right now
        SystemProperties.waitForAsyncLoad()

        streamLoader.active = true
    }

    StackView.onDeactivating: {
        BpInput.enable()
        profiles.restore()
    }

    Timer {
        id: startSessionTimer
        onTriggered: {
            gc()
            session.start()
        }
    }

    Loader {
        id: streamLoader
        active: false
        asynchronous: true
        sourceComponent: Item {}

        onLoaded: {
            // The Session owns the SDL gamecontroller subsystem from here on
            BpInput.disable()

            if (!session.initialize(window)) {
                sessionFinished(0)
                sessionReadyForDeletion()
                return
            }

            spinner.visible = true

            // Show launch warnings for a moment before starting
            streamView.warnings = session.launchWarnings
            startSessionTimer.interval = streamView.warnings.length > 0 ? 3500 : 0
            for (var i = 0; i < streamView.warnings.length; i++) {
                console.warn(streamView.warnings[i])
            }
            startSessionTimer.start()
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Theme.margin * 2
        spacing: Theme.px(28)

        Text {
            width: parent.width
            text: streamView.appName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHero
            font.bold: true
            elide: Text.ElideRight
        }

        Row {
            spacing: Theme.px(24)

            BusyDots {
                id: spinner
                visible: false
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: streamView.stageText
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
            }
        }

        Repeater {
            model: streamView.warnings

            Text {
                width: content.width
                text: "⚠  " + modelData
                color: Theme.warning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(64)
        spacing: Theme.px(14)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Press %1 to end the stream").arg(BpInput.gamepadCount > 0 ? "Start + Select + L1 + R1" : "Ctrl + Alt + Shift + Q")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }
}
