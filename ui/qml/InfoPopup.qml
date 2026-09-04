// Ein kleiner "i"-Knopf mit Erklaerungen dahinter. Die Angaben stehen damit
// an einem Ort, statt die Flaeche zuzustellen.
//
// Wird ueber die ganze Ansicht gelegt (`anchors.fill: parent`), faengt aber
// nur dort Eingaben ab, wo der Knopf sitzt -- und, solange offen, ueberall,
// damit ein Klick daneben wieder schliesst.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"

    // Je Eintrag: { k: Ueberschrift, v: Text, color: optionale Farbe fuer den
    // Strich davor, thin: duenner Strich statt kraeftigem }
    property var entries: []
    property string title: Tr.t("legend", root.lang)
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color panelColor: "#12121b"
    property real fontSize: 12
    property bool open: false
    // Wo der Knopf sitzt
    property real buttonMargin: 0
    property real buttonRightInset: 0
    // Der eigene Knopf laesst sich abschalten, wenn der Wirt schon eine
    // Knopfleiste hat (im Dashboard die von DMS). `open` wird dann von aussen
    // gesetzt.
    property bool showButton: true
    // Damit sich weitere Knoepfe daneben anordnen lassen. **Nicht** per Anker
    // an `button` haengen -- der ist ein Kind dieses Items und damit fuer
    // Geschwister nicht ankerbar ("Cannot anchor to an item that isn't a
    // parent or sibling"). Ueber die Breite geht es.
    readonly property real buttonWidth: button.width

    // Klick daneben schliesst wieder
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.open = false
    }

    Rectangle {
        id: button

        visible: root.showButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.buttonMargin
        anchors.rightMargin: root.buttonMargin + root.buttonRightInset
        width: root.fontSize * 1.9
        height: width
        radius: width / 2
        color: root.open || hover.containsMouse ? Qt.rgba(1, 1, 1, 0.16)
                                                : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 40

        Text {
            anchors.centerIn: parent
            text: "i"
            color: root.textColor
            font.pixelSize: root.fontSize
            font.bold: true
            font.family: Fonts.serif()
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Rectangle {
        id: panel

        anchors.top: button.bottom
        anchors.right: button.right
        anchors.topMargin: root.fontSize * 0.5
        width: Math.min(root.width * 0.92, root.fontSize * 30)
        height: col.implicitHeight + root.fontSize * 1.6
        radius: root.fontSize * 0.5
        color: Qt.rgba(root.panelColor.r, root.panelColor.g, root.panelColor.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        visible: opacity > 0.01
        opacity: root.open ? 1 : 0
        z: 45

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        // Klicks im Feld sollen es nicht schliessen
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.fontSize * 0.8
            spacing: root.fontSize * 0.55

            Text {
                text: root.title
                color: root.dimColor
                font.pixelSize: root.fontSize * 0.85
                font.bold: true
            }

            Repeater {
                model: root.entries

                Row {
                    id: line

                    required property var modelData

                    width: col.width
                    spacing: root.fontSize * 0.6

                    // Farbstrich als Zuordnung zur Kurve
                    Item {
                        width: root.fontSize * 1.6
                        height: root.fontSize * 1.2

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: line.modelData.thin ? Math.max(1, root.fontSize * 0.1)
                                                        : Math.max(2, root.fontSize * 0.2)
                            radius: height / 2
                            visible: line.modelData.color !== undefined
                            color: line.modelData.color !== undefined
                                ? line.modelData.color : "transparent"
                            opacity: line.modelData.thin ? 0.5 : 1
                        }
                    }

                    Column {
                        width: col.width - root.fontSize * 2.2
                        spacing: root.fontSize * 0.1

                        Text {
                            text: line.modelData.k
                            color: root.textColor
                            font.pixelSize: root.fontSize * 0.85
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: line.modelData.v
                            color: root.dimColor
                            font.pixelSize: root.fontSize * 0.8
                        }
                    }
                }
            }
        }
    }
}
