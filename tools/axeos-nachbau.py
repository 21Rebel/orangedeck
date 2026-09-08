"""Ein AxeOS-Nachbau fuer den Prueflauf. Die Feldnamen sind die echten,
die Werte an einem Bitaxe Gamma plausibel gewaehlt."""
import http.server, json, math, random, time

START = time.time()

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
        "uptimeSeconds": int(48 * 3600 + t),
        "miningPaused": False,
        # **Mit Benutzername**, damit gepruefte wird, dass nur der Wirt bleibt.
        "stratumURL": "stratum+tcp://public-pool.io:21496/bc1qbeispieladresse",
        "hashrateMonitor": {"asics": [{"domains": [
            round(268 + math.sin(t / 5 + i) * 12, 1) for i in range(4)]}]},
    }

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.rstrip("/") != "/api/system/info":
            self.send_response(404); self.end_headers(); return
        b = json.dumps(satz()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass

http.server.HTTPServer(("127.0.0.1", 21042), H).serve_forever()
