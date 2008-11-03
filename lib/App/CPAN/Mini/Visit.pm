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
use Getopt::Lucid qw/ :all /;
use Path::Class ();
use Pod::Usage qw/ pod2usage /;

my @option_spec = (
  Switch("help|h"),
  Switch("version|V"),
  Param("minicpan|m"),
  Param("command|c"),
);

sub run {
  
  # get command line options
  my $opt = try eval { Getopt::Lucid->getopt( \@option_spec ) };
  for ( catch ) {
    when ( $_->isa('Getopt::Lucid::Exception::ARGV') ) {
      say;
      # usage stuff
      exit 1;
    }
    default { die $_ }
  }

  # handle "help" and "version" options
  pod2usage(1) if $opt->get_help;
  say basename($0) . ": $VERSION" and exit(1) if $opt->get_version;

  # locate minicpan directory
  if ( ! $opt->get_minicpan ) {
    my $config = try eval { CPAN::Mini->read_config };
    if ( ! catch && $config->{local} ) {
      $opt->merge_defaults( minicpan => $config->{local} );
    }
  }

  # confirm minicpan directory looks like minicpan
  # e.g. check for $dir/authors/id directory

  # find all distribution tarballs in authors/id/...

  # iterate over each distribution
}

1;

__END__

=begin wikidoc

= NAME

App::CPAN::Mini::Visit - Add abstract here

= VERSION

This documentation describes version %%VERSION%%.

= SYNOPSIS

    use App::CPAN::Mini::Visit;

= DESCRIPTION


= USAGE


= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted through the web interface at 
[http://rt.cpan.org/Dist/Display.html?Queue=App-CPAN-Mini-Visit]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= SEE ALSO


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

