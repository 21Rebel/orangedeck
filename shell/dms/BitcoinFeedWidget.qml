// Leiste: Pille mit Mempool-Zahl, Klick oeffnet die Live-Ansicht.
// Rechtsklick oeffnet sie in einem eigenen Fenster.
// Ausserdem als Control-Center-Kachel mit ausklappbarer Ansicht.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string windowCommand: Quickshell.env("HOME") + "/.local/bin/btcfeed-window"

    function grp(n) {
        if (!n)
            return "–";
        var s = String(Math.round(n)), out = "", c = 0;
        for (var i = s.length - 1; i >= 0; i--) {
            out = s[i] + out;
            if (++c % 3 === 0 && i > 0)
                out = "." + out;
        }
        return out;
    }

    function shortCount(n) {
        if (!n)
            return "–";
        return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n);
    }

    function feeText(v) {
        if (!v)
            return "–";
        return v < 10 ? v.toFixed(1) : String(Math.round(v));
    }

    FeedState {
        id: feedState

        pollMs: 500
    }

    property string colorMode: pluginService ? pluginService.loadPluginData("bitcoinFeed", "colorMode", "age") : "age"
    property string sizeMode: pluginService ? pluginService.loadPluginData("bitcoinFeed", "sizeMode", "value") : "value"
    property bool showInfo: pluginService ? pluginService.loadPluginData("bitcoinFeed", "showInfo", true) : true
    property bool showLegend: pluginService ? pluginService.loadPluginData("bitcoinFeed", "showLegend", true) : true

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== "bitcoinFeed")
                return;
            root.colorMode = root.pluginService.loadPluginData("bitcoinFeed", "colorMode", "age");
            root.sizeMode = root.pluginService.loadPluginData("bitcoinFeed", "sizeMode", "value");
            root.showInfo = root.pluginService.loadPluginData("bitcoinFeed", "showInfo", true);
            root.showLegend = root.pluginService.loadPluginData("bitcoinFeed", "showLegend", true);
        }
    }

    function openInWindow() {
        openWindow.running = false;
        openWindow.running = true;
    }

    Process {
        id: openWindow

        command: [root.windowCommand]
        running: false
    }

    ccWidgetIcon: "currency_bitcoin"
    ccWidgetPrimaryText: "Bitcoin"
    ccWidgetSecondaryText: feedState.online ? root.grp(feedState.mempoolCount) + " im Mempool" : "Feed offline"
    ccWidgetIsActive: feedState.online

    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 300
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            FeedPanel {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                feed: feedState
                colorMode: root.colorMode
                sizeMode: root.sizeMode
                infoVisible: root.showInfo
                legendVisible: root.showLegend
                textColor: Theme.surfaceText
                dimColor: Theme.surfaceVariantText
                accentColor: Theme.primary
                lineColor: Theme.outlineMedium
                baseFont: Theme.fontSizeSmall + 1
            }
        }
    }

    pillRightClickAction: () => root.openInWindow()

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "currency_bitcoin"
                size: Theme.fontSizeMedium + 2
                color: feedState.online ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shortCount(feedState.mempoolCount)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 0

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "currency_bitcoin"
                size: Theme.fontSizeMedium
                color: feedState.online ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shortCount(feedState.mempoolCount)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall - 2
            }
        }
    }

    popoutWidth: 560
    popoutHeight: 520

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Bitcoin Feed"
            detailsText: feedState.online ? "Block " + root.grp(feedState.tipHeight) + " · " + root.grp(feedState.mempoolCount) + " Transaktionen im Mempool" : "Feed offline – btcfeed läuft nicht"
            showCloseButton: true

            headerActions: Component {
                DankActionButton {
                    iconName: "open_in_new"
                    buttonSize: 30
                    tooltipText: "In eigenem Fenster öffnen"
                    onClicked: {
                        root.openInWindow();
                        if (popout.closePopout)
                            popout.closePopout();
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.max(200, root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingL * 2)

                FeedPanel {
                    anchors.fill: parent
                    feed: feedState
                    headerVisible: false
                    colorMode: root.colorMode
                    sizeMode: root.sizeMode
                    infoVisible: root.showInfo
                    legendVisible: root.showLegend
                    textColor: Theme.surfaceText
                    dimColor: Theme.surfaceVariantText
                    accentColor: Theme.primary
                    lineColor: Theme.outlineMedium
                    baseFont: Theme.fontSizeSmall + 1
                }
            }
        }
    }
}
