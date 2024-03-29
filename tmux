#!/usr/bin/env bash
# tmux invocation wrapper

# if client, ensure use of the same tmux binary as server is using
if [[ $TMUX ]]; then
	tmuxpid=${TMUX#*,}
	tmuxpid=${tmuxpid%,*}
	/proc/$tmuxpid/exe "$@"
	exit
fi

# if server, malloc() should use madvise(MADV_HUGEPAGE), which helps
# the process to have less PTEs, so forking will be faster, which is
# good especially with large amounts of scrollback, see tmux issue 3352
#
# this variable should be unset in the global tmux environment via
# rcfile, so pane shells are not getting hugetlb malloc unless they ask
#
# the script breaks if we're not invoked by $PATH lookup (and this
# script wouldn't resolve first in PATH), we would not remove the right
# PATH element, and could invoke ourselves again, causing an infinite
# loop.  we use the glibc variable being set to tell if there's been an
# accidental nested invocation.  other uses of the variable, or server
# starts without an unset in the rcfile, would break this
#
if [[ $GLIBC_TUNABLES ]]
then echo "tmux wrapper aborting to avoid infinite loop" >&2; false; exit
else export GLIBC_TUNABLES=glibc.malloc.hugetlb=1
fi

# find the real tmux path by removing our own dir from PATH and then
# looking up the executable again.  this only works correctly if we're
# not a symlink, which is the case for us normally, being installed by
# our own installx utility.
#
savedpath=$PATH
cmdpath=${BASH_SOURCE%/*}
PATH=$(
	IFS=:
	newpath=($PATH)
	for ((i = 0; i < ${#newpath[@]}; i++))
	do if [[ ${newpath[i]} == $cmdpath ]]
	then unset 'newpath[i]'; break; fi; done
	printf "${newpath[*]}"
)
realexe=$(type -P ${0##*/})
PATH=$savedpath

$realexe "$@"
