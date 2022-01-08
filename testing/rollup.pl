#!/bin/perl

use strict;
use warnings;
use Data::Dumper;

my ($stack, $source, $time, $prev_time, $diff);

foreach (<>) {
  chomp;

  # trapdebug kexec_kernel main;/lib/profiling-lib.sh /lib/zfsbootmenu-core.sh /libexec/zfsbootmenu-init;1641848253.018649
  ($stack, $source, $time) = split(/;/, $_);

  # the first line is free, there are no previous timestamps to use
  $prev_time //= $time;

  my @sstack = split(/ /, $stack);
  my @ssource = split(/ /, $source);

  my @trace;

  # Start at 1, removing trapdebug from the stack
  foreach my $i (1 .. $#sstack) {
    unshift (@trace, "$sstack[$i]\@$ssource[$i]");
  }

  $stack = join(';', @trace);

  # reset prev_time to make this a no-op
  # time spent sourcing the unguarded library is unknowable to flamegraph.pl
  if ( $stack =~ m,source@/lib/profiling-lib.sh, ) {
    $prev_time = $time;
  }

  # flamegraph doesn't care about units, but it does round non-integers to the nearest integer
  # prefer microsecond precision so that we have sub-ms granularity
  $diff = int((( $time - $prev_time ) * 1000000 ) + 1/2);

  $prev_time = $time;

  print "$stack $diff\n";
}
