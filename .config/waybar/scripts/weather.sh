#!/usr/bin/bash

CITY="Torrance"

# Step 1: Use Open-Meteo Geocoding API to resolve city → lat/lon
geo=$(curl -s "https://geocoding-api.open-meteo.com/v1/search?name=${CITY}&count=1&language=en&format=json")

lat=$(echo "$geo" | jq '.results[0].latitude')
lon=$(echo "$geo" | jq '.results[0].longitude')

# Step 2: Fetch current weather for that location
json=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true")

temp=$(echo "$json" | jq '.current_weather.temperature')
code=$(echo "$json" | jq '.current_weather.weathercode')
wind=$(echo "$json" | jq '.current_weather.windspeed')

# Step 3: Map weather code → icon & condition
case $code in
  0) icon="☀️"; condition="Clear sky" ;;
  1|2) icon="🌤️"; condition="Mainly clear" ;;
  3) icon="☁️"; condition="Cloudy" ;;
  45|48) icon="🌫️"; condition="Fog" ;;
  51|53|55) icon="🌦️"; condition="Drizzle" ;;
  61|63|65) icon="🌧️"; condition="Rain" ;;
  71|73|75) icon="❄️"; condition="Snow" ;;
  95) icon="⛈️"; condition="Thunderstorm" ;;
  *) icon="❔"; condition="Unknown" ;;
esac

echo $CITY ${temp}°C $condition $icon 
