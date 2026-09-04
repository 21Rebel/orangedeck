// Die vier Tafeln der Startseite: Gebuehrenstufen, Schwierigkeitsanpassung,
// Zustand des Mempools mit Zulaufkurve und die zuletzt ersetzten
// Transaktionen (RBF).
//
// Alles bis auf die Ersetzungen kommt aus `FeedState` -- also ohne
// zusaetzlichen Abruf.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Grid {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real uiFont: 13
    property string lang: "de"
    property var replacements: []
    // Welche Tafeln gezeigt werden. Leer heisst alle. `Grid` laesst
    // unsichtbare Kinder aus, es bleibt also keine Luecke stehen.
    property var panels: []

    function zeigt(id) {
        var f = root.panels;
        if (!f || !f.length || typeof f.indexOf !== "function")
            return true;
        return f.indexOf(id) >= 0;
    }

    signal txPicked(string txid)

    columns: width > uiFont * 62 ? 2 : 1
    columnSpacing: uiFont * 1.2
    rowSpacing: uiFont * 1.2

    readonly property real panelWidth: (width - (columns - 1) * columnSpacing) / columns
    // Die beiden unteren Tafeln sind gleich hoch -- unterschiedlich hohe
    // Nachbarn wirken wie ein Versehen. Die Hoehe richtet sich nach der
    // volleren von beiden, damit nichts abgeschnitten wird.
    readonly property real lowerHeight: Math.max(uiFont * 19,
                                                 rbfCol.implicitHeight + uiFont * 3.4)
    readonly property var fees: (feed && feed.snap.fees) || ({})
    readonly property var diff: feed ? feed.difficulty : ({})
    readonly property var stats: (feed && feed.snap.stats) || ({})

    // Tausendertrennung in der Schreibweise der Sprache -- Deutsch nimmt den
    // Punkt, Englisch das Komma. Das ist keine Kosmetik: "1.234" heisst je
    // nach Sprache tausendzweihundert oder eins Komma zwei.
    function grp(n) {
        return Tr.group(n, root.lang);
    }

    function sat(v) {
        return (v === undefined || v === null) ? "–" : Tr.fixed(v, 2, root.lang);
    }

    function span(ms) {
        if (!ms || ms < 0)
            return "–";
        var min = Math.floor(ms / 60000);
        var d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60);
        if (d > 0)
            return Tr.t(d === 1 ? "in.day" : "in.days", root.lang, d);
        if (h > 0)
            return Tr.t("in.hours", root.lang, h);
        return Tr.t("in.min", root.lang, min);
    }

    function reload() {
        if (!root.feed)
            return;
        root.feed.lookup("replacements", "now", function (d, err) {
            if (!err)
                root.replacements = d || [];
        });
    }

    Component.onCompleted: reload()

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.reload()
    }

    // Ein Rahmen fuer alle Tafeln
    component Panel: Rectangle {
        property alias title: head.text
        // Wo der Inhalt anfangen darf. Wer mittig stehen will, mittet
        // **darunter** -- sonst rechnet er die Ueberschrift mit und sitzt
        // sichtbar zu tief.
        readonly property real contentTop: head.y + head.height + root.uiFont * 0.6

        width: root.panelWidth
        radius: root.uiFont * 0.4
        color: Qt.rgba(1, 1, 1, 0.035)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
            id: head

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: root.uiFont * 0.8
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
            font.letterSpacing: 0.6
        }
    }

    // ------------------------------------------------ Gebuehrenstufen
    Panel {
        height: root.uiFont * 8.4
        visible: root.zeigt("fees")
        title: Tr.t("panel.fees", root.lang)

        Row {
            id: feeRow

            anchors.horizontalCenter: parent.horizontalCenter
            // Mittig im Raum **unter** der Ueberschrift
            y: parent.contentTop + (parent.height - parent.contentTop - height) / 2
            spacing: root.uiFont * 1.6

            Repeater {
                model: [
                    { "k": Tr.t("fee.none", root.lang), "v": root.fees.economy },
                    { "k": Tr.t("fee.low", root.lang), "v": root.fees.hour },
                    { "k": Tr.t("fee.medium", root.lang), "v": root.fees.halfHour },
                    { "k": Tr.t("fee.high", root.lang), "v": root.fees.fastest }
                ]

                Column {
                    id: tier

                    required property var modelData
                    required property int index

                    spacing: root.uiFont * 0.95

                    Rectangle {
                        width: root.uiFont * 7.6
                        height: root.uiFont * 1.5
                        radius: root.uiFont * 0.25
                        // Von gedaempft nach kraeftig -- hoehere Prioritaet,
                        // kraeftigeres Gruen. Dieselbe Logik wie bei den
                        // geplanten Bloecken.
                        color: Qt.hsva(root.goodColor.hsvHue,
                                       0.4 + 0.12 * tier.index,
                                       0.34 + 0.13 * tier.index, 1)

                        Text {
                            anchors.centerIn: parent
                            text: tier.modelData.k
                            color: "#ffffff"
                            font.pixelSize: root.uiFont * 0.78
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: root.uiFont * 0.3

                        Text {
                            anchors.baseline: unit.baseline
                            text: root.sat(tier.modelData.v)
                            color: root.textColor
                            font.pixelSize: root.uiFont * 1.5
                        }

                        Text {
                            id: unit

                            text: "sat/vB"
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.8
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------ Schwierigkeitsanpassung
    Panel {
        height: root.uiFont * 8.4
        visible: root.zeigt("difficulty")
        title: Tr.t("panel.difficulty", root.lang)

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.uiFont * 0.6
            anchors.margins: root.uiFont * 0.9
            spacing: root.uiFont * 0.7

            Rectangle {
                width: parent.width
                height: root.uiFont * 1.1
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.diff.progress || 0) / 100))
                    height: parent.height
                    radius: height / 2

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "#3d8ce0"
                        }
                        GradientStop {
                            position: 1
                            color: "#8b5cf6"
                        }
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 600
                        }
                    }
                }
            }

            Row {
                width: parent.width

                Repeater {
                    model: [
                        { "k": Tr.t("diff.avgBlockTime", root.lang),
                          "v": root.diff.timeAvg
                              ? "~" + Tr.t("duration.min", root.lang,
                                            Tr.fixed(root.diff.timeAvg / 60000, 1, root.lang))
                              : "–",
                          "c": root.textColor },
                        { "k": Tr.t("diff.change", root.lang),
                          "v": root.diff.change !== undefined
                              ? (root.diff.change >= 0 ? "▲ +" : "▼ ") + root.sat(root.diff.change) + " %" : "–",
                          "c": (root.diff.change || 0) >= 0 ? root.goodColor : root.badColor },
                        { "k": root.diff.nextHeight
                            ? Tr.t("diff.targetAt", root.lang, root.grp(root.diff.nextHeight))
                            : Tr.t("diff.next", root.lang),
                          "v": root.span(root.diff.remainingTime),
                          "c": root.textColor }
                    ]

                    Column {
                        id: dcol

                        required property var modelData

                        width: parent.width / 3
                        spacing: root.uiFont * 0.15

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dcol.modelData.v
                            color: dcol.modelData.c
                            font.pixelSize: root.uiFont * 1.15
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: dcol.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.75
                        }
                    }
                }
            }
        }
    }

    // ----------------------------------------------- Zustand des Mempools
    Panel {
        height: root.lowerHeight
        visible: root.zeigt("mempool")
        title: Tr.t("panel.mempool", root.lang)

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: root.uiFont * 0.9
            anchors.topMargin: root.uiFont * 2.4
            spacing: root.uiFont * 0.6

            Row {
                width: parent.width

                Repeater {
                    model: [
                        { "k": Tr.t("mempool.minFee", root.lang), "v": root.sat(root.fees.minimum) + " sat/vB" },
                        { "k": Tr.t("mempool.usage", root.lang), "v": (root.feed && root.feed.mempoolVsize)
                            ? Math.round(root.feed.mempoolVsize / 1e6) + " MB" : "–" },
                        { "k": Tr.t("mempool.unconfirmed", root.lang), "v": root.feed ? root.grp(root.feed.mempoolCount) : "–" }
                    ]

                    Column {
                        id: mcol

                        required property var modelData

                        width: parent.width / 3
                        spacing: root.uiFont * 0.15

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mcol.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.75
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mcol.modelData.v
                            color: root.textColor
                            font.pixelSize: root.uiFont * 1.15
                        }
                    }
                }
            }

            Text {
                text: Tr.t("mempool.incoming", root.lang)
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.78
            }

            Canvas {
                id: inflow

                width: parent.width
                // Nimmt, was die Tafel uebrig laesst
                height: root.lowerHeight - root.uiFont * 8.6

                Connections {
                    target: root
                    function onStatsChanged() {
                        inflow.requestPaint();
                    }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var s = root.stats.inflow || [];
                    if (s.length < 2)
                        return;
                    var peak = Math.max.apply(null, s);
                    if (peak <= 0)
                        return;
                    // **Luft nach oben.** Ohne sie beruehrt die hoechste Spitze
                    // die Oberkante und wird durch die Strichstaerke
                    // angeschnitten; die oberste Beschriftung haette dort auch
                    // keinen Platz.
                    var hi = peak * 1.12;
                    var padB = root.uiFont * 1.1, padL = root.uiFont * 2.4;
                    var padT = root.uiFont * 0.5;
                    var w = width - padL, h = height - padB - padT;

                    // Waagerechte Hilfslinien mit Beschriftung
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07);
                    ctx.fillStyle = root.dimColor;
                    ctx.font = (root.uiFont * 0.68) + "px " + Fonts.sansCss();
                    ctx.textAlign = "right";
                    ctx.lineWidth = 1;
                    for (var g = 0; g <= 2; g++) {
                        var gy = Math.round(padT + h * g / 2) + 0.5;
                        ctx.beginPath();
                        ctx.moveTo(padL, gy);
                        ctx.lineTo(width, gy);
                        ctx.stroke();
                        // Beschriftet wird der **echte** Hoechstwert, nicht der
                        // um die Luft erhoehte
                        ctx.fillText(Tr.fixed(peak * (1 - g / 2), 1, root.lang),
                                     padL - root.uiFont * 0.4, gy + root.uiFont * 0.25);
                    }

                    // Die Kurve, eingefaerbt nach Hoehe: ruhig gruen, Spitzen rot
                    ctx.lineWidth = Math.max(1.4, root.uiFont * 0.13);
                    ctx.lineJoin = "round";
                    for (var i = 1; i < s.length; i++) {
                        var x0 = padL + w * (i - 1) / (s.length - 1);
                        var x1 = padL + w * i / (s.length - 1);
                        var y0 = padT + h - h * s[i - 1] / hi;
                        var y1 = padT + h - h * s[i] / hi;
                        var f = Math.max(s[i - 1], s[i]) / hi;
                        ctx.strokeStyle = Qt.hsva((1 - f) * 0.33, 0.75, 0.9, 1);
                        ctx.beginPath();
                        ctx.moveTo(x0, y0);
                        ctx.lineTo(x1, y1);
                        ctx.stroke();
                    }

                    // Mittelwert als gestrichelte Linie
                    var sum = 0;
                    for (i = 0; i < s.length; i++)
                        sum += s[i];
                    var avg = sum / s.length;
                    var ay = Math.round(padT + h - h * avg / hi) + 0.5;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (var x = padL; x < width; x += 8) {
                        ctx.moveTo(x, ay);
                        ctx.lineTo(Math.min(width, x + 4), ay);
                    }
                    ctx.stroke();

                    ctx.textAlign = "left";
                    ctx.fillStyle = root.dimColor;
                    ctx.fillText(Tr.t("mempool.perMin", root.lang,
                                      Math.round(s.length * 5 / 60),
                                      Tr.fixed(avg, 1, root.lang) + " tx/s"),
                                 padL, height - root.uiFont * 0.15);
                }
            }
        }
    }

    // ------------------------------------------------ Ersetzungen (RBF)
    Panel {
        height: root.lowerHeight
        visible: root.zeigt("rbf")
        title: Tr.t("panel.rbf", root.lang)

        Column {
            id: rbfCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.uiFont * 0.9
            anchors.topMargin: root.uiFont * 2.4
            spacing: root.uiFont * 0.2

            Row {
                width: parent.width
                spacing: root.uiFont * 0.8

                Text {
                    width: parent.width * 0.42
                    text: "TxID"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.72
                }

                Text {
                    width: parent.width * 0.2
                    horizontalAlignment: Text.AlignRight
                    text: "vorher"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.72
                }

                Text {
                    width: parent.width * 0.2
                    horizontalAlignment: Text.AlignRight
                    text: "neu"
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.72
                }
            }

            Repeater {
                model: root.replacements.slice(0, 7)

                Rectangle {
                    id: rrow

                    required property var modelData

                    readonly property var newTx: rrow.modelData.tx || ({})
                    readonly property var oldTx: (rrow.modelData.replaces
                                                  && rrow.modelData.replaces.length)
                        ? rrow.modelData.replaces[0].tx || ({}) : ({})

                    width: parent.width
                    height: root.uiFont * 1.7
                    radius: 3
                    color: rarea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: root.uiFont * 0.2
                        spacing: root.uiFont * 0.8

                        Text {
                            width: parent.width * 0.42
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: rrow.newTx.txid || ""
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.78
                            font.family: Fonts.mono()
                        }

                        Text {
                            width: parent.width * 0.2
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: rrow.oldTx.rate !== undefined ? root.sat(rrow.oldTx.rate) : "–"
                            color: root.dimColor
                            font.pixelSize: root.uiFont * 0.78
                        }

                        Text {
                            width: parent.width * 0.2
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: rrow.newTx.rate !== undefined ? root.sat(rrow.newTx.rate) : "–"
                            color: root.goodColor
                            font.pixelSize: root.uiFont * 0.78
                        }
                    }

                    MouseArea {
                        id: rarea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rrow.newTx.txid)
                                root.txPicked(String(rrow.newTx.txid));
                        }
                    }
                }
            }
        }
    }
}
