// Die Blockkette rueckwaerts durchblaettern.
//
// Die Leiste auf der Startseite zeigt die letzten Bloecke nebeneinander; hier
// stehen sie untereinander mit allem, was `/v1/blocks` mitliefert, und lassen
// sich Seite fuer Seite zurueckverfolgen. Der Daemon kennt dafuer beide
// Formen: `blocks/recent` fuer die neuesten, `blocks/<hoehe>` fuer die
// fuenfzehn davor.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Column {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13

    signal blockPicked(string hash)

    property var blocks: []
    property string error: ""
    property bool busy: false
    // Von welcher Hoehe an geblaettert wird. 0 heisst: die neuesten.
    property int von: 0

    spacing: uiFont * 0.3

    readonly property int tip: (feed && feed.tipHeight) || 0
    readonly property int oberste: blocks.length ? (blocks[0].height || 0) : 0
    readonly property int unterste: blocks.length
        ? (blocks[blocks.length - 1].height || 0) : 0

    function grp(n) {
        if (n === undefined || n === null)
            return "–";
        var t = String(Math.round(n)), out = "", c = 0;
        for (var i = t.length - 1; i >= 0; i--) {
            out = t[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function ago(ts) {
        if (!ts)
            return "";
        var m = Math.floor(Math.max(0, Date.now() / 1000 - ts) / 60);
        if (m < 60)
            return "vor " + m + " Min";
        var h = Math.floor(m / 60);
        if (h < 48)
            return "vor " + h + " Std";
        return "vor " + Math.floor(h / 24) + " Tagen";
    }

    function laden() {
        if (!root.feed)
            return;
        root.busy = true;
        var wohin = root.von > 0 ? String(root.von) : "recent";
        root.feed.lookup("blocks", wohin, function (d, err) {
            root.busy = false;
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.blocks = d || [];
        });
    }

    onVonChanged: laden()
    Component.onCompleted: laden()

    // ------------------------------------------------------- Kopfzeile
    Row {
        width: parent.width
        spacing: root.uiFont * 0.8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Blockhistorie"
            color: root.textColor
            font.pixelSize: root.uiFont * 1.2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.blocks.length
                ? root.grp(root.unterste) + " bis " + root.grp(root.oberste)
                : (root.busy ? "lädt …" : "")
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.85
        }
    }

    Text {
        width: parent.width
        visible: root.error.length > 0
        text: root.error
        color: "#e06c6c"
        font.pixelSize: root.uiFont * 0.9
    }

    // ----------------------------------------------------------- Liste
    Repeater {
        model: root.blocks

        Rectangle {
            id: zeile

            required property var modelData

            readonly property var ex: zeile.modelData.extras || ({})

            width: root.width
            height: root.uiFont * 2.4
            radius: 4
            color: maus.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: root.uiFont * 0.6
                spacing: root.uiFont * 0.9

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 5
                    text: root.grp(zeile.modelData.height)
                    color: root.accentColor
                    font.pixelSize: root.uiFont * 0.95
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: root.ago(zeile.modelData.timestamp)
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: root.grp(zeile.modelData.tx_count) + " TX"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 4.5
                    text: (zeile.modelData.size / 1024 / 1024).toFixed(2).replace(".", ",") + " MB"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: zeile.ex.medianFee !== undefined
                        ? "~" + (zeile.ex.medianFee >= 10
                            ? Math.round(zeile.ex.medianFee)
                            : zeile.ex.medianFee.toFixed(1).replace(".", ",")) + " sat/vB"
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: zeile.ex.reward
                        ? "₿ " + (zeile.ex.reward / 1e8).toFixed(3).replace(".", ",") : ""
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: (zeile.ex.pool && zeile.ex.pool.name) || ""
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }
            }

            MouseArea {
                id: maus

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.blockPicked(String(zeile.modelData.id))
            }
        }
    }

    // -------------------------------------------------------- Blaettern
    Row {
        spacing: root.uiFont * 0.6
        visible: root.blocks.length > 0

        Repeater {
            model: [
                { "k": "neueste", "l": "‹‹ neueste" },
                { "k": "neuer", "l": "‹ neuer" },
                { "k": "aelter", "l": "älter ›" }
            ]

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool moeglich: {
                    if (knopf.modelData.k === "aelter")
                        return root.unterste > 1;
                    // Ganz oben angekommen? Dann fuehrt "neuer" nirgendwohin.
                    return root.von > 0;
                }

                width: knopfText.width + root.uiFont * 1.2
                height: knopfText.height + root.uiFont * 0.6
                radius: height / 2
                opacity: knopf.moeglich ? 1 : 0.35
                color: knopfMaus.containsMouse && knopf.moeglich
                    ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    id: knopfText

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.85
                }

                MouseArea {
                    id: knopfMaus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: knopf.moeglich ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!knopf.moeglich)
                            return;
                        // Eine Seite sind die fuenfzehn Bloecke, die gerade
                        // dastehen -- gerechnet wird mit den echten Hoehen und
                        // nicht mit einer angenommenen Seitenlaenge.
                        if (knopf.modelData.k === "neueste")
                            root.von = 0;
                        else if (knopf.modelData.k === "aelter")
                            root.von = Math.max(1, root.unterste - 1);
                        else
                            root.von = Math.min(root.tip,
                                                root.oberste + root.blocks.length);
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Die Zeitangabe ist der Zeitstempel des Blocks, nicht die Uhrzeit "
              + "des Fundes — er darf um bis zu zwei Stunden abweichen und muss "
              + "nur über dem Mittel der elf vorherigen Blöcke liegen."
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.75
    }
}
