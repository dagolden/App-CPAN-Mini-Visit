# Copyright (c) 2008-2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

package App::CPAN::Mini::Visit;
use 5.010;
use strict;
use warnings;

our $VERSION = '0.006';
$VERSION = eval $VERSION; ## no critic

use CPAN::Mini ();
use Exception::Class::TryCatch qw/ try catch /;
use File::Basename qw/ basename /;
use File::Find qw/ find /;
use File::pushd qw/ tempd /;
use Path::Class qw/ dir file /;
use Getopt::Lucid qw/ :all /;
use Pod::Usage qw/ pod2usage /;

use Archive::Extract ();

my @option_spec = (
  Switch("help|h"),
  Switch("version|V"),
  Switch("quiet|q"),
  Param("append|a", qr/(?:^$|(?:^path|dist$))/ )->default(''),
  Param("e|E"),
  Param("minicpan|m"),
  Param("output|o"),
);

sub run {
  my ($self, @args) = @_;

  # get command line options
  my $opt = try eval { Getopt::Lucid->getopt( \@option_spec, \@args ) };
  for ( catch ) {
    when ( $_->isa('Getopt::Lucid::Exception::ARGV') ) {
      say;
      # usage stuff
      return 1;
    }
    default { die $_ }
  }

  # handle "help" and "version" options
  return _exit_usage() if $opt->get_help;
  return _exit_version() if $opt->get_version;

  # Set Archive::Extract globals
  # if quiet suppress warnings from Archive::Tar, etc.
  local $Archive::Extract::DEBUG = 0;
  local $Archive::Extract::PREFER_BIN = 1;
  local $Archive::Extract::WARN = $opt->get_quiet ? 0 : 1;

  # if -e/-E, then prepend to command
  if ( $opt->get_e ) {
    unshift @args, $^X, '-E', $opt->get_e;
  }

  # locate minicpan directory
  if ( ! $opt->get_minicpan ) {
    my %config = CPAN::Mini->read_config;
    if ( $config{local} ) {
      $opt->merge_defaults( {minicpan => $config{local}} );
    }
  }

  # confirm minicpan directory that looks like minicpan
  return _exit_no_minicpan() if ! $opt->get_minicpan;
  return _exit_bad_minicpan($opt->get_minicpan) if ! -d $opt->get_minicpan;

  my $id_dir = dir($opt->get_minicpan, qw/authors id/);
  return _exit_bad_minicpan($opt->get_minicpan) if ! -d $id_dir;

  # process all distribution tarballs in authors/id/...
  my $archive_re = qr{\.(?:tar\.(?:bz2|gz|Z)|t(?:gz|bz)|zip|pm\.gz)$}i;

  my $minicpan = dir( $opt->get_minicpan )->absolute;
  
  # save output by redirecting STDOUT if requested
  my ($out_fh, $orig_stdout );
  if ( $opt->get_output ) {
    open $out_fh, ">", $opt->get_output;
    open $orig_stdout, "<&=STDOUT";
    open STDOUT, ">&=" . fileno $out_fh;
  }

  find( 
    {
      no_chdir => 1,
      follow => 0,
      preprocess => sub { my @files = sort @_; return @files },
      wanted => sub {
        return unless /$archive_re/;
        # run code if program/args given otherwise print name
        if ( @args ) {
          return if $_ =~ /pm\.gz$/io; # not an archive, just a file
          my @cmd = @args;
          if ( $opt->get_append ) {
            if ( $opt->get_append eq 'dist' ) {
              my $distname = $_;
              my $prefix = dir( $minicpan, qw/authors id/ );
              $distname =~ s{^$prefix[\\/].[\\/]..[\\/]}{};
              push @cmd, $distname;
            }
            else {
              push @cmd, $_;
            }
          }
          _visit( $_, @cmd );
        }
        else {
          say; 
        }
      },
    },
    $minicpan
  );

  # restore STDOUT and close output file
  if ( $opt->get_output ) {
    open STDOUT, ">&=" . fileno $orig_stdout;
    close $out_fh;
  }

  return 0; # exit code
}

