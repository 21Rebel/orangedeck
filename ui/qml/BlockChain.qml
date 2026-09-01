// Die letzten Bloecke als Kette, waagerecht rollbar. Neuester links.
//
// Die Daten kommen ueber den Daemon (`/lookup/blocks/recent`), der sie von
// mempool.space oder einem eigenen Node holt.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property var blocks: []
    property string error: ""

    signal blockPicked(string hash)

    implicitHeight: uiFont * 13

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
        var s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
        var m = Math.floor(s / 60);
        if (m < 60)
            return "vor " + m + " Min";
        var h = Math.floor(m / 60);
        if (h < 48)
            return "vor " + h + " Std";
        return "vor " + Math.floor(h / 24) + " Tagen";
    }

    function reload() {
        if (!root.feed)
            return;
        root.feed.lookup("blocks", "recent", function (d, err) {
            if (err) {
                root.error = err;
                return;
            }
            root.error = "";
            root.blocks = d || [];
        });
    }

    Component.onCompleted: reload()

    // Nach einem neuen Block nachladen
    Connections {
        target: root.feed
        enabled: root.feed !== null
        function onBlockMined() {
            reloadTimer.restart();
        }
    }

    Timer {
        id: reloadTimer

        interval: 4000
        onTriggered: root.reload()
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: "Letzte Blöcke"
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }

    Flickable {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.uiFont * 1.6
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: row.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: row

            spacing: root.uiFont * 0.6

            Repeater {
                model: root.blocks

                Item {
                    id: cell

                    required property var modelData

                    readonly property var ex: cell.modelData.extras || ({})

                    width: root.uiFont * 10
                    height: strip.height

                    Text {
                        id: heightLabel

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.grp(cell.modelData.height)
                        color: root.accentColor
                        font.pixelSize: root.uiFont * 0.95
                        font.bold: true
                    }

                    Rectangle {
                        anchors.top: heightLabel.bottom
                        anchors.topMargin: root.uiFont * 0.3
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        radius: root.uiFont * 0.3
                        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - root.uiFont
                            spacing: root.uiFont * 0.18

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.medianFee !== undefined
                                    ? "~" + Math.round(cell.ex.medianFee) + " sat/vB" : ""
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.75
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.ex.reward
                                    ? (cell.ex.reward / 1e8).toFixed(3).replace(".", ",") + " BTC" : ""
                                color: root.textColor
                                font.pixelSize: root.uiFont * 0.95
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.grp(cell.modelData.tx_count) + " Transaktionen"
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (cell.modelData.size / 1024 / 1024).toFixed(2).replace(".", ",") + " MB"
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.ago(cell.modelData.timestamp)
                                color: root.dimColor
                                font.pixelSize: root.uiFont * 0.72
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: (cell.ex.pool && cell.ex.pool.name) || ""
                                color: root.accentColor
                                font.pixelSize: root.uiFont * 0.72
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.blockPicked(cell.modelData.id)
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.blocks.length === 0
        text: root.error.length ? root.error : "lädt …"
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.85
    }
}
