// Liquidations-Heatmap -- der dritte Unterreiter im Markt.
//
// **Das hier ist gerechnet, nicht gemessen.** Es zeigt nicht, wo liquidiert
// wurde -- das steht im Reiter daneben --, sondern wo Positionen *laegen*
// und bei welchem Kurs sie sterben wuerden. Die hellen Baender liegen
// deshalb **vor** dem Kurs; eine Messung kann das prinzipiell nicht, sie
// kennt keine Zukunft.
//
// Zwei Annahmen stecken darin, beide erfunden: die Verteilung der Hebel und
// die Aufteilung zwischen Long und Short. Der Dienst schickt sie mit, und
// diese Ansicht nennt sie -- eine Schaetzung, die sich als Messung ausgibt,
// waere schlimmer als gar keine.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string lang: "de"
    property string zeichen: "$"
    // Antwort von /market/heatmap
    property var yAchse: []
    property var zellen: []
    property real hoechst: 0
    property var schlusskurse: []
    property var hebel: []
    property bool zuLang: false
    property int maxTage: 30

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property real baseFont: 12

    readonly property bool hatDaten: root.hoechst > 0 && root.zellen.length > 0

    // Die Hebelstufen als Text, damit die Annahme dasteht statt im Quelltext
    // zu verschwinden: "5x 30 %, 10x 30 %, ..."
    readonly property string hebelText: {
        var t = [];
        for (var i = 0; i < root.hebel.length; i++)
            t.push(root.hebel[i][0] + "× " + Math.round(root.hebel[i][1] * 100) + " %");
        return t.join(" · ");
    }

    function geld(v) {
        if (v >= 1e9)
            return Tr.fixed(v / 1e9, 1, root.lang) + " G";
        if (v >= 1e6)
            return Tr.fixed(v / 1e6, 1, root.lang) + " M";
        if (v >= 1000)
            return Math.round(v / 1000) + " k";
        return Math.round(v) + "";
    }

    // --------------------------------------------------------- Kopfzeile
    Column {
        id: kopf

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.baseFont * 0.3

        Row {
            spacing: root.baseFont * 0.5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("market.heatTitle", root.lang)
                color: root.textColor
                font.pixelSize: root.baseFont
                font.bold: true
            }

            // **Der Warnhinweis ist Teil der Ansicht, keine Fussnote.** Wer
            // ihn wegnimmt, macht aus einer Schaetzung eine Behauptung.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: warn.implicitWidth + root.baseFont * 0.8
                height: warn.implicitHeight + root.baseFont * 0.25
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: root.accentColor

                Text {
                    id: warn

                    anchors.centerIn: parent
                    text: Tr.t("market.estimate", root.lang)
                    color: root.accentColor
                    font.pixelSize: root.baseFont - 3
                    font.bold: true
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatHow", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
        }

        Text {
            width: parent.width
            visible: root.hebel.length > 0
            wrapMode: Text.WordWrap
            text: Tr.t("market.heatAssume", root.lang, root.hebelText)
            color: root.dimColor
            font.pixelSize: root.baseFont - 3
            font.family: Fonts.mono()
        }
    }

    // ---------------------------------------------------------- Das Bild
    Item {
        id: bild

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: kopf.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: root.baseFont * 0.6

        readonly property real achse: root.baseFont * 4.2
        readonly property real feld: Math.max(10, width - achse - root.baseFont * 0.5)

        Text {
            anchors.centerIn: parent
            visible: !root.hatDaten
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.zuLang ? Tr.t("market.heatTooLong", root.lang, root.maxTage)
                              : Tr.t("market.heatEmpty", root.lang)
            color: root.dimColor
            font.pixelSize: root.baseFont - 1
        }

        Canvas {
            id: leinwand

            visible: root.hatDaten
            x: bild.achse
            width: bild.feld
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            antialiasing: false

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var n = root.zellen.length;
                if (!n || root.hoechst <= 0)
                    return;
                var spalten = root.schlusskurse.length || 1;
                var stufen = root.yAchse.length || 1;
                var bw = width / spalten;
                var bh = height / stufen;
                // **Wurzelkennlinie statt linear.** Die Betraege gehen ueber
                // drei Groessenordnungen; linear waere alles ausser der
                // hellsten Zelle schwarz.
                for (var i = 0; i < n; i++) {
                    var z = root.zellen[i];
                    var t = Math.pow(z[2] / root.hoechst, 0.45);
                    // Von dunkelrot ueber orange nach gelb -- dieselbe
                    // Richtung wie die Waerme, die der Name verspricht.
                    var r = Math.min(1, 0.35 + t * 0.65);
                    var g = Math.max(0, Math.min(1, (t - 0.35) * 1.5));
                    var b = Math.max(0, (t - 0.8) * 2.5);
                    ctx.fillStyle = Qt.rgba(r, g, b, Math.min(0.95, 0.12 + t));
                    // Die Stufe 0 liegt unten: y-Achse umgedreht
                    ctx.fillRect(Math.floor(z[0] * bw),
                                 Math.floor((stufen - 1 - z[1]) * bh),
                                 Math.ceil(bw) + 1, Math.ceil(bh) + 1);
                }

                // Der Kurs darueber -- ohne ihn sagen die Baender nichts,
                // weil die Frage immer "wo relativ zu jetzt" heisst.
                if (root.yAchse.length > 1 && root.schlusskurse.length > 1) {
                    var tief = root.yAchse[0];
                    var hoch = root.yAchse[root.yAchse.length - 1];
                    if (hoch > tief) {
                        ctx.strokeStyle = "#ffffff";
                        ctx.lineWidth = 1.2;
                        ctx.globalAlpha = 0.85;
                        ctx.beginPath();
                        for (var x = 0; x < root.schlusskurse.length; x++) {
                            var yy = height * (1 - (root.schlusskurse[x] - tief) / (hoch - tief));
                            if (x === 0)
                                ctx.moveTo(x * bw + bw / 2, yy);
                            else
                                ctx.lineTo(x * bw + bw / 2, yy);
                        }
                        ctx.stroke();
                        ctx.globalAlpha = 1;
                    }
                }
            }
        }

        // Preisachse links
        Repeater {
            model: root.hatDaten ? root.yAchse : []

            Text {
                id: marke

                required property var modelData
                required property int index

                readonly property real zeilenhoehe:
                    bild.height / Math.max(1, root.yAchse.length)
                readonly property int jedeWievielte:
                    Math.max(1, Math.ceil((root.baseFont + 2) / zeilenhoehe))

                visible: marke.index % marke.jedeWievielte === 0
                x: 0
                y: bild.height - (marke.index + 1) * marke.zeilenhoehe
                width: bild.achse - root.baseFont * 0.4
                height: marke.zeilenhoehe
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: Tr.group(marke.modelData, root.lang)
                color: root.dimColor
                font.pixelSize: Math.max(7, root.baseFont - 3)
                font.family: Fonts.mono()
            }
        }

        // Massstab: was die hellste Zelle bedeutet
        Text {
            visible: root.hatDaten
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: root.baseFont * 0.3
            text: Tr.t("market.heatScale", root.lang,
                       root.zeichen + " " + root.geld(root.hoechst))
            color: root.dimColor
            font.pixelSize: Math.max(7, root.baseFont - 3)
        }
    }

    onZellenChanged: leinwand.requestPaint()
    onWidthChanged: leinwand.requestPaint()
    onHeightChanged: leinwand.requestPaint()
}
