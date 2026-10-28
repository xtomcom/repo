#!/bin/sh
# $1 is 0 on erase, 1 on upgrade.
if [ "$1" = 0 ]; then
  /usr/sbin/update-alternatives --remove go /usr/lib/golang/bin/go
fi
