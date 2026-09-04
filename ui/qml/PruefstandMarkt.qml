// Pruefstand: nur der Markt-Reiter, mit einem Schalter fuer die Vorschau.
// Nicht ausgeliefert -- zum Ansehen dessen, was beim Ziehen am Schieber
// gezeichnet wird, ohne dass eine Maus im Spiel sein muss.
import QtQuick

Item {
    id: pruef

    width: 1400
    height: 820

    // Der Zeitpunkt, auf den "gezogen" wird -- ueber die Umgebung setzbar
    // Die beiden letzten Argumente, egal wie der Laeufer davor zaehlt
    readonly property var argumente: Qt.application.arguments
    property int zielEnde: parseInt(pruef.argumente[pruef.argumente.length - 2] || "0", 10)
    property bool zeigeVorschau: pruef.argumente[pruef.argumente.length - 1] === "1"

    QtObject {
        id: stubFeed

        property bool direkt: false

        function getJson(path, done) {
            var x = new XMLHttpRequest();
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE)
                    return;
                if (x.status !== 200) {
                    done(null, "nicht erreichbar");
                    return;
                }
                try {
                    done(JSON.parse(x.responseText), null);
                } catch (e) {
                    done(null, "Antwort nicht lesbar");
                }
            };
            x.open("GET", "http://127.0.0.1:21021" + path);
            x.send();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#11131f"
    }

    MarketView {
        id: markt

        anchors.fill: parent
        anchors.margins: 14
        feed: stubFeed
        live: true
        lang: "de"
        currency: "usd"
        range: "24h"
        kind: "candles"
        lower: "volume"
        baseFont: 13
    }

    // Sobald die Uebersicht da ist: in die Vorschau schalten und auf das Ziel
    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: {
            if (!markt.uebersicht.length)
                return;
            if (pruef.zeigeVorschau) {
                // Wie waehrend des Ziehens: Stelle merken, nichts holen
                markt.vorschau = true;
                markt.fensterSchieben(pruef.zielEnde);
            } else {
                // Wie beim Loslassen: Vorschau aus, genaues Fenster holen
                markt.vorschau = false;
                markt.fensterSetzen(pruef.zielEnde);
            }
            running = false;
        }
    }
}
