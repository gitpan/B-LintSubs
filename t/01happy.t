#!/usr/bin/perl

use Test::More tests => 1;

my $perl = $ENV{PERL} || "perl";

sub lintsubs
{
   return system( $perl, '-MO=LintSubs', '-e', @_ );
}

is( lintsubs( 'print q{I am happy}' ), 0, 'Simple print line' );
