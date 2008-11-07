# Copyright (c) 2008 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

package App::CPAN::Mini::Visit;
use 5.010;
use strict;
use warnings;

use version; our $VERSION = qv("v0.1.0");

use CPAN::Mini ();
use Exception::Class::TryCatch qw/ try catch /;
use File::Basename qw/ basename /;
use File::Find qw/ find /;
use File::pushd qw/ tempd /;
use Path::Class qw/ dir file /;
use Getopt::Lucid qw/ :all /;
use Pod::Usage qw/ pod2usage /;

use Archive::Extract ();
$Archive::Extract::PREFER_BIN = 1;
$Archive::Extract::WARN = 1;
$Archive::Extract::DEBUG = 0;

my @option_spec = (
  Switch("help|h"),
  Switch("version|V"),
  Param("minicpan|m"),
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

  find( 
    {
      no_chdir => 1,
      follow => 0,
      preprocess => sub { return sort @_ },
      wanted => sub {
        return unless /$archive_re/;
        # run code if program/args given otherwise print name
        if ( @args) {
          return if $_ =~ /pm\.gz$/io; # not an archive, just a file
          _visit( $_, @args );
        }
        else {
          say; 
        }
      },
    },
    dir( $opt->get_minicpan )->absolute,
  );

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

  $exe [OPTIONS] -- [PROGRAM] [PROGRAM ARGS]

Options:
 --minicpan|-m      directory of a minicpan (defaults to local minicpan 
                    from CPAN::Mini config file)

 --                 indicates the end of options for $exe

 --help|-h          this usage info 

 --version|-V       $exe program version

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
  if ( ! $ae->extract ) {
    warn "Couldn't extract '$archive'\n";
    return;
  }
  
  # most distributions unpack a single directory that we must enter
  # but some behave poorly and unpack to the current directory
  my @children = dir()->children;
  if ( @children == 1 && -d $children[0] ) {
    chdir $children[0];
  }
  
  # execute command
  system( @cmd_line );
  if ( $? ) {
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

Copyright (c) 2008 by David A. Golden. All rights reserved.

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

