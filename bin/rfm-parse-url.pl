#!/usr/bin/perl -wT
use strict;
use warnings;

my $fullurl=$ARGV[0];
my $proto = '';
my $host = '';
my $path = '';
my $url = '';

$fullurl =~ s/^\s+//;
$fullurl =~ s/\s+$//;

if ($fullurl =~ m,(?:http|ftp)://,) {
    my $urlend = substr ($fullurl, -1);
    if ($urlend ne '/') {
        $fullurl .= '/';
    }
    if ($fullurl =~ m,(http|ftp)://([^/@]+)(/[^ ]*),) {
        $proto = $1;
        $host = $2;
        $path = $3;
        $url = $fullurl;
    }
}

print "parse_protocol='$proto'\n";
print "parse_host='$host'\n";
print "parse_path='$path'\n";
print "parse_url='$url'\n";
1;
