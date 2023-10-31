use 5.008000;
use ExtUtils::MakeMaker;
use Alien::cmake3;
use File::Spec::Functions qw/catfile/;
use Config;

my $cmake_options;
my $myextlib = 'brotli/libbrotlienc$(LIB_EXT) brotli/libbrotlidec$(LIB_EXT) brotli/libbrotlicommon$(LIB_EXT)';

if ($Config{myuname} =~ /strawberry/i || $Config{osname} =~ /MSWin/i ) {
    if ($Config{cc} =~ /gcc/i) {
        $cmake_options = ' -G "MinGW Makefiles" ';
    } elsif ($Config{cc} =~ /cl/i) {
        $cmake_options = ' -G "NMake Makefiles" ';
        $myextlib = 'brotli/brotlienc$(LIB_EXT) brotli/brotlidec$(LIB_EXT) brotli/brotlicommon$(LIB_EXT)';
    } else {
        $cmake_options = '';
    }
}

WriteMakefile(
	NAME             => 'IO::Compress::Brotli',
	VERSION_FROM     => 'lib/IO/Compress/Brotli.pm',
	ABSTRACT         => 'Read/write Brotli buffers/streams',
	AUTHOR           => 'Marius Gavrilescu <marius@ieval.ro>',
	MIN_PERL_VERSION => '5.08.0',
	LICENSE          => 'perl',
	SIGN             => 1,
	EXE_FILES        => [ 'bin/bro-perl' ],
	PREREQ_PM        => {
		'File::Slurper' => '0',
		'Getopt::Long'  => '0',
		'Time::HiRes'   => '0',
	},
	CONFIGURE_REQUIRES   => {
		'Alien::cmake3' => '0',
	},
	BUILD_REQUIRES   => {
		'Alien::cmake3' => '0',
	},
	INC              => '-Ibrotli/c/include',
	MYEXTLIB         => $myextlib,
	clean            => { FILES => "brotli/Makefile $myextlib brotli/CMakeCache.txt brotli/CMakeFiles/* brotli/CTestTestfile.cmake brotli/DartConfiguration.tcl brotli/brotli* brotli/cmake_install.cmake brotli/libbrotlicommon.pc brotli/libbrotlidec.pc brotli/libbrotlienc.pc" },
	META_ADD         => {
		dynamic_config => 0,
		resources      => {
			repository   => 'https://github.com/timlegge/perl-IO-Compress-Brotli',
		},
	}
);

sub MY::postamble {
    my @dirs = Alien::cmake3->bin_dir;
    my $cmake = defined $dirs[0] ? catfile($dirs[0] , Alien::cmake3->exe) : Alien::cmake3->exe;
'
$(MYEXTLIB): brotli/CMakeLists.txt
	cd brotli && "' . $cmake . '"' . $cmake_options . ' -DCMAKE_MAKE_PROGRAM=$(MAKE) -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./installed . && $(MAKE)
'
}
