#!/bin/bash
# Writes ffmuc-geo-feed.csv (RFC 8805) for the prefixes of AS212567 seen at bgp.tools.
# Default location is Munich. geo-feed-overrides.csv (optional, next to this script,
# same format as the output) replaces the line of an equal prefix or is inserted
# right after its covering prefix. Output order: IPv4, then IPv6, by address.
set -euo pipefail

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
overrides="$dir/geo-feed-overrides.csv"
out="${1:-ffmuc-geo-feed.csv}"
default="DE,DE-BY,Munich,"

# Address of a CIDR as a bit string (32 or 128 characters).
bits() {
    local addr=${1%/*} b="" part o g
    if [[ $addr == *:* ]]; then
        local head=${addr%%::*} tail="" groups=() hg=() tg=()
        [[ $addr == *::* ]] && tail=${addr#*::}
        IFS=: read -ra hg <<< "$head"
        [[ $addr == *::* ]] && IFS=: read -ra tg <<< "$tail"
        groups=("${hg[@]}")
        if [[ $addr == *::* ]]; then
            for ((o = ${#hg[@]} + ${#tg[@]}; o < 8; o++)); do groups+=(0); done
            groups+=("${tg[@]}")
        fi
        for g in "${groups[@]}"; do
            for ((o = 15; o >= 0; o--)); do b+=$(((16#$g >> o) & 1)); done
        done
    else
        IFS=. read -ra part <<< "$addr"
        for g in "${part[@]}"; do
            for ((o = 7; o >= 0; o--)); do b+=$(((g >> o) & 1)); done
        done
    fi
    echo "$b"
}

# covers <outer cidr> <inner cidr>: inner lies within outer (and is not equal).
covers() {
    local ol=${1#*/} il=${2#*/} ob ib
    ob=$(bits "$1")
    ib=$(bits "$2")
    [ "${#ob}" -eq "${#ib}" ] && [ "$ol" -lt "$il" ] && [ "${ob:0:ol}" = "${ib:0:ol}" ]
}

mapfile -t ovr < <(grep -vE '^\s*(#|$)' "$overrides" 2>/dev/null || true)

table=$(curl -A "noc@ffmuc.net" https://bgp.tools/table.jsonl -s | grep 212567 || true)

# sort key: family (bit length), address bits, prefix length
mapfile -t cidrs < <(
    grep -oE '[0-9.]+/[0-9]+|[0-9a-fA-F:]+/[0-9]+' <<< "$table" | sort -u |
        while read -r c; do b=$(bits "$c"); echo "${#b} $b ${c#*/} $c"; done |
        sort -k1,1n -k2,2 -k3,3n | cut -d' ' -f4
)

: > "$out.tmp"
for c in "${cidrs[@]}"; do
    line="$c,$default"
    for o in "${ovr[@]}"; do [ "${o%%,*}" = "$c" ] && line=$o; done
    echo "$line" >> "$out.tmp"
    for o in "${ovr[@]}"; do
        covers "$c" "${o%%,*}" && echo "$o" >> "$out.tmp"
    done
done
mv "$out.tmp" "$out"

echo "CSV-Datei wurde erstellt: $out"
