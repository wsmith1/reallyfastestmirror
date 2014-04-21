#!/usr/bin/perl -wT
use strict;
use warnings;
use IO::File ();

my $speedtest_report_path = $ARGV[0];
my $mirrorlist_path = $ARGV[1];

my %MIRRORS_SPEEDS = ();
my %MIRROR_HASH = ();
my @MIRROR_ARRAY = ();

my $msp_fh = IO::File->new("< $speedtest_report_path") || die;
while (my $line_raw = <$msp_fh>) {
    my $line = $line_raw;
    chomp ($line);

    if ($line =~ m,\s+(\d+(?:\.\d+))\s+((?:http|ftp)://[^/@]+),) {
        $MIRRORS_SPEEDS{$2} = $1;
    }
}

$msp_fh->close();
$msp_fh = undef;

my $fh = IO::File->new("< $mirrorlist_path") || die;




while (my $line_raw = <$fh>) {
    my $line = $line_raw;
    chomp ($line);
    if ($line =~ m,^#,) {
        print $line_raw;
    }
    elsif ($line =~ m,^((?:http|ftp)://[^/@]+)(/[^ ]*),) {
        $MIRROR_HASH{$1} = $line;
        if (!exists($MIRRORS_SPEEDS{$1})) {
            $MIRRORS_SPEEDS{$1} = 0;
        }
    }
    else {
        # Nothing
    }
}

$fh->close();
$fh = undef;

@MIRROR_ARRAY = sort { $MIRRORS_SPEEDS{$b} <=> $MIRRORS_SPEEDS{$a} } keys %MIRROR_HASH;
print "# speed ranking\n";
foreach my $m (@MIRROR_ARRAY) {
    print sprintf ("# %15.3f    %s\n", $MIRRORS_SPEEDS{$m}, $MIRROR_HASH{$m});
}
print "# speed ranking ends\n";
foreach my $m (@MIRROR_ARRAY) {
    print "$MIRROR_HASH{$m}\n";
}