sub _exit_no_minicpan {
  say STDERR << "END_NO_MINICPAN";
No minicpan configured.
END_NO_MINICPAN
  return 1;
}

sub _exit_bad_minicpan {
  my ($dir) = @_;
  die "requires directory argument" unless defined $dir;
  say STDERR << "END_BAD_MINICPAN";
Directory '$dir' does not appear to be a CPAN repository.
END_BAD_MINICPAN
  return 1;
}

sub _exit_usage {
  my $exe = basename($0);
  say STDERR << "END_USAGE";
Usage:
  $exe [OPTIONS] [PROGRAM]

  $exe [OPTIONS] -- [PROGRAM] [ARGS]

Options:

 --append|-a        --append=dist -> append distname after ARGS
                    --append=path -> append tarball path after ARGS

 -e|-E              run next argument via 'perl -E'
 
 --help|-h          this usage info 

 --minicpan|-m      directory of a minicpan (defaults to local minicpan 
                    from CPAN::Mini config file)

 --output|-o        file to save output instead of sending to terminal

 --quiet|-q         silence warnings and suppress STDERR from tar

 --version|-V       $exe program version

 --                 indicates the end of options for $exe

END_USAGE
  return 1;
}

sub _exit_version {
  say STDERR basename($0) . ": $VERSION";
  return 1
}

sub _visit {
  my ($archive, @cmd_line) = @_;
  
  my $tempd = tempd;

  my $ae = Archive::Extract->new( archive => $archive );

  my $olderr;

  # stderr > /dev/null if quiet
  if ( ! $Archive::Extract::WARN ) {
    open $olderr, ">&STDERR";
    open STDERR, ">", File::Spec->devnull;
  }

  my $extract_ok = $ae->extract;

  # restore stderr if quiet
  if ( ! $Archive::Extract::WARN ) {
    open STDERR, ">&", $olderr;
    close $olderr;
  }

  if ( ! $extract_ok ) {
    warn "Couldn't extract '$archive'\n" if $Archive::Extract::WARN;
    return;
  }
  
  # most distributions unpack a single directory that we must enter
  # but some behave poorly and unpack to the current directory
  my @children = dir()->children;
  if ( @children == 1 && -d $children[0] ) {
    chdir $children[0];
  }
  
  # execute command
  my $rc = system( @cmd_line );
  if ( $rc == -1 ) {
    warn "Error running '@cmd_line': $!\n";
  }

  return;
}

1;

__END__

=begin wikidoc

= NAME

App::CPAN::Mini::Visit - explore each distribution in a minicpan repository

= VERSION

This documentation describes %%VERSION%%.

= SYNOPSIS

    #!/usr/bin/perl
    use App::CPAN::Mini::Visit;
    exit App::CPAN::Mini::Visit->run;

= DESCRIPTION

This module contains the guts of the [visitcpan] program.  See documentation of
that program for details on features and command line options.

= USAGE

== {run()}

    exit App::CPAN::Mini::Visit->run();

Executes the program, processing command line arguments and traversing
a minicpan repository.  Returns an exit code.

= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted through the web interface at 
[http://rt.cpan.org/Dist/Display.html?Queue=App-CPAN-Mini-Visit]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= SEE ALSO

* [CPAN::Mini]

= AUTHOR

David A. Golden (DAGOLDEN)

= COPYRIGHT AND LICENSE

Copyright (c) 2008-2009 by David A. Golden. All rights reserved.

Licensed under Apache License, Version 2.0 (the "License").
You may not use this file except in compliance with the License.
A copy of the License was distributed with this file or you may obtain a 
copy of the License from http://www.apache.org/licenses/LICENSE-2.0

Files produced as output though the use of this software, shall not be
considered Derivative Works, but shall be considered the original work of the
Licensor.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=end wikidoc

=cut

