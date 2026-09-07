#!/usr/bin/env bash
# Das Android-Paket aus einem beliebigen Stand bauen.
#
# **Warum es das Skript gibt.** Am 06.09.2026 wurde das APK aus `v0.2.0`
# gebaut, und der Bau scheiterte zweimal an Dingen, die nirgends standen:
#
#   1. `QT_HOST_PATH` fehlt. Ohne es meldet CMake nur "Qt6_FOUND to FALSE",
#      und der Grund steht zwoelf Zeilen weiter oben im Protokoll.
#   2. `build-openssl-android/` liegt **ausserhalb** des Repos. Ein frischer
#      Arbeitsbaum hat es nicht, und dann entsteht klaglos ein APK **ohne
#      TLS** -- auf dem Geraet vollstaendig funktionslos, weil mempool.space
#      nur https und wss spricht. Der Bau meldet keinen Fehler.
#
# Beides ist eine Umgebung, kein Wissen. Umgebungen gehoeren in eine Datei.
#
#     tools/apk.sh              aus dem Arbeitsbaum bauen
#     tools/apk.sh v0.2.0       aus einem Tag oder Commit bauen
#
# Das Ergebnis liegt unter ~/.local/share/orangedeck/auslieferung/ -- **nicht**
# im Kratzverzeichnis der Sitzung. Am 05.09.2026 lag die Pruef-VM dort und war
# am naechsten Tag weg; derselbe Fehler zweimal ist einer zu viel.
#
# Und **nicht** unter ~/.cache/: dort lag es bis zum 07.09.2026, und die
# Ausschlussliste der Sicherung beginnt mit genau dieser Zeile. Ein Paket,
# das ausgeliefert werden soll, ist kein Zwischenspeicher.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT="${ORANGEDECK_QT_ANDROID:-$HOME/Qt/6.11.2/android_arm64_v8a}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$(ls -d "$ANDROID_SDK_ROOT"/ndk/* 2>/dev/null | sort -V | tail -1)}"
ZIEL="${ORANGEDECK_APK_DIR:-$HOME/.local/share/orangedeck/auslieferung}"
STAND="${1:-}"

for p in "$QT/bin/qt-cmake" "$ANDROID_SDK_ROOT" "$ANDROID_NDK_ROOT"; do
    [ -e "$p" ] || { echo "fehlt: $p"; exit 1; }
done
[ -e "$REPO/build-openssl-android" ] || {
    echo "fehlt: $REPO/build-openssl-android -- erst tools/openssl-android.sh"; exit 1; }

if [ -n "$STAND" ]; then
    BAUM="$(mktemp -d)/orangedeck"
    git -C "$REPO" worktree add --detach "$BAUM" "$STAND^{}" >/dev/null
    # Der Baum aus der Historie kennt OpenSSL nicht -- es liegt ausserhalb.
    ln -sfn "$REPO/build-openssl-android" "$BAUM/build-openssl-android"
    aufraeumen() { git -C "$REPO" worktree remove --force "$BAUM" 2>/dev/null || true; }
    trap aufraeumen EXIT
else
    BAUM="$REPO"
fi
echo "== Stand: $(git -C "$BAUM" log --oneline -1) =="

"$QT/bin/qt-cmake" -S "$BAUM" -B "$BAUM/build-android" \
    -DCMAKE_BUILD_TYPE=Release -DQT_ANDROID_ABIS=arm64-v8a \
    -DQT_HOST_PATH=/usr -DQT_HOST_PATH_CMAKE_DIR=/usr/lib/cmake \
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
cmake --build "$BAUM/build-android" --target apk -j"$(nproc)"

APK="$BAUM/build-android/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"
[ -f "$APK" ] || { echo "kein APK entstanden"; exit 1; }

# **Nachsehen, nicht glauben.** Ein APK ohne TLS sieht aus wie eines mit.
n=$(unzip -l "$APK" | grep -cE "libssl|libcrypto" || true)
[ "$n" -ge 2 ] || { echo "APK OHNE TLS ($n Bibliotheken) -- nicht ausliefern"; exit 1; }
fassung=$(unzip -p "$APK" AndroidManifest.xml | strings -el | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+$" | head -1)

mkdir -p "$ZIEL"
name="orangedeck-${fassung:-unbekannt}-arm64-v8a-unsigniert.apk"
cp "$APK" "$ZIEL/$name"
( cd "$ZIEL" && sha256sum "$name" >> PRUEFSUMMEN.txt )
echo
echo "  $ZIEL/$name"
echo "  Fassung $fassung, TLS an Bord ($n Bibliotheken)"
echo
echo "Signieren (Schluessel und Passwort kommen von dir):"
echo "  \"\$ANDROID_SDK_ROOT\"/build-tools/*/apksigner sign \\"
echo "      --ks ~/.local/share/orangedeck/signing/orangedeck.jks \\"
echo "      --out $ZIEL/orangedeck-$fassung-arm64-v8a.apk \\"
echo "      $ZIEL/$name"
