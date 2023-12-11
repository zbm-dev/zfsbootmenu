#!/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

my ( $mode, $stack, $source, $line, $time, $prev_time, $diff );

GetOptions(
    "mode|m=s" => sub {
        ( undef, $mode ) = @_;
    }
);

foreach (<>) {
    chomp;
    my ( @trace, @line );

# trapdebug find_be_kernels populate_be_list main;/lib/profiling-lib.sh /lib/zfsbootmenu-core.sh /lib/zfsbootmenu-lib.sh /bin/zfsbootmenu;734 641 85 0;1695169626.438117
    @line = split( /;/, $_ );

    next unless scalar(@line) == 4;

    my @sstack  = split( / /, $line[0] );
    my @ssource = split( / /, $line[1] );
    my @slineno = split( / /, $line[2] );
    $time = $line[3];

    # the first line is free, there are no previous timestamps to use
    $prev_time //= $time;

    if ( $mode =~ m/chart/ ) {

        # Start at 1, removing trapdebug from the stack
        foreach my $i ( 1 .. $#sstack ) {
            unshift( @trace, "$sstack[$i]\@$ssource[$i]#$slineno[$i]" );
        }
    }
    elsif ( $mode =~ m/graph/ ) {

        # Start at 1, removing trapdebug from the stack
        foreach my $i ( 1 .. $#sstack ) {
            unshift( @trace, "$sstack[$i]\@$ssource[$i]" );
        }
    }

    $stack = join( ';', @trace );

    # reset prev_time to make this a no-op
    # time spent sourcing the unguarded library is unknowable to flamegraph.pl
    if ( $stack =~ m,source@/lib/profiling-lib.sh, ) {
        $prev_time = $time;
    }

# flamegraph doesn't care about units, but it does round non-integers to the nearest integer
# prefer microsecond precision so that we have sub-ms granularity
    $diff = int( ( ( $time - $prev_time ) * 1000000 ) + 1 / 2 );

    $prev_time = $time;

    print "$stack $diff\n";
}
