#!/bin/bash
NODELIST=$(sinfo -N -h -o "%N" | tr '\n' ',' | sed 's/,$//')
if [ -n "$NODELIST" ]; then
    sudo scontrol update nodename="$NODELIST" state=idle
else
    echo "No nodes found by sinfo."
fi
