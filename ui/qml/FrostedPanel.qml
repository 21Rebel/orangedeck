// Lesbarer Untergrund fuer Textangaben, die sonst im Kachelfeld untergehen --
// besonders im Zoom, wo grosse helle Flaechen direkt hinter der Schrift liegen.
//
// Legt sich hinter ein beliebiges Item (`content`) und uebernimmt dessen Lage
// und Groesse samt Rand. Ist `backdropSource` gesetzt, wird der Bereich
// dahinter abgegriffen und weichgezeichnet; sonst bleibt es bei der
// eingefaerbten Flaeche, die allein schon lesbar macht.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property Item content: null          // was lesbar bleiben soll
    property Item backdropSource: null   // was dahinter weichgezeichnet wird
    property real pad: 8
    property real cornerRadius: 6
    property color tint: "#0b0b12"
    property real tintAlpha: 0.72
    property bool blurred: true
    property real blurStrength: 1.0

    visible: content ? content.visible : false
    x: content ? content.x - pad : 0
    y: content ? content.y - pad : 0
    width: content ? content.width + pad * 2 : 0
    height: content ? content.height + pad * 2 : 0
    clip: true

    readonly property bool blurActive: blurred && backdropSource !== null
                                       && width > 0 && height > 0

    // Nur der Ausschnitt hinter diesem Feld wird abgegriffen, nicht die ganze
    // Flaeche -- sonst kostet jedes Feld einen vollen zusaetzlichen
    // Zeichendurchgang.
    ShaderEffectSource {
        id: shot

        anchors.fill: parent
        visible: false
        // **Nicht** `live: true`. Der Untergrund muss nicht sechzigmal pro
        // Sekunde neu abgegriffen werden -- die Halde selbst zeichnet nur
        // fuenfmal (Timer mit 200 ms in FeedCanvas), und weichgezeichnet faellt
        // ein Unterschied ohnehin kaum auf. Mit `live: true` gemessen: 14,4 %
        // CPU gegen 9,6 % ohne Weichzeichnung.
        live: false
        hideSource: false
        recursive: false
        sourceItem: root.blurActive ? root.backdropSource : null
        sourceRect: root.backdropSource
            ? Qt.rect(root.x - root.backdropSource.x,
                      root.y - root.backdropSource.y,
                      root.width, root.height)
            : Qt.rect(0, 0, 0, 0)
    }

    // Die Form des Feldes als Maske. Ohne sie beschneidet QML nur rechteckig
    // (`clip`), waehrend die eingefaerbte Flaeche darueber abgerundet ist --
    // in den vier Ecken stand dadurch weichgezeichneter Inhalt **ohne**
    // Einfaerbung, was wie ein Fehler aussah und es auch war.
    Item {
        id: maskShape

        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "white"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.blurActive
        source: shot
        blurEnabled: true
        blur: root.blurStrength
        blurMax: 24
        maskEnabled: true
        maskSource: maskShape
        // Harte, aber geglaettete Kante genau auf der Rundung
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.2
    }

    // Nachfuehren im selben Takt wie die Halde.
    Timer {
        interval: 200
        repeat: true
        running: root.blurActive && root.visible
        triggeredOnStart: true
        onTriggered: shot.scheduleUpdate()
    }

    // Lage oder Groesse geaendert -> sofort einmal nachziehen, sonst steht
    // bis zu 200 ms lang der alte Ausschnitt darunter.
    onXChanged: if (blurActive) shot.scheduleUpdate()
    onYChanged: if (blurActive) shot.scheduleUpdate()
    onWidthChanged: if (blurActive) shot.scheduleUpdate()
    onHeightChanged: if (blurActive) shot.scheduleUpdate()

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintAlpha)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
    }
}
