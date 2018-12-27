#!/usr/bin/perl
#
# gamedump.pl
#
# Matthew J. Kidd (San Diego, CA)
#
# This software is released under the GNU General Public License GPLv3
# See: http://www.gnu.org/licenses/gpl.html for full license.
#
# Partially decodes an ACBLscore game file, outputting result as JSON.
#
# 12-Nov-2014 - Current release
# 05-Nov-2014 - Initial release

use strict;
use FindBin;
use lib $FindBin::Bin;

use JSON::PP;
use ACBLgamedecode;

my $VERSTR = '1.0.1';

# Exit codes
my $EXIT_SUCCESS      =   0;
my $EXIT_ARG_PARSING  =  -1;
my $EXIT_FILE_ERR     =  -2;

(my $bname = $0) =~ s/.*[\\\/]//;

if ( scalar(@ARGV) == 0 ) {
  
  print "\n  Missing parameter(s)\n";
  
  print << "DONE";

  Usage: $bname fname [fname...] [-o ofname]

  fname  : ACBLscore game filename
  ofname : Output filename (default is STDOUT)
    
  Options
    -sc : Dump to section level only
    -nb : Don't dump board
    -ne : Don't dump entries (individual, pairs, teams)
    -vr : Display version number
    
  Partially decodes one or more ACBLscore game files, outputting
  result as JSON.
  
  Online documentation is located at:
  http://lajollabridge.com/Software/ACBLgamedump/ACBLgamedump-About.htm
  
  See http://lajollabridge.com/Articles/ACBLscoreGameFilesDecoded.htm
  for details of ACBLscore game file format.

DONE

  exit($EXIT_SUCCESS);
}

my (@fnames, %opt);

while ( my $arg = shift(@ARGV) ) {
  if ( substr($arg,0,1) ne '-' ) { push @fnames, $arg; next; };
  my $sw = substr($arg,1);
  if ($sw eq 'o') {
    $arg = shift(@ARGV);
    if (!defined $arg) {
      print STDERR "\n-$sw switch is missing argument.\n"; exit($EXIT_ARG_PARSING);
    }
    $opt{'ofname'} = $arg;
  }
  elsif ($sw eq 'nb') { $opt{'noboards'} = 1; }
  elsif ($sw eq 'ne') { $opt{'noentries'} = 1; }
  elsif ($sw eq 'sc') { $opt{'sectionsonly'} = 1; }
  elsif ($sw eq 'vr') { $opt{'showver'} = 1; }
  else {
    print STDERR "Unrecognized switch: $arg\n";
  }
}

print STDERR "$bname $VERSTR\n" if $opt{'showver'};

if (scalar(@fnames) == 0) {
  print STDERR "No input file(s) to process.\n"; exit($EXIT_ARG_PARSING);
}

my $data;
my $ix = 0;

foreach my $fname (@fnames) {
  my ($err, $gm) = ACBLgamedecode::decode($fname, \%opt);
  if ($err == -257) {
    print STDERR "Not an ACBLscore game file: $fname (skipped)\n";
  }
  elsif (!$err) { $data->[$ix] = $gm; }

  $ix++;
}

exit($EXIT_SUCCESS) if !defined $data;

my $fh;
if ( defined $opt{'ofname'} ) {
  if (! open($fh, '>', $opt{'ofname'})) {
    print STDERR "Unable to open/write: $opt{'ofname'}\n"; exit($EXIT_FILE_ERR);
  }  
}
else {
  open($fh, '>-');
}

print $fh JSON::PP->new->encode($data);
close($fh);  

exit($EXIT_SUCCESS);
