"""Ein AxeOS-Nachbau fuer den Prueflauf. Die Feldnamen sind die echten,
die Werte an einem Bitaxe Gamma plausibel gewaehlt.

Mit `/api/system/statistics` wie ab AxeOS 2.x: zwoelf Stunden Verlauf im
Minutenabstand, samt `columns`-Auswahl. Die Form ist am 10.09.2026 an einem
echten Bitaxe (v2.14.2) abgelesen: `labels` in der Reihenfolge des Geraets,
der Zeitstempel immer dabei, gezaehlt in Millisekunden seit dessen Start.

    NACHBAU_STATISTIK=0 python3 tools/axeos-nachbau.py

stellt die Aufzeichnung ab (`statsFrequency` 0, leere Liste) -- so wird ein
Bitaxe ausgeliefert.
"""
import http.server, json, math, os, random, time, urllib.parse

START = time.time()
# Das Geraet laeuft schon 48 Stunden, wenn der Nachbau startet.
VORLAUF = 48 * 3600
STATISTIK = os.environ.get("NACHBAU_STATISTIK", "1") != "0"
TAKT = 60
GRENZE = 720
SPALTEN = ["hashrate", "hashrate_1m", "hashrate_10m", "hashrate_1h", "errorPercentage",
           "asicTemp", "asicTemp2", "vrTemp", "asicVoltage", "voltage", "power",
           "current", "fanSpeed", "fanRpm", "fan2Rpm", "wifiRssi", "freeHeap",
           "responseTime", "timestamp"]

def satz():
    t = time.time() - START
    grund = 1080.0
    return {
        "hostname": "bitaxe-prueflauf",
        "ASICModel": "BM1370",
        "boardVersion": "601",
        "axeOSVersion": "v2.6.5",
        "hashRate": grund + math.sin(t / 7) * 90 + random.uniform(-25, 25),
        "hashRate_1m": grund + math.sin(t / 30) * 40,
        "hashRate_10m": grund + math.sin(t / 90) * 15,
        "expectedHashrate": 1200,
        "bestDiff": "412M",
        "bestSessionDiff": "12.4M",
        "poolDifficulty": "1000",
        "networkDifficulty": "142.3T",
        "blockFound": 0,
        "errorPercentage": 0.31 + random.uniform(0, 0.2),
        "temp": 61.5 + math.sin(t / 20) * 2.5,
        "power": 18.4 + random.uniform(-0.6, 0.6),
        "fanrpm": 4120,
        "sharesAccepted": 84213,
        "sharesRejected": 12,
        "uptimeSeconds": int(VORLAUF + t),
        "statsFrequency": TAKT if STATISTIK else 0,
        "statsLimit": GRENZE,
        "miningPaused": False,
        # **Mit Benutzername**, damit gepruefte wird, dass nur der Wirt bleibt.
        "stratumURL": "stratum+tcp://public-pool.io:21496/bc1qbeispieladresse",
        "hashrateMonitor": {"asics": [{"domains": [
            round(268 + math.sin(t / 5 + i) * 12, 1) for i in range(4)]}]},
    }

def statistik(spalten):
    """Die letzten GRENZE Eintraege, einer je TAKT Sekunden."""
    jetzt_ms = int((VORLAUF + time.time() - START) * 1000)
    labels = [c for c in SPALTEN if c in spalten or c == "timestamp"]
    zeilen = []
    if STATISTIK:
        for k in range(GRENZE, 0, -1):
            ts = jetzt_ms - k * TAKT * 1000
            t = ts / 1000
            werte = {
                # Ein langsamer Gang und etwas Rauschen, damit man im Graphen
                # sieht, dass Stunden darin stehen.
                "hashrate": 1080 + math.sin(t / 5400) * 60 + random.uniform(-30, 30),
                "hashrate_10m": 1080 + math.sin(t / 5400) * 60,
                "errorPercentage": 0.3 + random.uniform(0, 0.2),
                # Um denselben Wert wie `temp` in satz(), sonst springt der
                # Graph am Uebergang zu den Live-Werten.
                "asicTemp": 61.5 + math.sin(t / 7200) * 2.5,
            }
            zeilen.append([ts if c == "timestamp" else round(werte.get(c, 0), 2)
                           for c in labels])
    return {"currentTimestamp": jetzt_ms, "labels": labels, "statistics": zeilen}

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        teile = urllib.parse.urlsplit(self.path)
        pfad = teile.path.rstrip("/")
        if pfad == "/api/system/statistics":
            q = urllib.parse.parse_qs(teile.query)
            spalten = q["columns"][0].split(",") if "columns" in q else SPALTEN
            b = json.dumps(statistik(spalten)).encode()
        elif pfad == "/api/system/info":
            b = json.dumps(satz()).encode()
        else:
            self.send_response(404); self.end_headers(); return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass

http.server.HTTPServer(("127.0.0.1", 21042), H).serve_forever()
