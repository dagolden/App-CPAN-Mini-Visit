# Copyright (c) 2008 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a 
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use 5.006;
use strict;
use warnings;
use lib 'inc';
eval "require Pod::WikiDoc";
my $class = $@ ? "Module::Build" : "Module::Build::WikiDoc";
eval "require $class";
my $build = $class->new( 
    module_name => 'App::CPAN::Mini::Visit',
    dist_author => 'David Golden <dagolden@cpan.org>',
    license => 'apache',
    create_readme => 1,
    create_makefile_pl  => 'traditional',
    configure_requires => {
      'version' => 0.74, 
    },
    requires => {
      'perl' => 5.010,
      'Archive::Extract' => 0.28, 
      'CPAN::Mini' => 0.572,
      'Exception::Class::TryCatch' => 1.12,
      'File::Basename' => 0,
      'File::Find' => 0,
      'File::pushd' => 1.00,
      'Getopt::Lucid' => 0.16,
      'Path::Class' => 0.16,
      'Pod::Usage' => 1.35, 
      'version' => 0.74,  
    },
    build_requires => {
      'File::Temp' => 0.20, 
      'IO::CaptureOutput' => 1.0801,
      'IO::File' => 0,
      'Test::More' => 0.62, 
    },
    meta_add            => { 
        no_index => { 
            directory => [ qw/ examples inc t /],
        } 
    },
);
$build->create_build_script;

