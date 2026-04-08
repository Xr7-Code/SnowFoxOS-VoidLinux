#!/bin/bash
# SnowFoxOS v3 — Polybar Launch Script
# Unterstützt mehrere Monitore

# Bestehende Polybar-Instanzen beenden
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

# Für jeden Monitor eine Polybar starten
if type "xrandr" > /dev/null 2>&1; then
    for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m polybar --reload snowfox &
    done
else
    polybar --reload snowfox &
fi
