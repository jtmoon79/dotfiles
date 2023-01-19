#!/usr/bin/env perl
#
# list installed perl CPAN modules
# ripped from https://www.cyberciti.biz/faq/list-installed-perl-modules-unix-linux-appleosx-bsd/

use warnings;

use ExtUtils::Installed;

my $inst    = ExtUtils::Installed->new();
my @modules = $inst->modules();
 foreach $module (@modules){
      print $module . "\n";
}
