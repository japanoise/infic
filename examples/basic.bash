#!/bin/bash
# Basic example
source infic.bash

infic_gamename="Sitting Home Alone"

declare -A exroom
exroom[light]=1
exroom[name]='echo Bedroom'
exroom[description]='printf "%s\n" "What a cosy, lovely room." "" "North leads to the landing."'
exroom[north]=landing

declare -A landing
landing[light]=1
landing[name]='echo "The landing"'
landing[description]='echo "A bit beat up, but it'"'"'s home. The clock reads $(date +%T)."'
landing[south]=exroom

infic_player[parent]=exroom

infic_intro="Sitting home alone after a crappy show; no-one showed up like they said they would..."

infic_go
