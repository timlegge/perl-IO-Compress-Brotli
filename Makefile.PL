use 5.014000;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME             => 'IO::Compress::Brotli',
	VERSION_FROM     => 'lib/IO/Compress/Brotli.pm',
	ABSTRACT         => 'Read Brotli buffers/streams',
	AUTHOR           => 'Marius Gavrilescu <marius@ieval.ro>',
	MIN_PERL_VERSION => '5.14.0',
	LICENSE          => 'perl',
	SIGN             => 1,
	PREREQ_PM        => {},
	BUILD_REQUIRES   => {
		qw/File::Slurp 0/,
	},
	INC              => '-I.',
	OBJECT           => 'Brotli.o bit_reader.o decode.o dictionary.o huffman.o state.o streams.o',
	C                => [<dec/*c>],
	depend           => {'$(INST_DYNAMIC)' => '$(O_FILES)'},
	META_ADD         => {
		dynamic_config => 0,
		resources      => {
			repository   => 'https://git.ieval.ro/?p=io-compress-brotli.git',
		},
	}
);
