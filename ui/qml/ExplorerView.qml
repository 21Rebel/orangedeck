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

    // --- Zustand ---------------------------------------------------------
    property string kind: ""          // tx | block | address
    // **Nicht** `data` nennen: das ist in QML die Standard-Eigenschaft, in der
    // die Kindelemente liegen. Sie zu ueberschreiben bringt den Baum durcheinander.
    property var result: null         // Antwort der Hauptabfrage
    property var extra: null          // outspends bzw. Adresstransaktionen
    property string status: ""        // Meldung statt Ergebnis
    property bool busy: false
    property var trail: []            // Weg dorthin, fuer den Zurueck-Knopf

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

        var route = kind === "tx" ? "tx" : (kind === "blockhash" ? "block" : "address");
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
        height: field.height + root.scaleUnit * 1.1

        Rectangle {
            id: backBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: root.scaleUnit * 1.9
            height: width
            radius: width / 2
            visible: root.trail.length > 0
            color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: root.textColor
                font.pixelSize: root.scaleUnit * 1.1
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
            anchors.left: backBtn.visible ? backBtn.right : parent.left
            anchors.leftMargin: backBtn.visible ? root.scaleUnit * 0.5 : 0
            anchors.right: parent.right
            height: field.height + root.scaleUnit * 0.7
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: field.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: hintLabel.left
                anchors.leftMargin: root.scaleUnit * 0.9
                anchors.rightMargin: root.scaleUnit * 0.5
                anchors.verticalCenter: parent.verticalCenter
                color: root.textColor
                font.pixelSize: root.scaleUnit * 0.8
                font.family: "monospace"
                selectByMouse: true
                clip: true
                onAccepted: root.submit(text)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "Blockhöhe, Blockhash, TxID oder Adresse …"
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.8
                }
            }

            Text {
                id: hintLabel

                anchors.right: parent.right
                anchors.rightMargin: root.scaleUnit * 0.9
                anchors.verticalCenter: parent.verticalCenter
                text: root.busy ? "sucht …" : Search.hintFor(field.text)
                color: root.busy ? root.accentColor : root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
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

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.kind === "" && root.status.length === 0
                text: "Gib eine Blockhöhe, einen Blockhash, eine TxID oder eine Adresse ein.\n"
                      + "Auch txid:n für einen Ausgang und n:txid für einen Eingang.\n\n"
                      + "Aus dem Feed heraus führt ein Klick auf eine Kachel direkt hierher."
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.7
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

            Text {
                width: flick.width
                elide: Text.ElideMiddle
                text: root.result.txid
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 0.8
                font.family: "monospace"
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
                // flacher, deshalb bekommt sie mit jedem Band mehr Hoehe und
                // reicht weiter hinauf als frueher.
                // Die Flaeche waechst mit der Zahl der Baender, der Strang
                // bleibt gleich dick -- so ziehen sich die Luecken auf.
                height: Math.max(root.scaleUnit * 7, Math.min(root.scaleUnit * 26,
                        root.scaleUnit * 1.3 * Math.max((root.result.vin || []).length,
                                                        (root.result.vout || []).length) + root.scaleUnit * 4))
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

            Text {
                width: flick.width
                elide: Text.ElideMiddle
                text: root.result.id
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.62
                font.family: "monospace"
            }

            Row {
                spacing: root.scaleUnit * 1.2

                Repeater {
                    model: [
                        { "k": "Zeit", "v": root.ago(root.result.timestamp) },
                        { "k": "Transaktionen", "v": root.grp(root.result.tx_count) },
                        { "k": "Größe", "v": root.grp(Math.round(root.result.size / 1024)) + " kB" },
                        { "k": "Gewicht", "v": root.grp(Math.round(root.result.weight / 1000)) + " kWU" }
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

            Text {
                width: flick.width
                elide: Text.ElideMiddle
                text: root.result.address
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 0.8
                font.family: "monospace"
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
