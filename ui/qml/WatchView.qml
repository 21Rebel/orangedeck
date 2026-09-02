// Beobachtete Wallets -- **ausschliesslich betrachtend**.
//
// Der verbindliche Grundsatz des Projekts (ZIELBILD.md, 01.09.2026): die
// Anwendung bekommt nie etwas in die Hand, mit dem sich Geld bewegen liesse.
// Hier steht deshalb nur ein erweiterter **oeffentlicher** Schluessel; die
// Adressen werden im Daemon aus reiner Punktarithmetik abgeleitet. Es gibt im
// ganzen Programm keine Zeile, die signieren koennte.
//
// Eingetragen wird ueber die Kommandozeile, nicht hier: der Dienst nimmt
// nichts entgegen, er antwortet nur. Ein Schreibweg waere die erste
// Angriffsflaeche.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    // Sieht jemand hin? Sonst wird nicht nachgefragt.
    property bool live: true
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))
    readonly property real uiFont: Math.max(11, Math.min(14, scaleUnit * 0.62))

    // Transaktion oder Adresse im Explorer oeffnen
    signal txPicked(string txid)
    signal addressPicked(string address)

    // In die Zwischenablage -- wie im Explorer ueber ein unsichtbares Textfeld,
    // QtQuick hat dafuer nichts Eigenes.
    TextEdit {
        id: clipboard

        visible: false
    }

    property string copied: ""

    function copyText(t) {
        if (!t)
            return;
        clipboard.text = String(t);
        clipboard.selectAll();
        clipboard.copy();
        root.copied = String(t);
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer

        interval: 1400
        onTriggered: root.copied = ""
    }

    property var wallets: []
    property bool busy: false
    property string error: ""
    property int shown: 0            // welche Wallet, wenn es mehrere gibt
    property string tab: "txs"       // txs | addr
    property bool __pending: false

    readonly property var one: (wallets.length > shown) ? wallets[shown] : null
    readonly property real eur: (feed && feed.price.eur) || 0

    function grp(n) {
        if (n === undefined || n === null || isNaN(n))
            return "–";
        var t = String(Math.round(n)), out = "", c = 0;
        for (var i = t.length - 1; i >= 0; i--) {
            out = t[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function btc(sats) {
        return (sats / 1e8).toFixed(8).replace(".", ",");
    }

    function euro(sats) {
        if (!root.eur)
            return "";
        return "≈ " + root.grp(sats / 1e8 * root.eur) + " €";
    }

    function ago(ts) {
        if (!ts)
            return "unbestätigt";
        var m = Math.floor(Math.max(0, Date.now() / 1000 - ts) / 60);
        if (m < 60)
            return "vor " + m + " Min";
        var h = Math.floor(m / 60);
        if (h < 48)
            return "vor " + h + " Std";
        var t = Math.floor(h / 24);
        return t < 60 ? "vor " + t + " Tagen" : "vor " + Math.floor(t / 30) + " Monaten";
    }

    function kindLabel(k) {
        if (k === "p2wpkh")
            return "SegWit (bc1…, BIP84)";
        if (k === "p2sh-p2wpkh")
            return "SegWit in P2SH (3…, BIP49)";
        if (k === "p2pkh")
            return "Legacy (1…, BIP44)";
        return k || "";
    }

    function refresh() {
        if (!root.feed || root.__pending || !root.live)
            return;
        root.__pending = true;
        root.feed.getJson("/wallets", function (d, err) {
            root.__pending = false;
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.wallets = d.wallets || [];
            root.busy = !!d.busy;
            if (root.shown >= root.wallets.length)
                root.shown = 0;
        });
    }

    onLiveChanged: {
        if (root.live)
            refresh();
    }

    Component.onCompleted: refresh()

    // Fuenf Sekunden reichen: der Daemon tastet alle fuenf Minuten ab und
    // ausserdem nach jedem Blockfund. Haeufiger zu fragen wuerde nichts
    // Neues bringen.
    Timer {
        interval: 5000
        repeat: true
        running: root.live && root.feed !== null
        onTriggered: root.refresh()
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: spalte.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: spalte

            width: flick.width
            spacing: root.uiFont

            // ------------------------------------- noch nichts eingetragen
            Column {
                width: parent.width
                spacing: root.uiFont * 0.6
                visible: root.wallets.length === 0

                Text {
                    text: "Keine Wallet eingetragen"
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Diese Ansicht zeigt Guthaben und Verlauf einer Wallet, ohne "
                          + "sie anzufassen. Dafür genügt der erweiterte öffentliche "
                          + "Schlüssel — xpub, ypub oder zpub. Ein privater Schlüssel "
                          + "wird nicht entgegengenommen und wäre hier auch nutzlos: "
                          + "das Programm kann nicht signieren."
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.95
                }

                Rectangle {
                    width: parent.width
                    height: befehl.height + root.uiFont * 1.4
                    radius: root.uiFont * 0.4
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Column {
                        id: befehl

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.uiFont * 0.8
                        spacing: root.uiFont * 0.3

                        Text {
                            text: "btcfeed --watch-add <zpub…> \"Mein Sparbuch\""
                            color: root.accentColor
                            font.pixelSize: root.uiFont
                            font.family: "monospace"
                        }

                        Text {
                            text: "btcfeed --watch-list       zeigt, was eingetragen ist\n"
                                  + "btcfeed --watch-remove 1  nimmt einen Eintrag heraus\n"
                                  + "systemctl --user restart btcfeed   übernimmt die Änderung"
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                            font.family: "monospace"
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Eingetragen wird bewusst auf der Kommandozeile: der Dienst "
                          + "im Hintergrund antwortet nur, er nimmt nichts entgegen. "
                          + "Der Schlüssel liegt danach in ~/.config/btcfeed/sources.json, "
                          + "für niemanden sonst lesbar."
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }
            }

            // ------------------------------------------------ Wallet-Wahl
            Row {
                spacing: root.uiFont * 0.6
                visible: root.wallets.length > 1

                Repeater {
                    model: root.wallets

                    Rectangle {
                        id: wahl

                        required property var modelData
                        required property int index

                        readonly property bool aktiv: root.shown === wahl.index

                        width: wahlText.width + root.uiFont * 1.4
                        height: wahlText.height + root.uiFont * 0.6
                        radius: height / 2
                        color: wahl.aktiv ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: wahl.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.1)

                        Text {
                            id: wahlText

                            anchors.centerIn: parent
                            text: wahl.modelData.name
                            color: wahl.aktiv ? root.textColor : root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shown = wahl.index
                        }
                    }
                }
            }

            // ---------------------------------------------------- Kopfteil
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null

                Row {
                    spacing: root.uiFont * 0.6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.one.name : ""
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.8
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.kindLabel(root.one.kind) : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy ? "wird abgetastet …" : ""
                        color: root.dimColor
                        font.pixelSize: root.uiFont * 0.85
                    }
                }

                Text {
                    text: root.one ? "₿ " + root.btc(root.one.balance) : ""
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 1.7
                    font.bold: true
                }

                Text {
                    text: root.one ? root.euro(root.one.balance) : ""
                    color: root.dimColor
                    font.pixelSize: root.uiFont
                }

                Text {
                    visible: root.one && root.one.pending !== 0
                    text: root.one
                        ? (root.one.pending > 0 ? "+" : "") + "₿ " + root.btc(root.one.pending)
                          + " noch unbestätigt"
                        : ""
                    color: root.goodColor
                    font.pixelSize: root.uiFont * 0.9
                }

                Text {
                    visible: root.one && root.one.error
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.one ? root.one.error : ""
                    color: root.badColor
                    font.pixelSize: root.uiFont * 0.9
                }
            }

            // ------------------------------------------------- Kennzahlen
            Flow {
                width: parent.width
                spacing: root.uiFont * 1.8
                visible: root.one !== null

                Repeater {
                    model: {
                        var w = root.one;
                        if (!w)
                            return [];
                        return [
                            { "k": "erhalten", "v": "₿ " + root.btc(w.received) },
                            { "k": "ausgegeben", "v": "₿ " + root.btc(w.sent) },
                            { "k": "Transaktionen", "v": root.grp(w.txCount) },
                            { "k": "benutzte Adressen", "v": root.grp(w.used) },
                            { "k": "Fingerabdruck", "v": w.fingerprint || "–" }
                        ];
                    }

                    Column {
                        id: kennzahl

                        required property var modelData

                        spacing: root.uiFont * 0.1

                        Text {
                            text: kennzahl.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.8
                        }

                        Text {
                            text: kennzahl.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 1.1
                        }
                    }
                }
            }

            // ---------------------------------- naechste Empfangsadresse
            Column {
                width: parent.width
                spacing: root.uiFont * 0.2
                visible: root.one !== null && root.one.nextRecv

                Text {
                    text: "Nächste unbenutzte Empfangsadresse"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                }

                Row {
                    spacing: root.uiFont * 0.5

                    Text {
                        id: naechste

                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(spalte.width - root.uiFont * 4, implicitWidth)
                        elide: Text.ElideMiddle
                        text: root.one ? root.one.nextRecv : ""
                        color: root.textColor
                        font.pixelSize: root.uiFont
                        font.family: "monospace"
                    }

                    CopyButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.one ? root.one.nextRecv : ""
                        done: root.copied === (root.one ? root.one.nextRecv : "")
                        size: root.uiFont * 1.05
                        iconColor: root.dimColor
                        hoverColor: root.textColor
                        doneColor: root.goodColor
                        onCopy: function (was) {
                            root.copyText(was);
                        }
                    }
                }
            }

            // ----------------------------------------------------- Umschalter
            Row {
                spacing: root.uiFont * 1.2
                visible: root.one !== null

                Repeater {
                    model: [
                        { "k": "txs", "l": "Transaktionen" },
                        { "k": "addr", "l": "Adressen" }
                    ]

                    Item {
                        id: reiter

                        required property var modelData

                        readonly property bool aktiv: root.tab === reiter.modelData.k

                        width: reiterText.width
                        height: reiterText.height + root.uiFont * 0.5

                        Text {
                            id: reiterText

                            anchors.top: parent.top
                            text: reiter.modelData.l
                            color: reiter.aktiv ? root.textColor : root.dimColor
                            font.pixelSize: root.uiFont
                            font.bold: reiter.aktiv
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: reiter.aktiv ? parent.width : 0
                            height: 2
                            radius: 1
                            color: root.accentColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 140
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = reiter.modelData.k
                        }
                    }
                }
            }

            // ------------------------------------------ Transaktionsliste
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null && root.tab === "txs"

                Repeater {
                    model: root.one ? (root.one.txs || []) : []

                    Rectangle {
                        id: zeile

                        required property var modelData

                        width: parent.width
                        height: root.uiFont * 2.4
                        radius: 4
                        color: zeileMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.07)
                                                       : Qt.rgba(1, 1, 1, 0.03)

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.uiFont * 0.7
                            spacing: root.uiFont

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                elide: Text.ElideMiddle
                                text: zeile.modelData.t
                                color: root.textColor
                                font.pixelSize: root.uiFont * 0.85
                                font.family: "monospace"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                // Das Vorzeichen ist die Aussage: was die
                                // Wallet gewonnen oder verloren hat.
                                text: (zeile.modelData.d > 0 ? "+" : "")
                                      + "₿ " + root.btc(zeile.modelData.d)
                                color: zeile.modelData.d > 0 ? root.goodColor
                                                             : root.textColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 7
                                text: zeile.modelData.ok
                                    ? root.ago(zeile.modelData.ts) : "unbestätigt"
                                color: zeile.modelData.ok ? root.dimColor : root.accentColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: zeile.modelData.h
                                    ? "Block " + root.grp(zeile.modelData.h) : ""
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }
                        }

                        MouseArea {
                            id: zeileMaus

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.txPicked(String(zeile.modelData.t))
                        }
                    }
                }
            }

            // ----------------------------------------------- Adressliste
            Column {
                width: parent.width
                spacing: root.uiFont * 0.25
                visible: root.one !== null && root.tab === "addr"

                Repeater {
                    model: root.one ? (root.one.addresses || []) : []

                    Rectangle {
                        id: adrZeile

                        required property var modelData

                        width: parent.width
                        height: root.uiFont * 2.4
                        radius: 4
                        color: adrMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.07)
                                                     : Qt.rgba(1, 1, 1, 0.03)

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.uiFont * 0.7
                            spacing: root.uiFont

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 4
                                // Wechselgeld gehoert der Wallet selbst -- das
                                // sieht man den Adressen sonst nicht an.
                                text: (adrZeile.modelData.c === 1 ? "Wechsel " : "Empfang ")
                                      + adrZeile.modelData.i
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.8
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 12
                                elide: Text.ElideMiddle
                                text: adrZeile.modelData.a
                                color: root.textColor
                                font.pixelSize: root.uiFont * 0.85
                                font.family: "monospace"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.uiFont * 9
                                text: "₿ " + root.btc(adrZeile.modelData.bal)
                                color: adrZeile.modelData.bal > 0 ? root.textColor
                                                                  : root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: adrZeile.modelData.n + "×"
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.85
                            }
                        }

                        MouseArea {
                            id: adrMaus

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addressPicked(String(adrZeile.modelData.a))
                        }
                    }
                }
            }

            // -------------------------------------------------- Fussnote
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.one !== null
                text: "Nur betrachtend: hier liegt ein öffentlicher Schlüssel, kein "
                      + "privater. Er verlässt das Gerät nicht — die Adressen werden "
                      + "hier abgeleitet und einzeln abgefragt. Was bleibt, ist ein "
                      + "Verkettungsproblem: wer viele Adressen nacheinander von "
                      + "derselben Stelle abfragt, zeigt dem Betreiber, dass sie "
                      + "zusammengehören. Ganz lösen lässt sich das nur mit einem "
                      + "eigenen Knoten."
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.8
            }

            Text {
                width: parent.width
                visible: root.error.length > 0
                text: root.error
                color: root.badColor
                font.pixelSize: root.uiFont * 0.9
            }
        }
    }
}
