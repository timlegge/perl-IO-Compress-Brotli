use 5.008000;
use ExtUtils::MakeMaker;
use Alien::cmake3;
use File::Spec::Functions qw/catfile/;
use Config;

my $lib_ext = $Config{lib_ext} || '.a';

# The three static archives produced by Brotli's own CMake build
# (-DBUILD_SHARED_LIBS=OFF gives separate enc/dec/common libs).
my @parts = (
    "brotli/libbrotlienc$lib_ext",
    "brotli/libbrotlidec$lib_ext",
    "brotli/libbrotlicommon$lib_ext",
);
my $parts_str = join ' ', @parts;

# ONE combined archive. ExtUtils::MakeMaker's static_lib rule runs
#   cp $(MYEXTLIB) $(INST_STATIC)
# which only works when MYEXTLIB names a single file. Setting MYEXTLIB to the
# three separate libs is what made cp fail with "No such file or directory",
# so we merge them into a single library and hand EU::MM that.
my $myextlib = "brotli/libbrotli$lib_ext";

my $cmake_options = '';
my $merge_cmds;   # extra Makefile recipe line(s) that build $myextlib from @parts

if ($Config{myuname} =~ /strawberry/i || $Config{osname} =~ /MSWin/i) {
    if ($Config{cc} =~ /cl/i) {                 # MSVC toolchain: lib.exe merges libs
        $cmake_options = ' -G "NMake Makefiles" ';
        $merge_cmds = "\tlib -nologo -out:$myextlib $parts_str\n";
    } else {                                    # MinGW: GNU binutils ar (supports -M)
        $cmake_options = ' -G "MinGW Makefiles" ';
        $merge_cmds = gnu_merge($myextlib);
    }
} elsif ($^O eq 'darwin') {                     # macOS: BSD ar has no -M, use libtool
    $merge_cmds = "\tlibtool -static -o $myextlib $parts_str\n";
} else {                                        # Linux / GNU ar
    $merge_cmds = gnu_merge($myextlib);
}

# Build an `ar` MRI script now and feed it to ar via input redirection at
# build time. Redirection works under both /bin/sh and cmd.exe, avoiding the
# shell-quoting differences of an inline here-doc.
sub gnu_merge {
    my ($out) = @_;
    if (-d 'brotli') {
        open my $fh, '>', 'brotli/combine.mri' or die "Cannot write brotli/combine.mri: $!";
        print {$fh} "create $out\n";
        print {$fh} "addlib $_\n" for @parts;
        print {$fh} "save\n";
        print {$fh} "end\n";
        close $fh;
    }
    return "\t\$(AR) -M < brotli/combine.mri\n"
         . "\t\$(RANLIB) $out\n";
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
	clean            => { FILES => "brotli/Makefile $myextlib $parts_str brotli/combine.mri brotli/CMakeCache.txt brotli/CMakeFiles/* brotli/CTestTestfile.cmake brotli/DartConfiguration.tcl brotli/brotli* brotli/cmake_install.cmake brotli/libbrotlicommon.pc brotli/libbrotlidec.pc brotli/libbrotlienc.pc" },
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
    return <<"POSTAMBLE";
\$(MYEXTLIB): brotli/CMakeLists.txt
\tcd brotli && "$cmake"$cmake_options -DCMAKE_MAKE_PROGRAM=\$(MAKE) -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./installed . && \$(MAKE)
$merge_cmds
POSTAMBLE
}
