# Copyright (c) 2008 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use 5.010;
use strict;
use warnings;
use Exception::Class::TryCatch qw/try catch/;
use File::Basename qw/basename/;
use IO::CaptureOutput qw/capture/;
use IO::File;
use File::Spec ();
use File::Temp qw/tempdir/;
use Test::More;

plan tests => 15;

require_ok( 'App::CPAN::Mini::Visit' );

#--------------------------------------------------------------------------#
# fixtures
#--------------------------------------------------------------------------#

my $exe = basename $0;
my ($stdout, $stderr);
my $tempdir = tempdir( CLEANUP => 1 );
my $minicpan = File::Spec->catdir(qw/t CPAN/);

sub _create_minicpanrc {
  my $rc_fh = IO::File->new(File::Spec->catfile($tempdir,'.minicpanrc'), ">");
  say {$rc_fh} $_[0] || '';
  close $rc_fh;
}

#--------------------------------------------------------------------------#
# Option: version
#--------------------------------------------------------------------------#

for my $opt ( qw/ --version -V / ) {
  try eval {
    capture sub {
      App::CPAN::Mini::Visit->run( $opt )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $err, undef, "[$opt] no exception" );
  is( $stderr, "$exe: $App::CPAN::Mini::Visit::VERSION\n", "[$opt] correct" );
}

#--------------------------------------------------------------------------#
# Option: help
#--------------------------------------------------------------------------#

for my $opt ( qw/ --help -h / ) {
  try eval {
    capture sub {
      App::CPAN::Mini::Visit->run( $opt )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $err, undef, "[$opt] no exception" );
  like( $stderr, qr/^Usage:/, "[$opt] correct" );
}

#--------------------------------------------------------------------------#
# minicpan -- no minicpanrc and no --minicpan should fail with error
#--------------------------------------------------------------------------#

# homedir for testing 
local $ENV{HOME} = $tempdir;

# should have error here
{
  my $label = "no minicpan config";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run( )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $err, undef, "[$label] no exception" );
  like( $stderr, qr/^No minicpan configured/, "[$label] error message correct" );
}

# missing minicpan directory should have error
my $bad_minicpan = 'doesntexist';
_create_minicpanrc("local: $bad_minicpan");
{
  my $label = "missing minicpan dir";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run( )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $err, undef, "[$label] no exception" );
  like( $stderr, qr/^Directory '$bad_minicpan' does not appear to be a CPAN repository/, 
    "[$label] error message correct" 
  );
}

# badly structured minicpan directory should have error
$bad_minicpan = File::Spec->catdir($tempdir, 'CPAN');
mkdir $bad_minicpan;
_create_minicpanrc("local: $bad_minicpan");
{
  my $label = "bad minicpan dir";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run( )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $err, undef, "[$label] no exception" );
  like( $stderr, qr/^Directory '$bad_minicpan' does not appear to be a CPAN repository/, 
    "[$label] error message correct" 
  );
}


# good minicpan directory (from options -- overrides bad config)

# good minicpan directory (from config only)

