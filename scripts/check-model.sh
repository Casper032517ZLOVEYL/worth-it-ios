#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
scratch=$(mktemp -d /tmp/worthit-model.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
clang -O1 -c '值得吗？/Astronomy/astronomy.c' -o "$scratch/astronomy.o"
clang -O1 -c '值得吗？/Astronomy/WINatal.c' -o "$scratch/natal.o"
swiftc -import-objc-header '值得吗？/Astronomy/WorthIt-Bridging-Header.h' "$scratch/astronomy.o" "$scratch/natal.o" -module-cache-path "$scratch/modules" '值得吗？/Models/Decision.swift' '值得吗？/Models/Profile.swift' '值得吗？/Models/NatalChart.swift' '值得吗？/Models/Localization.swift' '值得吗？/Models/Lottery.swift' '值得吗？/Models/SmallAction.swift' '值得吗？/Models/GuanyinModernReading.swift' '值得吗？/Models/GuanyinLot.swift' '值得吗？/Models/StarReading.swift' '值得吗？/Services/TreeHoleStore.swift' Tests/main.swift -o "$scratch/check-model"
"$scratch/check-model"
