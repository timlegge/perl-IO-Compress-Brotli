#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Test::More;
binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);
use Encode qw(decode_utf8 encode_utf8);

BEGIN {
    use_ok('IO::Compress::Brotli',   'bro')   or BAIL_OUT('cannot load IO::Compress::Brotli');
    use_ok('IO::Uncompress::Brotli', 'unbro') or BAIL_OUT('cannot load IO::Uncompress::Brotli');
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Return a fresh SV holding the UTF-8 bytes of $str with the UTF-8 flag OFF.
sub utf8_bytes {
    my $s = shift;
    utf8::encode($s) if utf8::is_utf8($s);
    return $s;
}

# Return a fresh SV holding the characters of $str with the UTF-8 flag ON
# (when the string contains anything that requires it).
sub utf8_chars {
    my $s = shift;
    $s = decode_utf8($s) unless utf8::is_utf8($s);
    return $s;
}

# ---------------------------------------------------------------------------
# One-shot interface: bro / unbro
# ---------------------------------------------------------------------------

subtest 'bro: pure ASCII (no UTF-8 flag) round-trips' => sub {
    my $input    = "hello world" x 100;
    my $encoded  = bro($input);
    ok(defined $encoded && length $encoded, 'got compressed output');
    is(unbro($encoded), $input, 'decompresses to original');
};

subtest 'bro: byte string with high bytes round-trips' => sub {
    my $input   = utf8_bytes("café");   # 5 UTF-8 bytes, flag off
    ok(!utf8::is_utf8($input), 'input flag is off');
    my $encoded = bro($input);
    is(unbro($encoded), $input, 'byte-for-byte round trip');
};

subtest 'bro: Latin-1-range character string does not croak' => sub {
    # This is the case that 0.019 silently downgrades and produces
    # different output for. After the fix, it should behave like a
    # UTF-8-encoded byte string.
    my $chars = utf8_chars("café");
    ok(utf8::is_utf8($chars), 'input flag is on');

    my $encoded;
    my $ok = eval { $encoded = bro($chars); 1 };
    ok($ok, 'bro() did not croak on UTF-8-flagged Latin-1 string')
        or diag "error: $@";

    # The decompressed bytes should equal the UTF-8 encoding of the
    # characters, NOT the Latin-1 downgrade.
    my $decoded = unbro($encoded);
    is($decoded, encode_utf8("café"),
        'decompressed output equals UTF-8 byte encoding of input');
    isnt($decoded, "caf\xE9",
        'decompressed output is NOT the Latin-1 downgrade');
};

subtest 'bro: non-Latin-1 characters do not croak (regression for 0.019)' => sub {
    my $chars = utf8_chars("日本");
    ok(utf8::is_utf8($chars), 'input flag is on');

    my $encoded;
    my $ok = eval { $encoded = bro($chars); 1 };
    ok($ok, 'bro() did not croak on characters > U+00FF')
        or diag "error: $@";

    is(unbro($encoded), encode_utf8("日本"),
        'round-trips to UTF-8 byte encoding');
};

subtest 'bro: character string and equivalent byte string compress identically' => sub {
    # This is the core invariant: the compressed output should be a
    # function of the logical string, not of Perl's internal storage.
    for my $literal ("café", "日本", "Ærø", "hello") {
        my $chars = utf8_chars($literal);
        my $bytes = utf8_bytes($literal);

        my $from_chars = eval { bro($chars) };
        my $from_bytes = eval { bro($bytes) };

        is($from_chars, $from_bytes,
            "bro() output identical for char vs byte form of '$literal'");
    }
};

subtest 'bro: input SV is not mutated' => sub {
    # The fix should encode a *copy*, not the caller's SV.
    my $original = utf8_chars("café");
    my $snapshot = $original;       # SV copy; still flagged
    bro($original);
    ok(utf8::is_utf8($original), 'UTF-8 flag still set after bro()');
    is($original, $snapshot, 'value unchanged after bro()');
};

subtest 'bro: quality and window parameters still work' => sub {
    my $input = "The quick brown fox jumps over the lazy dog. " x 50;
    my $q1 = bro($input, 1);
    my $q11 = bro($input, 11);
    ok(length $q1,  'quality=1 produces output');
    ok(length $q11, 'quality=11 produces output');
    is(unbro($q1),  $input, 'quality=1 round-trips');
    is(unbro($q11), $input, 'quality=11 round-trips');
};

subtest 'bro: invalid quality still croaks' => sub {
    my $ok = eval { bro("hello", 99); 1 };
    ok(!$ok, 'invalid quality croaks');
    like($@, qr/Invalid quality/, 'expected error message');
};

# ---------------------------------------------------------------------------
# Streaming interface
# ---------------------------------------------------------------------------

subtest 'streaming: UTF-8-flagged chunks do not croak' => sub {
    my $enc = IO::Compress::Brotli->create;
    isa_ok($enc, 'IO::Compress::Brotli');

    my $out = '';
    my $ok = eval {
        $out .= $enc->compress(utf8_chars("café "));
        $out .= $enc->compress(utf8_chars("日本 "));
        $out .= $enc->compress("plain ascii");
        $out .= $enc->finish;
        1;
    };
    ok($ok, 'streaming compress did not croak on UTF-8-flagged chunks')
        or diag "error: $@";

    my $expected = encode_utf8("café ") . encode_utf8("日本 ") . "plain ascii";
    is(unbro($out), $expected, 'streaming output round-trips correctly');
};

subtest 'streaming: char and byte chunks produce identical output' => sub {
    my $literal = "café 日本 hello";

    my $enc_c = IO::Compress::Brotli->create;
    my $from_chars = $enc_c->compress(utf8_chars($literal)) . $enc_c->finish;

    my $enc_b = IO::Compress::Brotli->create;
    my $from_bytes = $enc_b->compress(utf8_bytes($literal)) . $enc_b->finish;

    is($from_chars, $from_bytes,
        'streaming output identical regardless of input flag');
};

subtest 'streaming: chunk SV is not mutated' => sub {
    my $chunk = utf8_chars("café");
    my $snapshot = $chunk;

    my $enc = IO::Compress::Brotli->create;
    $enc->compress($chunk);
    $enc->finish;

    ok(utf8::is_utf8($chunk), 'UTF-8 flag still set on chunk');
    is($chunk, $snapshot, 'chunk value unchanged');
};

subtest 'streaming: flush works' => sub {
    my $enc = IO::Compress::Brotli->create;
    my $out = '';
    $out .= $enc->compress("hello ");
    $out .= $enc->flush;
    $out .= $enc->compress("world");
    $out .= $enc->finish;
    is(unbro($out), "hello world", 'round trip with flush');
};

# ---------------------------------------------------------------------------
# Decompression side
# ---------------------------------------------------------------------------

subtest 'unbro: with explicit size works' => sub {
    my $input   = "x" x 1000;
    my $encoded = bro($input);
    is(unbro($encoded, 10_000), $input, 'unbro with size hint round-trips');
};

subtest 'unbro: streaming decompress works' => sub {
    my $input   = "y" x 5000;
    my $encoded = bro($input);
    my $dec = IO::Uncompress::Brotli->create;
    is($dec->decompress($encoded), $input, 'streaming decompress round-trips');
};

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

subtest 'edge: empty string' => sub {
    my $encoded = bro("");
    ok(defined $encoded, 'bro("") returns defined value');
    is(unbro($encoded), "", 'round-trips to empty');
};

subtest 'edge: long UTF-8 input' => sub {
    my $chars = utf8_chars("日本語のテキスト " x 1000);
    my $encoded = eval { bro($chars) };
    ok(defined $encoded, 'long UTF-8 input compresses');
    is(unbro($encoded), encode_utf8("日本語のテキスト " x 1000),
        'long UTF-8 input round-trips');
};

done_testing;
