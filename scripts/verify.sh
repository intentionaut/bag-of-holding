#!/bin/sh
# Checks the three promises in the README against the built app and the source.
# Usage: scripts/verify.sh [path/to/app]   Exits 1 if any promise fails.
set -u
cd "$(dirname "$0")/.."
app="${1:-build/Bag of Holding.app}"
[ -d "$app" ] || { echo "No app at $app. Run ./build.sh first."; exit 2; }
fail=0
check() { if [ "$2" = ok ]; then echo "PASS  $1"; else echo "FAIL  $1: $2"; fail=1; fi; }
found() { grep -rEn "$@" Sources || true; }

ents=$(codesign -d --entitlements - --xml "$app" 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null)
[ -n "$ents" ] || { echo "Could not read entitlements from $app"; exit 2; }
keys=$(printf '%s' "$ents" | grep -o '<key>[^<]*</key>' | sed 's/<[^>]*>//g' | sort | tr '\n' ' ')
expected="com.apple.security.app-sandbox com.apple.security.files.user-selected.read-only "

# 1. No network. The sandbox blocks network access unless an entitlement grants it.
net=$(printf '%s' "$keys" | grep -i network)
# The tip link is allowed: it opens in your browser, not in the app.
api=$(found 'URLSession|NWConnection|import Network|CFNetwork|CFSocket|https?://' | grep -v '"https://ko-fi.com/intentionaut"' || true)
check "No network: no network entitlement" "$([ -z "$net" ] && echo ok || echo "$net")"
check "No network: no networking code in Sources" "$([ -z "$api" ] && echo ok || echo "$api")"

# 2. No analytics, no accounts.
spy=$(found -i 'analytic|telemetr|tracking|login|password|Keychain|AuthenticationServices|CloudKit|iCloud')
check "No analytics or accounts in Sources" "$([ -z "$spy" ] && echo ok || echo "$spy")"

# 3. Reads only what you hand it; writes only inside the bag.
check "Entitlements are exactly sandbox + read-only access to files you pick" \
  "$([ "$keys" = "$expected" ] && echo ok || echo "found: $keys")"
destroy=$(found 'removeItem|moveItem|trashItem|replaceItem|setAttributes' | grep -v '^Sources/BagCore/Bag.swift:' || true)
check "No code outside Bag.swift deletes, moves or edits files" "$([ -z "$destroy" ] && echo ok || echo "$destroy")"
removes=$(grep -cE 'removeItem' Sources/BagCore/Bag.swift)
others=$(grep -E '[^e]moveItem|trashItem|replaceItem|setAttributes' Sources/BagCore/Bag.swift || true)
check "Bag.swift deletes only in remove(), from the bag folder" \
  "$([ "$removes" = 1 ] && [ -z "$others" ] && grep -q 'deletingLastPathComponent() == folder' Sources/BagCore/Bag.swift && echo ok || echo "removeItem x$removes $others")"
writers=$(grep -rlE 'copyItem|write\(to:|createFile' Sources | grep -v '^Sources/BagCore/Bag.swift$' || true)
check "Only Bag.swift writes files" "$([ -z "$writers" ] && echo ok || echo "$writers")"

exit $fail
