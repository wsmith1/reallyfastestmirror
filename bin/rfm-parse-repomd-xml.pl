#!/usr/bin/perl -wT

use strict;
use warnings;
use IO::File ();

my $repomd_path = $ARGV[0];

my $repomd_xml_header_present = 0;
my $webfilter_mark_present = 0;

my $data_type = '';

my $location_primary = '';
my $location_primary_db = '';

my $valid_code = 'BAD';
my $valid_num = 0;


my $fh = IO::File->new("< $repomd_path") || die;
while (my $line_raw = <$fh>) {
    my $line = $line_raw;
    chomp ($line);

    if ($line =~ m,<repomd\s+xmlns\s*=\s*"http://linux.duke.edu/metadata/repo"\s*[^>]*>, ) {
        $repomd_xml_header_present = 1;
        next;
    }

    ## Check webfilter mark here if $repomd_xml_header_present is not set

    if ($repomd_xml_header_present) {
        if ($line =~ m,<\s*data\s+type\s*=\s*"([^"]+)", ) {
            $data_type = $1;
        }
        elsif ($line =~ m,</data>, ) {
            $data_type = '';
        }
        elsif ($data_type ne '' && ($line =~ m,<location\s+href\s*=\s*"([^"]+)"\s*/\s*>,) ) {
            if ($data_type eq 'primary') {
                $location_primary = $1;
            }
            if ($data_type eq 'primary_db') {
                $location_primary_db = $1;
            }
        }
        else {
            # Nothing
        }
    }
}

if ($repomd_xml_header_present && ( $location_primary || $location_primary_db ) ) {
    $valid_code = 'GOOD';
    $valid_num = 1;
}
elsif ($webfilter_mark_present) {
    $valid_code = 'FILTERED';
}
else {
    $valid_code = 'BAD';
}

print "repomd_xml_valid=$valid_num\n";
print "repomd_xml_valid_code=$valid_code\n";
print "repomd_xml_primary=$location_primary\n";
print "repomd_xml_primary_db=$location_primary_db\n";

1;
