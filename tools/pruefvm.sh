#!/usr/bin/env bash
# Die Pruef-VM aufbauen und starten.
#
# **Warum es das Skript gibt.** Am 04.09.2026 wurde die VM von Hand
# zusammengesetzt, und alles lag im Kratzverzeichnis der Sitzung: die
# 12-GB-Platte, die Buendel, die ISO. Einen Tag spaeter war nichts davon mehr
# da -- dieselbe Ursache, die auch `tools/vm.py` auf einen toten Pfad zeigen
# liess. Was man wieder braucht, muss man wieder herstellen koennen, ohne es
# aus einem Fliesstext zu rekonstruieren.
#
# Alles landet unter $ORANGEDECK_VM_DIR (Vorgabe ~/.cache/orangedeck-vm),
# demselben Ort, den `tools/vm.py` fuer den Monitor-Sockel nimmt.
#
#     tools/pruefvm.sh bauen     Buendel, Daten-ISO und Platte herstellen
#     tools/pruefvm.sh starten   QEMU starten (ohne Fenster, Monitor am Sockel)
#     tools/pruefvm.sh anhalten  QEMU beenden
#
# Danach steuert `tools/vm.py` den Gast: Tasten senden, Bilder holen.
set -euo pipefail

VM="${ORANGEDECK_VM_DIR:-$HOME/.cache/orangedeck-vm}"
ISO="${ORANGEDECK_VM_ISO:-$HOME/VMs/ubuntu-24.04.4.iso}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# **Die Live-Sitzung schreibt in den RAM.** Deshalb liegt der Flatpak-Bestand
# im Gast auf dieser Platte, nicht im Overlay -- siehe DOKUMENTATION,
# "Pruefen in einer Live-Sitzung".
PLATTE_GB="${ORANGEDECK_VM_DISK_GB:-12}"
RAM_MB="${ORANGEDECK_VM_RAM_MB:-2560}"

mkdir -p "$VM"

bauen() {
    echo "== Anwendung buendeln =="
    local bau="$VM/bau"
    rm -rf "$bau" "$VM/repo"
    flatpak-builder --user --repo="$VM/repo" --force-clean --disable-cache \
        --state-dir="$VM/state" "$bau" \
        "$REPO/packaging/flatpak/store._21rebel.orangedeck.yml"
    flatpak build-bundle "$VM/repo" "$VM/daten/orangedeck.flatpak" \
        store._21rebel.orangedeck \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

    # **Die Laufzeit muss mit.** Im Gast bricht die Netzverbindung zu Flathub
    # reihenweise ab, und ohne die GL-Erweiterung startet die Anwendung mit
    # "Could not initialize GLX" -- wer von Flathub installiert, bekommt sie
    # automatisch, ein Buendel bringt sie nicht mit.
    echo "== Laufzeit und GL-Erweiterung buendeln =="
    flatpak build-bundle --runtime ~/.local/share/flatpak/repo \
        "$VM/daten/kde-platform-6.9.flatpak" org.kde.Platform 6.9 \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
    flatpak build-bundle --runtime ~/.local/share/flatpak/repo \
        "$VM/daten/gl-default-24.08.flatpak" org.freedesktop.Platform.GL.default 24.08 \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

    # Die Pruefsummen wandern mit auf die ISO: im Gast wird gegengehalten,
    # bevor man dem Ergebnis glaubt.
    ( cd "$VM/daten" && sha256sum ./*.flatpak > PRUEFSUMMEN.txt )
    echo "== Daten-ISO =="
    xorriso -as mkisofs -V ORANGEDECK -J -r -o "$VM/daten.iso" "$VM/daten"
    echo "== Platte =="
    [ -f "$VM/vmdisk.qcow2" ] || qemu-img create -f qcow2 "$VM/vmdisk.qcow2" "${PLATTE_GB}G"
    ls -la "$VM"/daten.iso "$VM"/vmdisk.qcow2
}

starten() {
    [ -f "$ISO" ] || { echo "Keine Ubuntu-ISO unter $ISO (ORANGEDECK_VM_ISO setzt den Pfad)"; exit 1; }
    [ -f "$VM/daten.iso" ] || { echo "Keine Daten-ISO -- erst 'tools/pruefvm.sh bauen'"; exit 1; }
    rm -f "$VM/mon.sock"
    # **Zwei Laufwerke von Anfang an.** Am 04.09. wurde das Medium im Betrieb
    # getauscht; der Gast lieferte danach weiter den alten Inhalt aus dem
    # Cache, `ls` zeigte schon den neuen Namen. Wer beide ISOs gleich
    # einhaengt, hat die Falle nicht.
    qemu-system-x86_64 -enable-kvm -m "$RAM_MB" -smp 2 -cpu host \
        -drive file="$ISO",media=cdrom,readonly=on \
        -drive file="$VM/daten.iso",media=cdrom,readonly=on \
        -drive file="$VM/vmdisk.qcow2",if=virtio,format=qcow2 \
        -vga std -display none \
        -monitor "unix:$VM/mon.sock,server,nowait" \
        -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -boot d \
        > "$VM/qemu.log" 2>&1 &
    echo "QEMU gestartet (PID $!), Monitor: $VM/mon.sock"
    echo "Steuern mit tools/vm.py -- der nimmt denselben Ort."
}

anhalten() {
    pkill -f "monitor unix:$VM/mon.sock" 2>/dev/null || pkill -f 'qemu-system-x86_64.*orangedeck-vm' 2>/dev/null || true
    echo "angehalten"
}

case "${1:-}" in
    bauen)    bauen ;;
    starten)  starten ;;
    anhalten) anhalten ;;
    # Die Hilfe ist der Kopf der Datei -- bis zur ersten Zeile, die keine
    # Kommentarzeile mehr ist. Eine feste Zeilenzahl waere beim naechsten
    # eingefuegten Absatz falsch und haette Code mit ausgegeben.
    *) sed -n '2,${/^#/!q;s/^# \{0,1\}//p;}' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
