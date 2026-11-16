#!/bin/bash
# Bygger iOS-skallet og legger det på en iPhone eller iPad uten å åpne Xcode.
# Enheten må være paret med Mac-en og nåbar (kabel eller samme Wi-Fi), og Apple-kontoen må ligge i Xcode.
# Nødvendig når noe i ios/ er endret, og hver sjuende dag med gratis Apple-konto. Endringer i nettappen trenger det ikke.
set -euo pipefail
cd "$(dirname "$0")"

# Bruk: ./install.sh [del av enhetsnavnet], f.eks. ./install.sh ipad
# Uten navn brukes første enhet som er nåbar. Enheter som står som «unavailable» hoppes over.
NAME="${1:-}"
UDID=$(xcrun devicectl list devices 2>/dev/null | grep physical | grep -v unavailable | grep -i -- "$NAME" \
  | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]+-[0-9A-F]+$/ && length($i) > 20) print $i }' | head -1)
if [ -z "$UDID" ]; then
  echo "Fant ingen nåbar enhet${NAME:+ som heter noe med «$NAME»}. Koble til med kabel, eller sjekk at den er på samme Wi-Fi og låst opp." >&2
  exit 1
fi

xcodebuild -project Speylog.xcodeproj -scheme Speylog -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build -allowProvisioningUpdates build \
  | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" || true
APP=build/Build/Products/Debug-iphoneos/Speylog.app
[ -d "$APP" ] || { echo "Bygget feilet." >&2; exit 1; }

# Installasjonen kan feile selv om bygget gikk bra, f.eks. når utviklermodus er av. Da skal skriptet si det.
if ! OUT=$(xcrun devicectl device install app --device "$UDID" "$APP" 2>&1); then
  echo "$OUT" | grep -iE "error|developer mode" | head -3 >&2
  if echo "$OUT" | grep -qi "developer mode"; then
    echo "Utviklermodus er ikke slått på på enheten: Innstillinger → Personvern og sikkerhet → Utviklermodus." >&2
  fi
  echo "Installasjonen feilet." >&2
  exit 1
fi
echo "Ferdig: Speylog er lagt på enheten."
