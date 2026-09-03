import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Einstellungen des Plugins in DMS.
//
// **Der grosse Teil steht nicht hier**, sondern auf der Seite "Einstellungen"
// im Dashboard-Tab und im Fenster -- dort ist er nach Ansichten geordnet und
// in allen Sprachen. Hier bleibt, was DMS selbst betrifft: die Ansicht eines
// Desktop-Widgets und dessen Aussehen.
//
// DMS legt jede Desktop-Widget-Instanz getrennt ab. Wer den Feed dreimal aufs
// Desktop legt, kann jedem Fenster eine andere Ansicht geben.
PluginSettings {
    pluginId: "orangedeck"

    SelectionSetting {
        settingKey: "widgetView"
        label: "Ansicht des Desktop-Widgets"
        description: "Jede Instanz kann eine andere zeigen — Feed, BlockClock, Miner, Explorer oder die beobachteten Wallets."
        options: [
            {label: "Feed", value: "feed"},
            {label: "BlockClock", value: "clock"},
            {label: "Miner", value: "miner"},
            {label: "Explorer", value: "explorer"},
            {label: "Wallet", value: "wallet"}
        ]
        defaultValue: "feed"
    }

    SelectionSetting {
        settingKey: "colorMode"
        label: "Farbe nach"
        description: "Alter: orange beim Eintreffen, blau nach 60 Sekunden (wie im Original). Gebühr: türkis bis violett nach sat/vByte. Art: eine Farbe je Transaktionsart."
        options: [
            {label: "Alter", value: "age"},
            {label: "Gebührenrate", value: "fee"},
            {label: "Art", value: "type"}
        ]
        defaultValue: "age"
    }

    SelectionSetting {
        settingKey: "sizeMode"
        label: "Größe nach"
        description: "Wert: jede Rasterstufe entspricht dem Zehnfachen an Ausgabewert. vBytes: Fläche nach Transaktionsgröße."
        options: [
            {label: "Ausgabewert", value: "value"},
            {label: "vBytes", value: "vbytes"}
        ]
        defaultValue: "value"
    }

    ToggleSetting {
        settingKey: "showInfo"
        label: "Blockangaben"
        description: "Höhe, Zeit, Gesamtwert, Größe und Ø-Gebühr des letzten Blocks"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showLegend"
        label: "Legende"
        description: "Größen- und Farbskala am rechten Rand"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "desktopOpacity"
        label: "Deckkraft Desktop-Widget"
        description: "Hintergrund des Desktop-Widgets"
        defaultValue: 70
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "tileDensity"
        label: "Kachelgröße"
        description: "Größer = weniger, dafür gröbere Kacheln"
        defaultValue: 100
        minimum: 60
        maximum: 250
        unit: "%"
    }
}
