#!/bin/sh
/usr/sbin/update-alternatives --install /usr/bin/go go /usr/lib/golang/bin/go 90 \
  --slave /usr/bin/gofmt gofmt /usr/lib/golang/bin/gofmt
