#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function indentation_stats () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m "$BASH_SOURCE")"
  local SELFPATH="$(dirname "$SELFFILE")"
  local SELFNAME="$(basename "$SELFFILE" .sh)"
  local INVOKED_AS="$(basename "$0" .sh)"

  local -A CFG=(
    [totals]=tabbed
    )
  local FLAG_OPTS_NAMES=(
    totals
    )
  local FILES=()
  parse_cli_opts "$@" || return $?

  readarray -t FILES < <(printf '%s\n' "${FILES[@]}" | sed -nre '
    s~^\./+~~   # for filenames given as "./--git" to avoid option
    /./p
    ' | LANG=C sort --version-sort --unique)
  [ -n "${FILES[*]}" ] || return 0$(
    echo "W: No filenames given. Try '--git'." >&2)

  local -A STATS=( [file-extras]= )
  def_file_extra multi-style '
    worded=use multiple styles of indentation.
    '
  def_file_extra binary '
    worded=were ignored because grep considered them as binary files.
    '
  local ITEM=
  for ITEM in ${STATS[file-extras]}; do STATS["$ITEM:files"]=0; done
  local -A COLS=( [names]= )
  def_col tabs '
    worded=are indented with tabs only.
    rgx=^\t+([^ \t]|$)
    '
  def_col spaces '
    worded=are indented with spaces only.
    rgx=^ +(\S|$)
    '
  def_col mixed '
    worded=have mixed indentation.
    rgx=^( +\t|\t+ )\s*([^ \t]|$)
    '
  def_col exotic '
    worded=have very exotic indentation.
    rgx=^\s*([\v\x08\x7F])
    '
  def_col min_sp '
    rgx=^ +
    rgx_metric=min_len_per_file
    aggregator=nonzero_range
    worded=spaces are the range of shortest space indentation per file.
    '
  def_col trail '
    worded=have trailing whitespace.
    rgx=\r{2,}$|[ \t\v]\r?$
    '

  cfg_flag_isset totals only || print_col_headers filename
  local FILE=
  for FILE in "${FILES[@]}"; do
    scan_one_file "$FILE" || return $?
  done

  print_summary || return $?
}


function parse_cli_opts () {
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) FILES+=( "$@" ); break;;
      --git )
        FILES+=( "$(git grep -lPe '^\s|\s$')" )
        # ^-- This works because we sort and normalize lines later
        ;;
      --totals=* | \
      --cfg:*=* )
        OPT="${OPT#--}"
        OPT="${OPT#cfg:}"
        CFG["${OPT%%=*}"]="${OPT#*=}";;
      --help | \
      -* )
        local -fp "${FUNCNAME[0]}" | guess_bash_script_config_opts-pmb
        [ "${OPT//-/}" == help ] && return 1
        echo "E: $0, CLI: unsupported option: $OPT" >&2; return 1;;
      * ) FILES+=( "$OPT" );;
    esac
  done

  local FO_KEY= FO_VAL=
  for FO_KEY in "${FLAG_OPTS_NAMES[@]}"; do
    FO_VAL="${CFG[$FO_KEY]}"
    FO_VAL="${FO_VAL//[^A-Za-z0-9_-]/,}"
    FO_VAL=",$FO_VAL,"
    CFG["$FO_KEY"]="$FO_VAL"
  done
}


function def_col () {
  local NAME="$1"; shift
  COLS[names]+=" $NAME"
  STATS["$NAME":lines]=0
  STATS["$NAME":files]=0
  COLS["$NAME":aggregator]='lnflag_sum'
  COLS["$NAME":rgx_metric]='lncnt'
  def_meta COLS "$NAME" "$@"
}


function def_file_extra {
  local NAME="$1"; shift
  STATS[file-extras]+=" $NAME"
  STATS["$NAME":files]=0
  def_meta STATS "$NAME" "$@"
}


function def_meta () {
  local DICT="$1"; shift
  local NAME="$1"; shift
  local SPEC="$*" LN=
  while [ -n "$SPEC" ]; do
    LN="${SPEC%%$'\n'*}"
    [ "$LN" == "$SPEC" ] && SPEC=
    SPEC="${SPEC#*$'\n'}"
    while [ "${LN:0:1}" == ' ' ]; do LN="${LN:1}"; done
    [ -n "$LN" ] || continue
    eval "$DICT"'["$NAME:${LN%%=*}"]="${LN#*=}"'
  done
}


function tabcells () { printf '%s\t' "$@"; }


function each_col () {
  local -A COL=()
  local COL_NAME=
  for COL_NAME in ${COLS[names]}; do
    each_col__find_details
    "$@" || return $?
  done
}

function each_col__find_details () {
  COL=( [name]="$COL_NAME" )
  local KEY=
  for KEY in "${!COLS[@]}"; do
    [[ "$KEY" == "$COL_NAME":* ]] || continue
    COL["${KEY#*:}"]="${COLS[$KEY]}"
  done
}


function print_col_headers () {
  echo -n '# '
  each_col eval tabcells '"${COL[name]}"'
  tabcells hints
  echo "$1"
}


function cfg_flag_isset () {
  local KEY="$1" FLAG="$2"
  local VAL="${CFG[$KEY]}"
  [ -n "$VAL" ] || echo "W: internal error: checking flag '$FLAG' in '$KEY'" \
    "which is not a flag set" >&2
  [[ "$VAL" == *",$2,"* ]]
}


