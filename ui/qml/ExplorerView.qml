// Explorer: suchen, Einzelheiten ansehen, dem Weg des Geldes folgen.
//
// Die Eingabeerkennung steckt in `search.js` (portiert aus dem Fork). Alle
// Abfragen laufen ueber den Daemon -- er weiss, ob die Daten von
// mempool.space oder von einem eigenen Node kommen.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "search.js" as Search

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 34, height / 20))
    // Die Suchleiste soll nicht mitwachsen -- in einem grossen Fenster wird
    // sie sonst albern gross. Der Inhalt darunter darf skalieren, die
    // Bedienelemente nicht.
    readonly property real uiFont: Math.min(scaleUnit * 0.78, 15)

    // --- Zustand ---------------------------------------------------------
    property string kind: ""          // tx | block | address
    // **Nicht** `data` nennen: das ist in QML die Standard-Eigenschaft, in der
    // die Kindelemente liegen. Sie zu ueberschreiben bringt den Baum durcheinander.
    property var result: null         // Antwort der Hauptabfrage
    property var extra: null          // outspends bzw. Adresstransaktionen
    property var tiles: null          // Kacheldaten des Blocks
    property bool tilesBusy: false
    property string status: ""        // Meldung statt Ergebnis
    property bool busy: false
    property var trail: []            // Weg dorthin, fuer den Zurueck-Knopf

    // In die Zwischenablage. QtQuick hat dafuer keine eigene Schnittstelle --
    // der uebliche Weg ist ein unsichtbares Textfeld, das man auswaehlt und
    // kopieren laesst.
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

    function btc(sats) {
        if (sats === undefined || sats === null)
            return "–";
        return "₿ " + (sats / 1e8).toFixed(8).replace(".", ",");
    }

    function shortId(id, n) {
        if (!id)
            return "";
        var k = n || 10;
        return id.length > 2 * k ? id.slice(0, k) + "…" + id.slice(-k) : id;
    }

    function ago(ts) {
        if (!ts)
            return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        if (s < 90)
            return "gerade eben";
        var m = Math.floor(s / 60);
        if (m < 90)
            return "vor " + m + " Min";
        var h = Math.floor(m / 60);
        if (h < 48)
            return "vor " + h + " Std";
        return "vor " + Math.floor(h / 24) + " Tagen";
    }

    // --- Abfragen --------------------------------------------------------
    function go(kind, arg, remember) {
        if (!root.feed)
            return;
        if (remember !== false && root.kind && root.result)
            root.trail = root.trail.concat([{ "kind": root.kind, "arg": root.currentArg }]);
        root.busy = true;
        root.status = "";
        root.extra = null;
        root.tiles = null;

        if (kind === "blockheight") {
            // Zuerst die Hoehe in einen Hash aufloesen -- die Antwort ist
            // reiner Text, kein JSON.
            root.feed.lookup("blockheight", arg, function (d, err) {
                root.busy = false;
                if (err) {
                    root.fail(err);
                    return;
                }
                root.go("blockhash", String(d), false);
            });
            return;
        }

        // Fuer Bloecke die ausfuehrliche Form: sie bringt Pool, Belohnung,
        // Gebuehrenspanne, UTXO-Aenderung und SegWit-Anteil mit.
        var route = kind === "tx" ? "tx" : (kind === "blockhash" ? "blockinfo" : "address");
        root.currentArg = arg;
        root.feed.lookup(route, arg, function (d, err) {
            root.busy = false;
            if (err) {
                root.fail(err);
                return;
            }
            root.kind = kind === "blockhash" ? "block" : (kind === "tx" ? "tx" : "address");
            root.result = d;
            root.status = "";
            // Nachladen, was den Weg weitererzaehlt
            if (root.kind === "tx")
                root.feed.lookup("outspends", arg, function (o) {
                    root.extra = o;
                });
            else if (root.kind === "address")
                root.feed.lookup("addresstxs", arg, function (o) {
                    root.extra = o;
                });
            else if (root.kind === "block") {
                // Die Kacheldaten kommen getrennt -- sie sind gross und der
                // Daemon bereitet sie erst auf.
                root.tiles = null;
                root.tilesBusy = true;
                root.feed.lookup("blocktiles", arg, function (t) {
                    root.tilesBusy = false;
                    root.tiles = t;
                });
            }
        });
    }

    property string currentArg: ""

    function fail(msg) {
        root.kind = "";
        root.result = null;
        root.status = msg;
    }

    function submit(text) {
        var m = Search.matchQuery(text);
        if (!m) {
            root.fail("Keine gültige Eingabe.");
            return;
        }
        if (m.kind === "xpub") {
            root.fail("Erweiterte Schlüssel gehören in die Wallet-Ansicht — sie kommen später.");
            return;
        }
        var k = m.kind === "input" || m.kind === "output" ? "tx" : m.kind;
        root.go(k, m.arg);
    }

    // Zurueck zur Startseite. Ohne ihn kam man aus einer Transaktion nur
    // ueber wiederholtes Zurueckgehen wieder heraus.
    function home() {
        root.trail = [];
        root.kind = "";
        root.result = null;
        root.extra = null;
        root.tiles = null;
        root.status = "";
        root.currentArg = "";
    }

    function back() {
        if (!trail.length)
            return;
        var last = trail[trail.length - 1];
        root.trail = trail.slice(0, -1);
        root.go(last.kind === "block" ? "blockhash" : last.kind, last.arg, false);
    }

    // ------------------------------------------------------------ Suchfeld
    Item {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: field.height + root.uiFont * 1.3

        Rectangle {
            id: homeBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: root.uiFont * 2.2
            height: width
            radius: width / 2
            visible: root.kind !== "" || root.status.length > 0
            color: homeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            // Haus, gezeichnet -- wie beim Zurueck-Pfeil aus demselben Grund:
            // Schriftzeichen sitzen nicht zuverlaessig mittig.
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: width

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = root.textColor;
                    ctx.lineWidth = Math.max(1.4, width * 0.14);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(width * 0.08, height * 0.46);
                    ctx.lineTo(width * 0.5, height * 0.1);
                    ctx.lineTo(width * 0.92, height * 0.46);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(width * 0.2, height * 0.44);
                    ctx.lineTo(width * 0.2, height * 0.9);
                    ctx.lineTo(width * 0.8, height * 0.9);
                    ctx.lineTo(width * 0.8, height * 0.44);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: homeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.home()
            }
        }

        Rectangle {
            id: backBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: homeBtn.visible ? homeBtn.right : parent.left
            anchors.leftMargin: homeBtn.visible ? root.uiFont * 0.4 : 0
            width: root.uiFont * 2.2
            height: width
            radius: width / 2
            visible: root.trail.length > 0
            color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            // Gezeichnet statt gesetzt: das Zeichen "‹" bringt je nach Schrift
            // eine eigene Seiten- und Grundlinienlage mit und sitzt dann nicht
            // mittig. Zwei Striche sind immer da, wo sie sein sollen.
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = root.textColor;
                    ctx.lineWidth = Math.max(1.5, width * 0.16);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(width * 0.68, height * 0.12);
                    ctx.lineTo(width * 0.28, height * 0.5);
                    ctx.lineTo(width * 0.68, height * 0.88);
                    ctx.stroke();
                }
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backBtn.visible ? backBtn.right
                                          : (homeBtn.visible ? homeBtn.right : parent.left)
            anchors.leftMargin: (backBtn.visible || homeBtn.visible) ? root.uiFont * 0.5 : 0
            anchors.right: parent.right
            height: field.height + root.uiFont * 0.8
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: field.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: hintLabel.left
                anchors.leftMargin: root.uiFont
                anchors.rightMargin: root.uiFont * 0.6
                anchors.verticalCenter: parent.verticalCenter
                color: root.textColor
                font.pixelSize: root.uiFont
                font.family: "monospace"
                selectByMouse: true
                clip: true
                onAccepted: root.submit(text)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "Blockhöhe, Blockhash, TxID oder Adresse …"
                    color: root.dimColor
                    font.pixelSize: root.uiFont
                }
            }

            Text {
                id: hintLabel

                anchors.right: parent.right
                anchors.rightMargin: root.uiFont
                anchors.verticalCenter: parent.verticalCenter
                // Bei leerem Feld stuende hier dasselbe wie im Platzhalter --
                // also nichts.
                text: root.busy ? "sucht …"
                                : (field.text.length ? Search.hintFor(field.text) : "")
                color: root.busy ? root.accentColor : root.dimColor
                font.pixelSize: root.uiFont * 0.82
            }
        }
    }

    // ----------------------------------------------------------- Ergebnis
    Flickable {
        id: flick

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: root.scaleUnit * 0.5
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds

        // Schmaler Balken rechts, nur solange es etwas zu rollen gibt.
        // Grosse Flussgrafiken machen den Inhalt schnell laenger als das
        // Fenster -- dann muss man auch sehen, dass es weitergeht.
        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.uiFont * 0.2)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

            width: flick.width
            spacing: root.scaleUnit * 0.5

            // ------------------------------------------------ Meldung
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.status.length > 0
                text: root.status
                color: root.badColor
                font.pixelSize: root.scaleUnit * 0.75
            }

            ExplorerHome {
                width: parent.width
                visible: root.kind === "" && root.status.length === 0
                feed: root.feed
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                uiFont: root.uiFont
                onBlockPicked: function (hash) {
                    root.go("blockhash", hash);
                }
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
            }

            // ------------------------------------------- Transaktion
            Loader {
                width: parent.width
                active: root.kind === "tx" && root.result !== null
                sourceComponent: txDetail
            }

            Loader {
                width: parent.width
                active: root.kind === "block" && root.result !== null
                sourceComponent: blockDetail
            }

            Loader {
                width: parent.width
                active: root.kind === "address" && root.result !== null
                sourceComponent: addressDetail
            }
        }
    }

    // ===================================================== Transaktion
    Component {
        id: txDetail

        Column {
            id: txBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result
            readonly property bool confirmed: d.status && d.status.confirmed

            Text {
                text: "Transaktion"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: txidLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    text: root.result.txid
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 0.8
                    font.family: "monospace"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.txid)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: txidLabel.verticalCenter
                    text: root.result.txid
                    done: root.copied === root.result.txid
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": "Status", "v": txBox.confirmed
                            ? "in Block " + root.grp(root.result.status.block_height) : "im Mempool" },
                        { "k": "Größe", "v": root.grp(root.result.size) + " Byte" },
                        { "k": "Gewicht", "v": root.grp(root.result.weight) + " WU" },
                        { "k": "Gebühr", "v": root.grp(root.result.fee) + " sat" },
                        { "k": "Rate", "v": root.result.weight
                            ? (root.result.fee / (root.result.weight / 4)).toFixed(2).replace(".", ",") + " sat/vB" : "–" }
                    ]

                    Column {
                        id: sc

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: sc.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: sc.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            // ------------------------------------------------ Einzelheiten
            Grid {
                columns: 2
                columnSpacing: root.scaleUnit * 2
                rowSpacing: root.scaleUnit * 0.2

                Repeater {
                    model: [
                        { "k": "Virtuelle Größe", "v": root.result.weight
                            ? (root.result.weight / 4 / 1000).toFixed(2).replace(".", ",") + " kvB" : "–" },
                        { "k": "Version", "v": String(root.result.version !== undefined ? root.result.version : "–") },
                        { "k": "Gewicht", "v": root.result.weight
                            ? (root.result.weight / 1000).toFixed(2).replace(".", ",") + " kWU" : "–" },
                        { "k": "Sperrzeit", "v": String(root.result.locktime !== undefined ? root.result.locktime : "–") },
                        { "k": "Größe", "v": root.result.size
                            ? (root.result.size / 1000).toFixed(2).replace(".", ",") + " kB" : "–" },
                        { "k": "Sigops", "v": String(root.result.sigops !== undefined ? root.result.sigops : "–") }
                    ]

                    Row {
                        id: dRow

                        required property var modelData

                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 7
                            text: dRow.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        Text {
                            text: dRow.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.9
                        }
                    }
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // Der Fluss: Betraege als Baender, links hinein, rechts hinaus
            Text {
                text: "Fluss"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.6
            }

            TxFlow {
                width: flick.width
                // Die Rundung lebt vom Verhaeltnis senkrecht zu waagerecht.
                // Das Original zeichnet 1200 x 600; hier ist die Flaeche viel
                // flacher, deshalb bekommt sie mit jedem Band mehr Hoehe --
                // der Strang bleibt gleich dick, so ziehen sich die Luecken auf.
                //
                // Gezaehlt werden die tatsaechlichen **Baender**: auf der
                // Ausgangsseite zaehlt die Gebuehr mit, sonst wird es dort zu
                // eng. Der Deckel liegt hoch; wird die Flaeche laenger als das
                // Fenster, rollt der Explorer ohnehin.
                readonly property int bandCount: Math.max((root.result.vin || []).length,
                                                          (root.result.vout || []).length
                                                          + ((root.result.fee || 0) > 0 ? 1 : 0))
                height: Math.max(root.scaleUnit * 9, Math.min(root.scaleUnit * 48,
                        root.scaleUnit * 1.5 * bandCount + root.scaleUnit * 5))
                vin: root.result.vin || []
                vout: root.result.vout || []
                fee: root.result.fee || 0
                outColor: root.accentColor
                textColor: root.textColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.62

                onActivated: function (side, index) {
                    if (side === "in") {
                        var vi = (root.result.vin || [])[index];
                        if (vi && vi.txid)
                            root.go("tx", vi.txid);
                    } else if (side === "out") {
                        var sp = root.extra && root.extra[index];
                        var vo = (root.result.vout || [])[index];
                        if (sp && sp.spent && sp.txid)
                            root.go("tx", sp.txid);
                        else if (vo && vo.scriptpubkey_address)
                            root.go("address", vo.scriptpubkey_address);
                    }
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // Ein- und Ausgaenge nebeneinander -- der Weg des Geldes
            Row {
                width: flick.width
                spacing: root.scaleUnit

                Column {
                    width: (flick.width - root.scaleUnit * 2) / 2
                    spacing: root.scaleUnit * 0.2

                    Text {
                        text: (root.result.vin || []).length + " Eingänge"
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    Repeater {
                        model: (root.result.vin || []).slice(0, 25)

                        Rectangle {
                            id: vinRow

                            required property var modelData

                            width: parent.width
                            height: vinCol.implicitHeight + root.scaleUnit * 0.4
                            radius: 4
                            color: vinArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                            Column {
                                id: vinCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.scaleUnit * 0.4
                                spacing: 1

                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: vinRow.modelData.prevout
                                        ? (vinRow.modelData.prevout.scriptpubkey_address || "(kein Adressformat)")
                                        : "Coinbase — neu erzeugt"
                                    color: root.textColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                    font.family: "monospace"
                                }

                                Text {
                                    text: vinRow.modelData.prevout
                                        ? root.btc(vinRow.modelData.prevout.value) : ""
                                    color: root.dimColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                }
                            }

                            MouseArea {
                                id: vinArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: vinRow.modelData.txid ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (vinRow.modelData.txid)
                                        root.go("tx", vinRow.modelData.txid);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "→"
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 1.2
                }

                Column {
                    width: (flick.width - root.scaleUnit * 2) / 2
                    spacing: root.scaleUnit * 0.2

                    Text {
                        text: (root.result.vout || []).length + " Ausgänge"
                        color: root.dimColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    Repeater {
                        model: (root.result.vout || []).slice(0, 25)

                        Rectangle {
                            id: voutRow

                            required property var modelData
                            required property int index

                            readonly property var spend: (root.extra && root.extra[voutRow.index]) || null

                            width: parent.width
                            height: voutCol.implicitHeight + root.scaleUnit * 0.4
                            radius: 4
                            color: voutArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                            Column {
                                id: voutCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: root.scaleUnit * 0.4
                                spacing: 1

                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: voutRow.modelData.scriptpubkey_address
                                        || ("(" + (voutRow.modelData.scriptpubkey_type || "unbekannt") + ")")
                                    color: root.textColor
                                    font.pixelSize: root.scaleUnit * 0.6
                                    font.family: "monospace"
                                }

                                Row {
                                    spacing: root.scaleUnit * 0.4

                                    Text {
                                        text: root.btc(voutRow.modelData.value)
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.6
                                    }

                                    Text {
                                        visible: voutRow.spend !== null
                                        text: voutRow.spend && voutRow.spend.spent
                                            ? "ausgegeben ›" : "noch nicht ausgegeben"
                                        color: voutRow.spend && voutRow.spend.spent
                                            ? root.accentColor : root.goodColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }
                                }
                            }

                            MouseArea {
                                id: voutArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Weiter dem Weg folgen: wurde der Ausgang
                                    // ausgegeben, dorthin; sonst zur Adresse.
                                    if (voutRow.spend && voutRow.spend.spent && voutRow.spend.txid)
                                        root.go("tx", voutRow.spend.txid);
                                    else if (voutRow.modelData.scriptpubkey_address)
                                        root.go("address", voutRow.modelData.scriptpubkey_address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================ Block
    Component {
        id: blockDetail

        Column {
            id: blockBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result

            Text {
                text: "Block"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Text {
                text: root.grp(root.result.height)
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 1.8
                font.bold: true
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: hashLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    text: root.result.id
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                    font.family: "monospace"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.id)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: hashLabel.verticalCenter
                    text: root.result.id
                    done: root.copied === root.result.id
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                readonly property var ex: root.result.extras || ({})

                Repeater {
                    model: [
                        { "k": "Zeit", "v": root.ago(root.result.timestamp) },
                        { "k": "Transaktionen", "v": root.grp(root.result.tx_count) },
                        { "k": "Größe", "v": root.grp(Math.round(root.result.size / 1024)) + " kB" },
                        { "k": "Gewicht", "v": root.grp(Math.round(root.result.weight / 1000)) + " kWU" },
                        { "k": "Mining-Pool", "v": ((root.result.extras || {}).pool || {}).name || "–" },
                        { "k": "Belohnung", "v": (root.result.extras || {}).reward
                            ? root.btc((root.result.extras || {}).reward) : "–" }
                    ]

                    Column {
                        id: bc

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: bc.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: bc.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            // Weitere Angaben aus dem Block
            Grid {
                columns: 2
                columnSpacing: root.scaleUnit * 2
                rowSpacing: root.scaleUnit * 0.2

                Repeater {
                    model: {
                        var e = root.result.extras || {};
                        return [
                            { "k": "Gebühren gesamt", "v": e.totalFees ? root.btc(e.totalFees) : "–" },
                            { "k": "Schwierigkeit", "v": root.result.difficulty
                                ? (root.result.difficulty / 1e12).toFixed(2).replace(".", ",") + " T" : "–" },
                            { "k": "mittlere Rate", "v": e.medianFee !== undefined
                                ? e.medianFee.toFixed(2).replace(".", ",") + " sat/vB" : "–" },
                            { "k": "Version", "v": root.result.version !== undefined
                                ? "0x" + Number(root.result.version).toString(16) : "–" },
                            { "k": "Gebührenspanne", "v": (e.feeRange && e.feeRange.length)
                                ? Math.round(e.feeRange[0]) + " – " + Math.round(e.feeRange[e.feeRange.length - 1]) + " sat/vB" : "–" },
                            { "k": "Nonce", "v": root.grp(root.result.nonce) },
                            { "k": "UTXO-Änderung", "v": e.utxoSetChange !== undefined
                                ? (e.utxoSetChange >= 0 ? "+" : "") + root.grp(e.utxoSetChange) : "–" },
                            { "k": "SegWit", "v": (e.segwitTotalTxs && root.result.tx_count)
                                ? Math.round(100 * e.segwitTotalTxs / root.result.tx_count) + " %" : "–" },
                            { "k": "Ø Transaktion", "v": e.avgTxSize !== undefined
                                ? Math.round(e.avgTxSize) + " Byte" : "–" },
                            { "k": "Merkle-Wurzel", "v": root.result.merkle_root
                                ? root.shortId(root.result.merkle_root, 8) : "–" }
                        ];
                    }

                    Row {
                        id: bRow

                        required property var modelData

                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 7
                            text: bRow.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.9
                        }

                        Text {
                            text: bRow.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.9
                        }
                    }
                }
            }

            // Die Kachelgrafik des Blocks -- dieselbe Optik wie im Feed
            Text {
                text: root.tilesBusy ? "Kacheln werden geholt …" : "Transaktionen im Block"
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.9
            }

            BlockTiles {
                width: flick.width
                height: Math.min(flick.width, root.scaleUnit * 34)
                visible: root.tiles !== null
                block: root.tiles
                dimColor: root.dimColor
                labelSize: root.uiFont * 0.85
                onTxPicked: function (txid) {
                    root.go("tx", txid);
                }
            }

            Row {
                spacing: root.scaleUnit * 0.5

                Rectangle {
                    width: prevLabel.width + root.scaleUnit * 0.8
                    height: prevLabel.height + root.scaleUnit * 0.4
                    radius: height / 2
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: prevLabel

                        anchors.centerIn: parent
                        text: "‹ vorheriger Block"
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    MouseArea {
                        id: prevArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("blockhash", root.result.previousblockhash)
                    }
                }

                Rectangle {
                    visible: root.feed && root.result.height < root.feed.tipHeight
                    width: nextLabel.width + root.scaleUnit * 0.8
                    height: nextLabel.height + root.scaleUnit * 0.4
                    radius: height / 2
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: nextLabel

                        anchors.centerIn: parent
                        text: "nächster Block ›"
                        color: root.textColor
                        font.pixelSize: root.scaleUnit * 0.6
                    }

                    MouseArea {
                        id: nextArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("blockheight", String(root.result.height + 1))
                    }
                }
            }
        }
    }

    // ========================================================== Adresse
    Component {
        id: addressDetail

        Column {
            id: addrBox

            spacing: root.scaleUnit * 0.45

            readonly property var d: root.result
            readonly property var cs: d.chain_stats || ({})
            readonly property var ms: d.mempool_stats || ({})
            readonly property real balance: (cs.funded_txo_sum || 0) - (cs.spent_txo_sum || 0)
                                            + (ms.funded_txo_sum || 0) - (ms.spent_txo_sum || 0)

            Text {
                text: "Adresse"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
            }

            Row {
                spacing: root.uiFont * 0.5

                Text {
                    id: addrLabel

                    width: Math.min(flick.width - root.uiFont * 6, implicitWidth)
                    elide: Text.ElideMiddle
                    text: root.result.address
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 0.8
                    font.family: "monospace"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyText(root.result.address)
                    }
                }

                CopyButton {
                    anchors.verticalCenter: addrLabel.verticalCenter
                    text: root.result.address
                    done: root.copied === root.result.address
                    size: root.uiFont * 1.05
                    iconColor: root.dimColor
                    hoverColor: root.textColor
                    doneColor: root.goodColor
                    onCopy: function (what) { root.copyText(what); }
                }
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": "Guthaben", "v": root.btc(addrBox.balance) },
                        { "k": "Transaktionen", "v": root.grp((addrBox.cs.tx_count || 0)
                                                              + (addrBox.ms.tx_count || 0)) },
                        { "k": "Empfangen", "v": root.btc(addrBox.cs.funded_txo_sum) },
                        { "k": "Gesendet", "v": root.btc(addrBox.cs.spent_txo_sum) }
                    ]

                    Column {
                        id: ac

                        required property var modelData

                        spacing: root.scaleUnit * 0.1

                        Text {
                            text: ac.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            text: ac.modelData.v
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.75
                        }
                    }
                }
            }

            Text {
                visible: (root.extra || []).length > 0
                text: "Letzte Transaktionen"
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.6
            }

            Repeater {
                model: (root.extra || []).slice(0, 15)

                Rectangle {
                    id: atxRow

                    required property var modelData

                    width: flick.width
                    height: root.scaleUnit * 1.5
                    radius: 4
                    color: atxArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.scaleUnit * 0.4
                        spacing: root.scaleUnit * 0.6

                        Text {
                            width: root.scaleUnit * 9
                            elide: Text.ElideMiddle
                            text: atxRow.modelData.txid
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.6
                            font.family: "monospace"
                        }

                        Text {
                            text: atxRow.modelData.status && atxRow.modelData.status.confirmed
                                ? root.ago(atxRow.modelData.status.block_time) : "im Mempool"
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.6
                        }
                    }

                    MouseArea {
                        id: atxArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go("tx", atxRow.modelData.txid)
                    }
                }
            }
        }
    }
}
