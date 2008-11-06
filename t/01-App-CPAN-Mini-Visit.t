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

plan tests => 12;

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
  is( $stderr, "$exe: $App::CPAN::Mini::Visit::VERSION\n", 
    "[$opt] correct" 
  ) or diag $err;
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
  like( $stderr, qr/^Usage:/, "[$opt] correct" ) or diag $err;
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
  like( $stderr, qr/^No minicpan configured/, 
    "[$label] error message correct" 
  ) or diag $err;
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
  like( $stderr, qr/^Directory '$bad_minicpan' does not appear to be a CPAN repository/, 
    "[$label] error message correct" 
  ) or diag $err;
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
  like( $stderr, qr/^Directory '$bad_minicpan' does not appear to be a CPAN repository/, 
    "[$label] error message correct" 
  ) or diag $err;
}

# good minicpan directory (from options -- overrides bad config)
for my $opt ( qw/ --minicpan -m / ) {
  my $label = "good $opt=...";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run("$opt=$minicpan")
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $stderr, "", "[$label] no error message" ) or diag $err;
}

# good minicpan directory (from config only)
_create_minicpanrc("local: $minicpan");
{
  my $label = "good minicpan from config";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run()
    } => \$stdout, \$stderr;
  };
  catch my $err;
  is( $stderr, "", "[$label] no error message" ) or diag $err;
}

# bad minicpan directory (from options -- overrides bad config)
{
  my $label = "bad -m=...";
  try eval { 
    capture sub {
      App::CPAN::Mini::Visit->run( "-m=$bad_minicpan" )
    } => \$stdout, \$stderr;
  };
  catch my $err;
  like( $stderr, qr/^Directory '$bad_minicpan' does not appear to be a CPAN repository/, 
    "[$label] error message correct" 
  ) or diag $err;
}

