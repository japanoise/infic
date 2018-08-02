#!/bin/bash
# Changing the status bar
source infic.bash
infic_gamename="Status bar test"
infic_score=100
function infic_status {
	printf "Install Gentoo! %s version 1. You have %s points!" "$infic_gamename" "$infic_score"
}
infic_go
