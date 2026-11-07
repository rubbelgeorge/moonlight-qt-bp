import QtQuick

import "."

// Footer row of button hints, e.g. [A] Starten  [X] Optionen  [B] Zurück
// hints: [{ action: BpInput.Accept, text: qsTr("Start") }, ...]
Row {
    id: bar

    property var hints: []

    spacing: Theme.px(36)

    Repeater {
        model: bar.hints

        Row {
            spacing: Theme.px(12)

            ButtonGlyph {
                action: modelData.action
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
