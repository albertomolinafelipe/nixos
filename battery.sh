perc=$(cat /sys/class/power_supply/BAT1/capacity)

# Notify at 50% battery level
if [ "$perc" -le 50 ] && [ "$perc" -gt 25 ]; then
    notify-send -u normal "Battery going down" "Your battery is at ${perc}%"
fi

# Notify at below 10% battery level
if [ "$perc" -lt 10 ]; then
    notify-send -u critical "LOW BATTERY" "Your battery is below 10%."
fi
