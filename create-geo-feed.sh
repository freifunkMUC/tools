#!/bin/bash

# Befehlsausgabe in Variable speichern
output=$(curl -A "noc@ffmuc.net" https://bgp.tools/table.jsonl -s | grep 212567)

# Informationen zu Land und Standort
country="DE"
region="DE-BY"
city="Munich"

# CIDR-Adressen extrahieren und formatieren
while read -r line; do
    cidr=$(echo "$line" | grep -oE '[0-9.]+/[0-9]+|[0-9a-fA-F:]+/[0-9]+')
    echo "$cidr,$country,$region,$city" >> ffmuc-geo-feed.csv
done <<< "$output"

echo "CSV-Datei wurde erstellt: ffmuc-geo-feed.csv"
