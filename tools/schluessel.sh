#!/usr/bin/env bash
# Den Signaturschluessel fuer die Android-Fassung anlegen.
#
# **Warum es das Skript gibt.** Die keytool-Zeile ist zu lang fuer eine
# Terminalbreite, und ein Zeilenumbruch an der falschen Stelle laesst sie
# klaglos halb ausfuehren. Wichtiger aber: die Angaben darin sind
# Entscheidungen, keine Tipparbeit, und sie stehen spaeter in **jedem
# signierten APK** oeffentlich lesbar.
#
#   CN=orangedeck   nur der Projektname. Kein Klarname, kein Ort, auch kein
#                   Pseudonym, das sich mit anderen Projekten verknuepfen
#                   liesse. Entschieden am 07.09.2026.
#   RSA 4096        apksigner v2/v3 verlangen nichts Groesseres, aber der
#                   Schluessel muss laenger halten als das Projekt.
#   10000 Tage      rund 27 Jahre. Ein abgelaufenes Zertifikat heisst: keine
#                   Updates mehr, fuer niemanden.
#
# **Der Behaelter gehoert nie ins Repo**, auch nicht voruebergehend.
# Verliert man ihn, laesst sich fuer alle, die die App installiert haben,
# nie wieder ein Update ausliefern -- keine Wiederherstellung, keine Stelle,
# die hilft. Das Passwort gehoert in den Passwortspeicher, nicht in eine
# Datei daneben: sonst sichert man beides zusammen und hat nichts gewonnen.
set -euo pipefail

ZIEL="${ORANGEDECK_KEYSTORE:-$HOME/.local/share/orangedeck/signing/orangedeck.jks}"

# Niemals ueber einen bestehenden Behaelter gehen. keytool wuerde hier zwar
# nur einen zweiten Eintrag anlegen statt zu ueberschreiben -- aber "wuerde
# zwar nur" ist keine Grundlage fuer etwas, das man nicht zurueckholen kann.
[ -e "$ZIEL" ] && {
    echo "Es liegt bereits ein Behaelter: $ZIEL"
    echo "Nichts getan. Zum Ansehen:"
    echo "  keytool -list -v -keystore $ZIEL"
    exit 1
}

mkdir -p "$(dirname "$ZIEL")"
chmod 700 "$(dirname "$ZIEL")"

keytool -genkeypair -v \
    -keystore "$ZIEL" \
    -alias orangedeck \
    -keyalg RSA -keysize 4096 \
    -validity 10000 \
    -dname "CN=orangedeck"

chmod 600 "$ZIEL"

echo
echo "Angelegt: $ZIEL"
echo
echo "**Jetzt sichern.** Der Ordner liegt in beiden Sicherungen (Proton und"
echo "Stick), aber die naechste laeuft erst zum Termin. Das Passwort gehoert"
echo "in den Passwortspeicher."
echo
echo "Was drinsteht, gegenlesen:"
echo "  keytool -list -v -keystore $ZIEL | grep -E 'Alias|Inhaber|Owner|Gueltig|Valid'"
