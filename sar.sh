#!/bin/bash

file=""
[ -z $1 ] || file="-f /var/log/sa/sa$1"

sar -r $file | awk '
  # Determine where each column is set
  NR == 3 {
    for(i = 3; i <= NF; i++) {
      if( $i == "kbmemused" ) { kbmemused_col=i }
      if( $i == "kbbuffers" ) { kbbuffers_col=i }
      if( $i == "kbcached" ) { kbcached_col=i }
      if( $i == "kbmemfree" ) { kbmemfree_col=i }
      if( $i == "%commit" ) { commit_col=i }
    }
  }
  # Pluck total memory usage from addition of a random line of "free + used"
  NR == 4 {
    memtotal = $3 + $4;
  }
  # For all lines that contain an actual usage log
  NR >= 4 && $3 ~ /^[0-9]/ && $1 ~ /^[0-9]/ {
    # determine real usage from "used - (buffers+cache)"
    realusage = $kbmemused_col - ( $kbbuffers_col + $kbcached_col )
    # percentage is simply dividing by total
    {if (realusage > 0) {percentusage = (realusage / memtotal) * 100} else {percentusage=0}}
    # print real usage / total (percentage)
    printf "%s %s: %dMB / %dMB = %d%%\n", $1, $2, realusage/1000, memtotal/1000, percentusage
  }
'
