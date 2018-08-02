#!/bin/bash
# infic.bash - An interactive fiction library for bash, loosely based on Inform

# Check for bash 4
if ((BASH_VERSINFO[0] < 4)); then echo "Sorry, you need at least bash-4.0 to run this script." >&2; exit 1; fi

################################################################################
# Global variables                                                             #
################################################################################

declare -r infic_version="0.1"
infic_gamename="infic version $infic_version"
infic_score=0
declare -A infic_parseresult
declare -A infic_player
declare infic_intro

################################################################################
# Drawing functions                                                            #
################################################################################

# Use a CSI escape code
function infic_csi {
    printf "\033[%s" "$1"
}

# Use an SGR escape code
function infic_sgr {
    infic_csi "${1}m"
}

# Initialise the screen
function infic_screen_init {
    infic_csi "2J" # Clear entire screen
    infic_csi "2;1H" # Jump to second row, first column
}

# Print the status line
# You can override this function to change the contents of the status line
function infic_status {
    printf "%s | Score: %s" "$infic_gamename" "$infic_score"
}

# Update the screen
function infic_screen_update {
    local cols
    cols="$(tput cols)"
    infic_csi "s" # Save cursor
    infic_csi "${cols}D" # Move cursor to BOL
    infic_csi "$(( $(tput lines) - $1 ))A" # Move cursor to the top row
    infic_csi "K" # Clear line
    infic_sgr "7" # Reverse video
    # Magic sed command from here: https://stackoverflow.com/a/19987527
    printf -v TC_SPC "%${cols}s" ''
    infic_status | sed "s/$/$TC_SPC/;s/^\\(.\\{${cols}\\}\\) */\\1/"
    infic_sgr "0" # Attributes off
    infic_csi "u" # Restore cursor
}

# Some formatting directives

function infic_bold_on {
    infic_sgr "1"
}

function infic_italic_on {
    infic_sgr "3"
}

function infic_reverse_on {
    infic_sgr "7"
}

function infic_reset {
    infic_sgr "0"
}

################################################################################
# Parser functions                                                             #
################################################################################

# Prints the parseresult assocarray
function infic_debug_parse {
    for key in "${!infic_parseresult[@]}"
    do
	echo "$key ${infic_parseresult[$key]}"
    done
}

# Clears the parseresult assocarray
function infic_clear_parse {
    for key in "${!infic_parseresult[@]}"
    do
	infic_parseresult["$key"]=""
    done
}

# infic_parse(words...)
# Takes a list of words; parses them and puts the result in $infic_parseresult
# Returns 0 if successful, non-zero and print issue otherwise
function infic_parse {
    case "${1,,}" in
	l|look )
	    infic_parseresult[verb]="look"
	    return 0;;
	q|quit )
	    infic_parseresult[verb]="quit"
	    return 0;;
	i|inv|inventory )
	    infic_parseresult[verb]="inventory"
	    return 0;;
	t|take )
	    infic_parseresult[verb]="take"
	    shift
	    if [ -z "$*" ]; then
		echo "Take what?"
		return 1
	    else
		infic_parseresult[object]="${*,,}"
		return 0
	    fi;;
	g|go )
	    infic_parseresult[verb]="go"
	    shift
	    if [ -z "$*" ]; then
		echo "Go where (which direction)?"
		return 1
	    else
		infic_parseresult[dir]="${*,,}"
		return 0
	    fi;;
	north|n )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="north"
	    return 0;;
	south|s )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="south"
	    return 0;;
	northeast|north-east|ne )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="north-east"
	    return 0;;
	southeast|south-east|se )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="south-east"
	    return 0;;
	northwest|north-west|nw )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="north-west"
	    return 0;;
	southwest|south-west|sw )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="south-west"
	    return 0;;
	east|e )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="east"
	    return 0;;
	west|w )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="west"
	    return 0;;
	up|u )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="up"
	    return 0;;
	down|d )
	    infic_parseresult[verb]="go"
	    infic_parseresult[dir]="down"
	    return 0;;
	examine|ex )
	    infic_parseresult[verb]="examine"
	    shift
	    if [ -z "$*" ]; then
		echo "Examine what?"
		return 1
	    else
		infic_parseresult[object]="${*,,}"
		return 0
	    fi;;
	drop )
	    infic_parseresult[verb]="drop"
	    shift
	    if [ -z "$*" ]; then
		echo "Drop what?"
		return 1
	    else
		infic_parseresult[object]="${*,,}"
		return 0
	    fi;;
	fuck|shit|piss|motherfucker|god|goddamn|damn|hell )
	    echo "There's really no need for that kind of language."
	    return 0;;
	* ) echo "I don't understand."; return 1;;
    esac
}

################################################################################
# Game logic                                                                   #
################################################################################

# infic_property(object, property)
# Get the property of the given object.
function infic_property {
     eval echo "\${$1[$2]}"
}

# infic_set_property(object, property, val)
# Set the property of the given object to val.
function infic_set_property {
     eval "$1[$2]=\"$3\""
}

# infic_has(object, property)
# Does an object have a property?
function infic_has {
    test ! -z "$(infic_property "$1" "$2")"
    return $?
}

# infic_exec_property(object, property)
# Run the code stored in the given object's property
function infic_exec_property {
	eval "$(infic_property "$1" "$2")"
}

# Get the player's current room
function infic_cur_room {
    infic_property infic_player parent
}

# Describes the room the player is in
function infic_roomdesc {
    room="$(infic_cur_room)"
    if [ -z "$room" ] || ! infic_has "$room" light
    then
	infic_bold_on
	echo "The darkness"
	infic_reset
	printf "\nIt is pitch black. You can't see a thing."
    else
	infic_bold_on
	infic_exec_property "$room" name
	infic_reset
	printf "\n"
	infic_exec_property "$room" description
    fi
}

# Does one action based on what's in the parser results
function infic_run {
    case "${infic_parseresult[verb]}" in
	look ) infic_roomdesc;;
	examine ) echo "Looks normal to me.";;
	go ) if infic_has "$(infic_cur_room)" "${infic_parseresult[dir]}"
	     then
		 infic_set_property infic_player parent "$(infic_property "$(infic_cur_room)" "${infic_parseresult[dir]}")"
		 infic_roomdesc
	     else
		 echo "You can't go that way"
	     fi;;
	take ) echo "You see no such thing.";;
	inventory ) echo "You are carrying nothing.";;
	drop ) echo "You aren't carrying any such thing.";;
    esac
}

################################################################################
# Game loop                                                                    #
################################################################################

# Run one iteration of the game
function infic_iter {
    printf "\n"
    if read -p ">" -rea infic_cmd
    then
	test -z "$infic_cmd" && return 0
	if infic_parse "${infic_cmd[@]}"
	then
	    if [ "${infic_parseresult[verb]}" = "quit" ]
	    then
		return 1
	    fi
	fi
	infic_run
	infic_clear_parse
    else
	# Probably EOF, so send a newline
	printf "\n"
	return 1
    fi
}

# Run this function to start the game once you're done setting up
function infic_go {
    infic_screen_init
    printf "%s\n\n" "$infic_intro"
    infic_roomdesc
    while true
    do
	infic_screen_update 2
	if ! infic_iter; then
	    infic_screen_update 1
	    read -rep "Really quit (y/n)? " quit
	    case "$quit" in
		y*|Y* ) exit 0;;
	    esac
	fi
    done
}
# infic.bash ends here
