#!/usr/bin/perl
use v5.08;
use warnings;

use Test::More tests => 132;
use File::Slurper qw/read_binary/;

use IO::Uncompress::Brotli;

for my $test (<brotli/tests/testdata/*.compressed*>) {
	my $expected = $test;
	$expected =~ s/\.compressed.*//;
	$expected = read_binary $expected;

	my $decoded = unbro ((scalar read_binary $test), 1_000_000);
	is $decoded, $expected, "$test (two-argument unbro)";

	$decoded = unbro scalar read_binary $test;
	is $decoded, $expected, "$test (one-argument unbro)";

	open FH, '<', $test;
	binmode FH;
	my $unbro = IO::Uncompress::Brotli->create;
	my ($buf, $out);
	until (eof FH) {
		read FH, $buf, 100;
		$out .= $unbro->decompress($buf);
	}
	is $out, $expected, "$test (streaming)";
}
