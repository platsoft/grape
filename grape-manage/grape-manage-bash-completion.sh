#!/bin/bash

_grape_manage()
{
	commands=$(grape-manage list)

	local cur prev
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"

	COMPREPLY=( $( compgen -W "${commands}" -- ${cur} ) ) 

}

complete -o default -F _grape_manage grape-manage
