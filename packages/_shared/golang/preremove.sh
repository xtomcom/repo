#!/bin/sh
# $1 is 0 on erase, 1 on upgrade.
if [ "$1" = 0 ]; then
  # Not fatal: dnf aborts the removal if the entry is already gone.
  /usr/sbin/update-alternatives --remove go /usr/lib/go-@BRANCH@/bin/go || :
fi
