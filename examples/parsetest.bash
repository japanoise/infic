#!/bin/bash
source infic.bash

function infic_test {
	infic_parse $*
	infic_debug_parse
	infic_clear_parse
}

echo "Intransitive verbs:               inventory"
infic_test inventory
echo "Transitive verbs:                 take lantern"
infic_test take lantern
echo "Transitive verbs w/ long objects: take the brass lantern"
infic_test take the brass lantern
echo "Directional abbreviations:        n"
infic_test n
