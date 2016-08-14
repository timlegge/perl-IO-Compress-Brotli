package IO::Compress::Brotli;

use 5.014000;
use strict;
use warnings;

use IO::Uncompress::Brotli;

use parent qw/Exporter/;

our @EXPORT = qw/bro/;
our @EXPORT_OK = @EXPORT;

our $VERSION = '0.001001';

sub create {
	my ($class) = @_;
	my $state = BrotliEncoderCreateInstance();
	bless \$state, $class
}

sub DESTROY {
	my ($self) = @_;
	BrotliEncoderDestroyInstance($$self)
}

sub quality {
    my ($self, $quality) = @_;
    BrotliEncoderSetQuality($$self, $quality)
}

sub window {
    my ($self, $window) = @_;
    BrotliEncoderSetWindow($$self, $window)
}

my %BROTLI_ENCODER_MODE = ( generic => 0, text => 1, font => 2 );
sub mode {
    my ($self, $mode) = @_;

    die "Invalid encoder mode"
        unless $BROTLI_ENCODER_MODE{$mode};

    BrotliEncoderSetMode($$self, $mode)
}

use constant {
    BROTLI_OPERATION_PROCESS => 0,
    BROTLI_OPERATION_FLUSH   => 1,
    BROTLI_OPERATION_FINISH  => 2
};
sub compress {
	my ($self, $data) = @_;
	BrotliEncoderCompressStream($$self, $data, BROTLI_OPERATION_PROCESS )
}

sub flush {
	my ($self) = @_;
	BrotliEncoderCompressStream($$self, '', BROTLI_OPERATION_FLUSH )
}

sub finish {
	my ($self) = @_;
	BrotliEncoderCompressStream($$self, '', BROTLI_OPERATION_FINISH )
}

# Untested, probably not working
sub set_dictionary {
	my ($self, $dict) = @_;
	BrotliEncoderSetCustomDictionary($$self, $dict)
}

1;
__END__

=encoding utf-8

=head1 NAME

IO::Compress::Brotli - [Not yet implemented] Write Brotli buffers/streams

=head1 SYNOPSIS

  use IO::Compress::Brotli;

  # compress a buffer
  my $encoded = bro $encoded;

  # compress a stream
  my $bro = IO::Compress::Brotli->create;
  while(have_input()) {
     my $block = get_input_block();
     my $encoded_block = $bro->compress($block);
     handle_output_block($encoded_block);
  }
  # Need to finish the steam
  handle_output_block($bro->finish());

=head1 DESCRIPTION

IO::Compress::Brotli is a module that compressed Brotli buffers
and streams. Despite its name, it is not a subclass of
L<IO::Compress::Base> and does not implement its interface. This
will be rectified in a future release.

=head2 One-shot interface

If you have the whole buffer in a Perl scalar use the B<bro>
function.

=over

=item B<bro>(I<$input>)

Takes a whole uncompressed buffer as input and returns the compressed
data.

Exported by default.

=back

=head2 Streaming interface

If you want to process the data in blocks use the object oriented
interface. The available methods are:

=over

=item IO::Compress::Brotli->B<create>

Returns a IO::Compress::Brotli instance. Please note that a single
instance cannot be used to decompress multiple streams.

=item $bro->B<window>(I<$window>)

Sets the window parameter on the brotli encoder.
Defaults to BROTLI_DEFAULT_WINDOW (22).

=item $bro->B<quality>(I<$quality>)

Sets the quality paremeter on the brotli encoder.
Defaults to BROTLI_DEFAULT_QUALITY (11).

=item $bro->B<mode>(I<$mode>)

Sets the brotli encoder mode, which can be any of "generic",
"text" or "font". Defaults to "generic".

=item $bro->B<compress>(I<$block>)

Takes the a block of uncompressed data and returns a block of
compressed data. Dies on error.

=item $bro->B<flush>()

Flushes any pending output from the encoder.

=item $bro->B<finish>()

Tells the encoder to start the finish operation, and flushes
any remaining compressed output.

Once finish is called, the encoder cannot be used to compress
any more content.

B<NOTE>: Calling finish is B<required>, or the output might
remain unflushed, and the be missing termination marks.

=back

=head1 SEE ALSO

Brotli Compressed Data Format Internet-Draft:
L<https://www.ietf.org/id/draft-alakuijala-brotli-08.txt>

Brotli source code: L<https://github.com/google/brotli/>

=head1 AUTHOR

Marius Gavrilescu, E<lt>marius@ieval.roE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Marius Gavrilescu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
