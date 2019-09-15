#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function update_demo () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m "$BASH_SOURCE")"
  local SELFPATH="$(dirname "$SELFFILE")"
  cd -- "$SELFPATH"/../.. || return $?

  local PROG='indentation-stats-pmb'
  local HOWTO="${SELFFILE%.upd.sh}.txt"
  (
    howto --git --totals=only,worded
    howto --git --totals=only
    howto --git
    howto --git --totals=no
    echo '# -*- coding: utf-8, tab-width: 8 -*-'
  ) >"$HOWTO" || return $?
}


function howto () {
  echo -n '$'
  printf ' %s' "$PROG" "$@"
  echo
  ./ista.sh "$@"
  echo
}



update_demo "$@"; exit $?
