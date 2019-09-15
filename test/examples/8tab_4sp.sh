#!/bin/bash
# -*- coding: utf-8, tab-width: 8 -*-

function mix_8tab_4sp () {
    if [ "$1" -gt 5 ]; then
	if [ "$1" -lt 42 ]; then
	    nl -ba <<-'__meh__'
		Unfortunately, bash's auto-unindent for heredocs
		only works for tabs.

		Still not a reason to mix them with spaces.

		__meh__
	    fi
    fi
}

mix_8tab_4sp 23; exit $?
