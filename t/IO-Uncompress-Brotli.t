#!/usr/bin/perl
use v5.14;
use warnings;

use Test::More tests => 81;
use File::Slurp;
BEGIN{ use_ok('IO::Uncompress::Brotli'); }

my $todo_re = qr/empty\.compressed\.(?:1[7-9]|2)|x\.compressed\.0[12]/;

for my $test (<brotli/tests/testdata/*.compressed*>) {
	my ($expected) = $test =~ s/\.compressed.*//r;
	$expected = read_file $expected;

	if($test !~ $todo_re) {
		my $decoded = unbro (scalar read_file $test);
		is $decoded, $expected, "$test";
	}

	open FH, '<', $test;
	my $unbro = IO::Uncompress::Brotli->create;
	my ($buf, $out);
	until (eof FH) {
		read FH, $buf, 100;
		$out .= $unbro->decompress($buf);
	}
	is $out, $expected, "$test (streaming)";
}
