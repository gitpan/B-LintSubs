package B::LintSubs;

use strict;
use B qw(walkoptree_slow main_root main_cv walksymtable);

our $VERSION = '0.01';

my $file = "unknown";		# shadows current filename
my $line = 0;			# shadows current line number
my $curstash = "main";		# shadows current stash
my $curcv;			# shadows current CV for current stash

my %done_cv;		# used to mark which subs have already been linted

my $exitcode = 0;

sub warning {
    my $format = (@_ < 2) ? "%s" : shift;
    warn sprintf("$format at %s line %d\n", @_, $file, $line);
}

sub lint_gv
{
    my $gv = shift;

    my $package = $gv->STASH->NAME;
    my $subname = $package . "::" . $gv->NAME;
    
    no strict 'refs';

    return if defined( &$subname );
    
    # AUTOLOADed functions will have failed here, but can() will get them
    my $coderef = UNIVERSAL::can( $package, $gv->NAME );
    return if defined( $coderef );

    # If we're still failing here, it maybe means a fully-qualified function
    # is being called at runtime in another package, that is 'require'd rather
    # than 'use'd, so we haven't loaded it yet. We can't check this.

    if( $curstash ne $package ) {
        # Throw a warning and hope the programmer knows what they are doing
        warning('Unable to check call to %s in foreign package', $subname);
        return;
    }

    $subname =~ s/^main:://;
    warning('Undefined subroutine %s called', $subname);
    $exitcode = 1;
}

sub B::OP::lint { }

sub B::COP::lint {
    my $op = shift;
    if ($op->name eq "nextstate") {
	$file = $op->file;
	$line = $op->line;
	$curstash = $op->stash->NAME;
    }
}

sub B::SVOP::lint {
    my $op = shift;
    if ($op->name eq "gv"
	&& $op->next->name eq "entersub")
    {
	lint_gv( $op->gv );
    }
}

sub B::PADOP::lint {
    my $op = shift;
    if ($op->name eq "gv"
	&& $op->next->name eq "entersub")
    {
	my $idx = $op->padix;
	my $gv = (($curcv->PADLIST->ARRAY)[1]->ARRAY)[$idx];
	lint_gv( $gv );
    }
}

sub B::GV::lintcv {
    my $gv = shift;
    my $cv = $gv->CV;
    return if !$$cv || $done_cv{$$cv}++;
    if( $cv->FILE eq $0 ) {
        my $root = $cv->ROOT;
        $curcv = $cv;
        walkoptree_slow($root, "lint") if $$root;
    }
}

sub do_lint {
    my %search_pack;

    $curcv = main_cv;
    walkoptree_slow(main_root, "lint") if ${main_root()};

    no strict qw( refs );
    walksymtable(\%{"main::"}, "lintcv", sub { 1 } );

    exit( $exitcode ) if $exitcode;
}

sub compile {
    my @options = @_;

    return \&do_lint;
}

1;