function scan_one_file () {
  local -A FILE=( [name]="$1" [hints]= )
  each_col "$FUNCNAME"__col || return $?
  if [ -n "${FILE[binary]}" ]; then
    let STATS[binary:files]+=1
    return 0
  fi

  local STYLES=0 KEY=
  for KEY in tabs spaces mixed exotic; do
    case "${FILE[$KEY]}" in
      0 ) ;;
      '' ) echo "W: no '$KEY' counts for ${FILE[name]}!" >&2;;
      * ) let STYLES+=1;;
    esac
  done
  if [ "$STYLES" -gt 1 ]; then
    let STATS[multi-style:files]+=1
    FILE[hints]+='m'
  fi

  cfg_flag_isset totals only && return 0
  tabcells "${FILE[hints]:--}"
  echo "${FILE[name]}"
}


function scan_one_file__col () {
  [ -n "${FILE[binary]}" ] && return 0
  COL[val]=
  scan_one_file__col_rgx || return $?
  [ -n "${COL[val]}" ] || return 8$(echo "E: no value detected for column "$(
    )"'${COL[name]}', file '${FILE[name]}'" >&2)
  cfg_flag_isset totals only || tabcells "${COL[val]}"
  FILE["${COL[name]}"]="${COL[val]}"
  col_aggregate_"${COL[aggregator]}" || return $?
}


function col_aggregate_lnflag_sum () {
  let STATS["${COL[name]}:files"]+=1 || true
  let STATS["${COL[name]}:lines"]+="${COL[val]}" || true
}


function stats_set_if_empty_or () {
  local KEY="$1"; shift
  local OPER="$1"; shift
  local VAL="$1"; shift
  local OLD="${STATS[$KEY]}"
  if [ -z "$OLD" ] || [ "$OLD" $OPER "$VAL" ]; then STATS[$KEY]="$VAL"; fi
}


function col_aggregate_nonzero_range () {
  local CN="${COL[name]}" VAL="${COL[val]}"
  if [ "$VAL" != 0 ]; then
    stats_set_if_empty_or "$CN":range_min -gt "$VAL"
    stats_set_if_empty_or "$CN":range_max -lt "$VAL"
  fi
  VAL="${STATS[$CN:range_min]}..${STATS[$CN:range_max]}"
  STATS["$CN:files"]="$VAL"
  STATS["$CN:lines"]="$VAL"
}


function scan_one_file__col_rgx () {
  [ -n "${COL[rgx]}" ] || return 0
  local GREP_OUT= GREP_RV=
  # Assign GREP_OUT in extra statement to capture the return value
  # of grep, not "local".
  # Use grep -n to ensure the last printed line won't be empty and thus
  # potentially stripped by bash, and to ensure none of the matched lines
  # can look like a message line.
  GREP_OUT="$(grep -Phone "${COL[rgx]}" -- "${FILE[name]}")"
  GREP_RV="$?"
  case "$GREP_RV:$GREP_OUT" in
    0:'Binary file '*' matches' )
      FILE[binary]='yes'
      FILE[hints]+='b'
      COL[val]=0
      return 0;;
    0:* )
      local RXMT="${COL[rgx_metric]}"
      col_metric_rgx_"$RXMT" || return $?;;
    1:* ) COL[val]=0;;
    * ) echo "E: grep error in ${FILE[name]}"; return "$GREP_RV";;
  esac
}


function col_metric_rgx_lncnt () {
  COL[val]="${GREP_OUT//[^$'\n']/}:"
  COL[val]="${#COL[val]}"
}


function col_metric_rgx_min_len_per_file () {
  COL[val]="$(<<<"$GREP_OUT" sed -re '
    s~^[0-9]+:~~
    s~.~1~g
    ' | sort --numeric-sort --unique | head --lines=1 | wc --max-line-length)"
}


function summary_stat_fact () {
  echo -n "${STATS[${COL[name]}:$1]}"
  case "$2" in
    tab ) echo -n $'\t';;
    sp+arg1 ) echo -n " $1";;
  esac
}


function print_summary () {
  cfg_flag_isset totals no && return 0

  if cfg_flag_isset totals worded; then
    each_col "$FUNCNAME"__worded
    local KEY= DESCR=
    for KEY in ${STATS[file-extras]}; do
      DESCR="${STATS[$KEY:worded]}"
      [ -n "$DESCR" ] || DESCR="(no description for '$KEY')"
      echo "${STATS[$KEY:files]} files $DESCR"
    done
    return 0
  fi

  print_col_headers $'unit\tnotes'
  each_col summary_stat_fact lines tab
  echo $'*\t'"lines"

  each_col summary_stat_fact files tab
  local ITEM= EXTRAS=
  for ITEM in ${STATS[file-extras]}; do
    EXTRAS+="${STATS[$ITEM:files]} $ITEM, "
  done
  echo $'*\tfiles\t'"${EXTRAS%, }"
}


function print_summary__worded () {
  local WORDED="${COL[worded]}"
  [ -n "$WORDED" ] || WORDED="(no description for '${COL[name]}')"
  "${FUNCNAME}_${COL[aggregator]}" || return $?
}


function print_summary__worded_lnflag_sum () {
  summary_stat_fact lines sp+arg1
  echo -n ' in '
  summary_stat_fact files sp+arg1
  echo " $WORDED"
}


function print_summary__worded_nonzero_range () {
  local CN="${COL[name]}"
  echo "${STATS[$CN:range_min]}..${STATS[$CN:range_max]} $WORDED"
}













indentation_stats "$@"; exit $?
