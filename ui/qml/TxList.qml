// Die Transaktionen eines Blocks zum Durchblaettern.
//
// Die Kachelgrafik zeigt den Block auf einen Blick, sagt aber nichts der Reihe
// nach. Hier steht dieselbe Liste als Liste: in der Reihenfolge des Blocks,
// mit Betrag, Groesse, Gebuehrenrate und -- wenn die Farben nach Art stehen --
// der gedeuteten Art.
//
// Die Daten sind schon da: `blocktiles` und `projectedtiles` liefern zu jeder
// Kachel eine Zeile [txid, vsize, fee, value, rate]. Es wird also nichts
// nachgeladen, nur anders dargestellt.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "txtype.js" as TxType

pragma ComponentBehavior: Bound

Column {
    id: root

    // Die aufbereiteten Kacheldaten
    property var block: null
    property string colorMode: "fee"
    property int perPage: 25
    property int page: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13

    signal txPicked(string txid)

    readonly property var alle: (block && block.txs) ? block.txs : []
    readonly property int seiten: Math.max(1, Math.ceil(alle.length / perPage))
    readonly property int step: (block && block.tileStep) || 1
    readonly property string types: (block && block.types) || ""

    // Beim Wechsel des Blocks wieder von vorn
    onBlockChanged: root.page = 0

    spacing: uiFont * 0.3

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

    function seite() {
        var von = root.page * root.perPage;
        var out = [];
        for (var i = von; i < Math.min(von + root.perPage, root.alle.length); i++) {
            var d = root.alle[i];
            out.push({
                "nr": i * root.step,
                "t": d[0],
                "v": d[1],
                "f": d[2],
                "a": d[3],
                "r": d[4],
                "k": i < root.types.length ? (parseInt(root.types.charAt(i), 10) || 0) : -1
            });
        }
        return out;
    }

    // ------------------------------------------------------- Kopfzeile
    Row {
        width: parent.width
        spacing: root.uiFont * 0.8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.grp(root.alle.length) + (root.step > 1 ? " Kacheln" : " Transaktionen")
            color: root.textColor
            font.pixelSize: root.uiFont * 0.95
        }

        // Bei sehr grossen Bloecken ist die Liste ausgeduennt -- das gehoert
        // dazugesagt, sonst zaehlt jemand mit und wundert sich.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.step > 1
            text: "jede " + root.step + ". Transaktion"
            color: root.accentColor
            font.pixelSize: root.uiFont * 0.8
        }

        Item {
            width: root.uiFont
            height: 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Seite " + (root.page + 1) + " von " + root.seiten
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }
    }

    // ------------------------------------------------------------ Liste
    Repeater {
        model: root.seite()

        Rectangle {
            id: zeile

            required property var modelData

            width: root.width
            height: root.uiFont * 2.2
            radius: 4
            color: maus.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: root.uiFont * 0.6
                spacing: root.uiFont * 0.8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 3
                    horizontalAlignment: Text.AlignRight
                    text: "#" + zeile.modelData.nr
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                // Der Farbpunkt zeigt dieselbe Art wie die Kachelgrafik --
                // nur wenn dort auch nach Art gefaerbt wird, sonst waeren es
                // zwei Farblogiken nebeneinander.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.colorMode === "type" && zeile.modelData.k >= 0
                    width: root.uiFont * 0.6
                    height: width
                    radius: 2
                    color: TxType.info(TxType.kindAt(zeile.modelData.k)).color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 10
                    elide: Text.ElideMiddle
                    text: zeile.modelData.t
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.85
                    font.family: "monospace"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 8
                    text: "₿ " + (zeile.modelData.a / 1e8).toFixed(8).replace(".", ",")
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 6
                    text: root.grp(zeile.modelData.v) + " vB"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: zeile.modelData.r > 0
                        ? zeile.modelData.r.toFixed(2).replace(".", ",") + " sat/vB"
                        : "keine Gebühr"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }
            }

            MouseArea {
                id: maus

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.txPicked(String(zeile.modelData.t))
            }
        }
    }

    // ---------------------------------------------------------- Blaettern
    Row {
        spacing: root.uiFont * 0.6
        visible: root.seiten > 1

        Repeater {
            model: [
                { "l": "‹‹ Anfang", "d": -1000000 },
                { "l": "‹ zurück", "d": -1 },
                { "l": "weiter ›", "d": 1 },
                { "l": "Ende ››", "d": 1000000 }
            ]

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool moeglich: {
                    var z = Math.max(0, Math.min(root.seiten - 1, root.page + knopf.modelData.d));
                    return z !== root.page;
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
                        if (knopf.moeglich)
                            root.page = Math.max(0, Math.min(root.seiten - 1,
                                                             root.page + knopf.modelData.d));
                    }
                }
            }
        }
    }
}
