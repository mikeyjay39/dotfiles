#!/usr/bin/env bash

# fetch JSON containing many exchange rates with USD as base
json=$(curl -s "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")

# extract the HUF rate
rate=$(echo "$json" | jq -r ".usd.huf")

# optionally format
printf "🇺🇸 -> %.2f 🇭🇺" "$rate"
