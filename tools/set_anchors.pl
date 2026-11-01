#!/usr/bin/perl
# Copies the frames, anchors and points a tools/import_*.gd run printed into assets/manifest.json,
# keeping each entry's frames, scale and other options:
#   Godot --headless --path . -s res://tools/import_painted.gd | perl tools/set_anchors.pl
use strict;
my %new;
while (<STDIN>) {
	next unless /^\s+"([^"]+)": \{(.*)\},/;
	my ($name, $body) = ($1, $2);
	my %f;
	$f{anchor} = $1 if $body =~ /"anchor": (\[[^\]]*\]|"[a-z_]+")/;
	$f{points} = $1 if $body =~ /"points": (\{[^}]*\})/;
	$f{frames} = $1 if $body =~ /"frames": (\[[^\]]*\])/;
	$new{$name} = \%f;
}
my $path = "assets/manifest.json";
open my $in, "<", $path or die;
my @lines = <$in>;
close $in;
my $done = 0;
for (@lines) {
	next unless /^(\s+)"([^"]+)": \{/ and $new{$2};
	my $f = $new{$2};
	s/"anchor": (\[[^\]]*\]|"[a-z_]+")/"anchor": $f->{anchor}/ if $f->{anchor};
	s/"points": \{[^}]*\}/"points": $f->{points}/ if $f->{points};
	s/"frames": \[[^\]]*\]/"frames": $f->{frames}/ if $f->{frames};
	$done++;
}
open my $out, ">", $path or die;
print $out @lines;
close $out;
print STDERR "Updated $done manifest entries\n";
