#!/bin/bash
# SnowFoxOS v3 — Lock Screen

LOCKCOLOR="#0f0f0f"
TEXTCOLOR="#e8e8e8ff"
ACCENT="#9B59B6ff"
WRONG="#E67E22ff"
VERIFY="#9B59B6ff"

i3lock \
    --color="${LOCKCOLOR:1}" \
    --inside-color="${LOCKCOLOR:1}ff" \
    --insidever-color="${LOCKCOLOR:1}ff" \
    --insidewrong-color="${LOCKCOLOR:1}ff" \
    --ring-color="${ACCENT}" \
    --ringver-color="${VERIFY}" \
    --ringwrong-color="${WRONG}" \
    --line-uses-ring \
    --keyhl-color="${ACCENT}" \
    --bshl-color="${WRONG}" \
    --separator-color="${ACCENT}" \
    --verif-color="${TEXTCOLOR}" \
    --wrong-color="${WRONG}" \
    --time-color="${TEXTCOLOR}" \
    --date-color="${TEXTCOLOR}" \
    --greeter-color="${ACCENT}" \
    --time-str="%H:%M" \
    --date-str="%a, %d.%m.%Y" \
    --verif-text="..." \
    --wrong-text="Falsch" \
    --noinput-text="" \
    --lock-text="" \
    --lockfailed-text="Fehler" \
    --radius=80 \
    --ring-width=4 \
    --clock \
    --indicator \
    --nofork
