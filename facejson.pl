#!/usr/bin/perl
#
# Matthew J. Kidd (San Diego, CA)
#
# This software is released under the GNU General Public License GPLv3
# See: http://www.gnu.org/licenses/gpl.html for full license.
#
# This program is a server side support program for the face view functionality
# in ACBLmerge. It returns the faces directory and a sorted array of ACBL
# player numbers for all players for whom faces are available. Results are
# returned as JavaScript Object Notation (JSON).
#
# The point of this program is to avoid queries for faces that do not
# exist and prevent a slew of 404 errors in the webserver event logs.
#
# Place this program in your server's /cgi-bin folder.
#
# 1.0.0 - 07-Mar-2011 - Current version
# 1.0.0 - 07-Mar-2011 - Initial Release

use strict;
use CGI qw(:standard);

# Location of faces as seen by clients (in particular ACBLmerge output).
# Change this value if the faces will reside in a different location.
my $FACE_DIR = '/images/faces';

# Location of faces as seen by this program running on the server.
# This works under Apache but if it does not work for your webserver
# specify the directory explicitly, e.g. ~/html/images/faces
my $INTERNAL_FACE_DIR = $ENV{'DOCUMENT_ROOT'} . $FACE_DIR;

opendir(DH, $INTERNAL_FACE_DIR) or die "Unable to open directory: $INTERNAL_FACE_DIR";
my @facejpgs = grep { /^\d{7}\.jpg$/ } readdir(DH);
my @pnums = map { substr($_,0,7) } @facejpgs;

# print "Content-Type: application/json\n";
print header('application/json');

print '[', join(',', "\"$FACE_DIR\"", '[' . join(',', sort(@pnums)) . ']'), ']';

