#!/usr/bin/env bash
# Das Android-Paket signieren.
#
# **Warum es das Skript gibt.** Dieselbe Begruendung wie bei
# `tools/schluessel.sh`, und aus demselben Anlass: die apksigner-Zeile ist zu
# lang fuer eine Terminalbreite. Am 08.09.2026 beim Einfuegen nach `--out`
# umgebrochen -- fish las den Rest als eigenen Befehl und meldete
# "Output file name missing after --out", dann "Unknown command:
# /home/.../orangedeck-0.2.1-arm64-v8a.apk". Eine halb ausgefuehrte
# Signierzeile ist schlimmer als eine gescheiterte: sie kann eine Datei
# anlegen, die aussieht wie ein Ergebnis.
#
#     tools/apk-signieren.sh            die neueste unsignierte Fassung
#     tools/apk-signieren.sh 0.2.1      eine bestimmte
#
# Das Passwort fragt apksigner selbst ab. **Nicht** ueber `--ks-pass pass:`:
# das schriebe es in die Prozessliste und in die Shell-Historie.
set -euo pipefail

ZIEL="${ORANGEDECK_APK_DIR:-$HOME/.local/share/orangedeck/auslieferung}"
KS="${ORANGEDECK_KEYSTORE:-$HOME/.local/share/orangedeck/signing/orangedeck.jks}"
FASSUNG="${1:-}"

SIGNER="$(ls -d "${ANDROID_SDK_ROOT:-$HOME/Android/sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)"
[ -x "${SIGNER:-}" ] || { echo "kein apksigner gefunden"; exit 1; }
[ -f "$KS" ] || { echo "kein Behaelter: $KS"; exit 1; }

if [ -z "$FASSUNG" ]; then
    # **Die hoechste Fassung, nicht die neueste Datei.** Ein Neubau einer
    # alten Nummer ist juenger und waere trotzdem die falsche.
    EIN="$(ls -1 "$ZIEL"/orangedeck-*-arm64-v8a-unsigniert.apk 2>/dev/null | sort -V | tail -1)"
    [ -n "$EIN" ] || { echo "keine unsignierte Fassung in $ZIEL"; exit 1; }
    FASSUNG="$(basename "$EIN" | sed -E 's/^orangedeck-(.*)-arm64-v8a-unsigniert\.apk$/\1/')"
else
    EIN="$ZIEL/orangedeck-$FASSUNG-arm64-v8a-unsigniert.apk"
    [ -f "$EIN" ] || { echo "fehlt: $EIN"; exit 1; }
fi
AUS="$ZIEL/orangedeck-$FASSUNG-arm64-v8a.apk"

# Nie ueber ein bestehendes Ergebnis gehen: wer zweimal signiert, will
# wissen, dass er es tut.
[ -e "$AUS" ] && { echo "Liegt bereits: $AUS"; echo "Nichts getan."; exit 1; }

echo "Fassung   $FASSUNG"
echo "Eingang   $EIN"
echo "Ausgang   $AUS"
echo "Behaelter $KS"
echo
echo "Das Passwort kommt von dir. Einfuegen geht in dieser Abfrage nicht --"
echo "von Hand tippen. Es fragt genau einmal (PKCS#12: Behaelter- und"
echo "Schluesselpasswort sind dasselbe)."
echo
"$SIGNER" sign --ks "$KS" --out "$AUS" "$EIN"

# **Nachsehen, nicht glauben.** Ein Rueckgabewert von 0 heisst, apksigner ist
# durchgelaufen -- nicht, dass die Signatur die ist, die wir meinen.
echo
echo "== Gegengelesen =="
"$SIGNER" verify --verbose --print-certs "$AUS"
echo
( cd "$ZIEL" && sha256sum "$(basename "$AUS")" | tee -a PRUEFSUMMEN.txt )
