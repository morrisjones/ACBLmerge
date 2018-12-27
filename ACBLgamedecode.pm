#!/usr/bin/perl
#
# ACBLgamedecode.pm
#
# Matthew J. Kidd (San Diego, CA)
#
# This software is released under the GNU General Public License GPLv3
# See: http://www.gnu.org/licenses/gpl.html for full license.
#
# Partially decodes an ACBLscore game file, outputting result as JSON.
#
# 05-Nov-2014 - Current release
# 05-Nov-2014 - Initial release

package ACBLgamedecode;

use strict;

# Error codes
my $SUCCESS           =    0;
my $ERR_FILE_ERR      =   -2;
my $ERR_NOT_GAME_FILE = -257;

# Version of decoded data
my $DECODE_FORMAT_VERSION = 1;

# ACBLscore constants
my $MAX_EVENTS   =  50;
my $MAX_SECTIONS = 100;

# ACBLscore events types and scoring methods.
my @EVENT_TYPE = ('Pairs', 'Teams', 'Individual', 'Home Style Pairs', 'BAM', 'Series Winner');
my @EVENT_SCORING = ('Matchpoints', 'IMPs with computed datum', 'Average IMPs', 'Total IMPs',
  'Instant Matchpoints', 'BAM Teams', 'Win/Loss', 'Victory Points', 'Knockout', undef,
   'Series Winner', undef, undef, undef, undef, undef, 'BAM Matchpoints', undef, 'Compact KO');
my @MOVEMENT_TYPE = ('Mitchell', 'Howell', 'Web', 'External', 'External BAM', 'Barometer',
  'Manual Mitchell', 'Manual Howell');

my @CLUB_GAME_TYPE = ('Open', 'Invitational', 'Novice', 'BridgePlus', 'Pupil', 'Introductory');
my %ACBL_PLAYER_RANKS = (' ' => 'Rookie', 'A' => 'Junior Master', 'B' => 'Club Master', 
  'C' => 'Sectional Master', 'D' => 'Regional Master', 'E' => 'NABC Master',
  'F' => 'Advanced NABC Master', 'G' => 'Life Master', 'H' => 'Bronze Life Master', 
  'I' => 'Silver Life Master', 'J' => 'Gold Life Master', 'K' => 'Diamond Life Master',
  'L' => 'Emerald Life Master', 'M' => 'Platinum Life Master', 'N' => 'Grand Life Master'
);
my @AWARD_SETS = ('previous', 'current', 'total');
my $PIGMENTATION_TYPES = ' BSRGP';
my @RIBBON_COLORS = ('', 'Blue', 'Red', 'Silver', undef, undef, undef, undef, undef, 'Blue/Red');

my %SPECIAL_SCORES = ('900' => 'Late Play', '950' => 'Not Played',
  '2040' => 'Ave-', '2050' => 'Ave', '2060' => 'Ave+');
  
my $BYE_TEAM_NUMBER = 888;  

# Structure parameters
my $STRAT_STRUCTURE_SIZE = 95;
my $SECTION_SUMMARY_BASE = 0x13e;
my $SECTION_SUMMARY_SIZE = 22;
my $PLAYER_STRUCTURE_SIZE = 120;
my $TEAM_MATCH_ENTRY_SIZE = 32;

sub decode {
  # Loads and parses a game file
  if (scalar(@_) != 1 && scalar(@_) != 2) { die "function requires 1 or 2 arguments."; }
  my ($fname, $opt) = @_;
  if (ref($fname) ne '') { die '1st argument must be a scalar.'; }
  if (!defined $opt) { $opt = {}; }
  elsif (ref($opt) ne 'HASH') { die '2nd argument must be a hashref or undef.'; }
  
  my $data;
  # Safely isolate $/ change.
  {
    local $/; my $fh;
    return($ERR_FILE_ERR) if !open($fh, '<', $fname);
    binmode($fh);
    $data = <$fh>;
    close($fh);
  }
  
  # Check for the 'AC3' magic bytes that appear at the start of all ACBLscore
  # game files.
  return($ERR_NOT_GAME_FILE) if (substr($data,0,6) ne "\x12\x0a\x03AC3");
  
  my ($p, $event_type_id, $event_scoring_id, $rankstr);

  my $gm = {'filename' => $fname, 'decode_format_version' => $DECODE_FORMAT_VERSION};
  
  my $ix = 0;
  for (my $i=0; $i<$MAX_EVENTS; $i++) {
    $p = unpack('V', substr($data, 0x12 + 4*$i, 4));
    next if !$p;
    $event_type_id    = unpack('C', substr($data, 0xda  + $i));
    $event_scoring_id = unpack('C', substr($data, 0x10c + $i));
    my $ev = {'event_id' => $i+1,  
      'event_type_id' => $event_type_id, 'event_type', $EVENT_TYPE[$event_type_id], 
      'event_scoring_id' => $event_scoring_id, 'event_scoring', $EVENT_SCORING[$event_scoring_id] };
    my $isTeams = $ev->{'event_type_id'} == 1 || $ev->{'event_type_id'} == 4;  
      
    $rankstr = eventDetails($ev, $data, $p, $isTeams);
    addSectionCombining($ev, $data);
    addSections($ev, $data, $opt, $rankstr);
    $gm->{'event'}[$ix] = $ev;
    $ix++;
  }
  
  return ($SUCCESS, $gm);
}

sub zstring {
  # Parse a string where first byte gives the length of the string.
  return substr($_[0], $_[1]+1, unpack('C', substr($_[0], $_[1],1)));
}

sub zstrings {
  # Decode multiple zstring fields and add fields to a hashref.
  # Example: zstrings($hr, $data, $p, 'fdname1', offset1, ...)
  die "At least two arguments are required" if (scalar(@_) < 3);
  die "Last string field has no offset" if (scalar(@_) % 2 == 0);
  my $hr = shift; my $data = shift; my $p = shift; my $fdname;
  while (defined ($fdname = shift)) { $hr->{$fdname} = zstring($data, $p + shift); }
}

sub eventDetails {
  # Parse event details.
  if (scalar(@_) != 4) { die "function requires 4 arguments."; }
  my ($ev, $data, $p, $isTeams) = @_;
  
  $ev->{'mp_rating'} = {
    'p-factor' => unpack('v', substr($data, $p + 0x7d)) / 1000,
    't-factor' => unpack('v', substr($data, $p + 0x83)) / 1000,
    's-factor' => unpack('v', substr($data, $p + 0x24f)) / 100
  };
 
  my $club_session_num = unpack('C', substr($data, $p + 0x95));
  # It is not clear the best way to figure out if results are from a tournament.
  # One way is to check whether there is a club number. Another way is to look
  # at the club session number which is what is done below.
  my $isTourney = $club_session_num == 0 ? 1 : 0;
 
  $ev->{'tournament_flag'} = $isTourney;
  if (! $isTourney) {
    $ev->{'club_num'} = zstring($data, $p + 0xb0);
    $ev->{'club_session_num'} = $club_session_num;
    $ev->{'club_game_type'} = $CLUB_GAME_TYPE[unpack('C', substr($data, $p + 0xa1))];
  }
  $ev->{'session_num'} = unpack('C', substr($data, $p + 0x8c));
  $ev->{'nstrats'} = unpack('C', substr($data, $p + 0x9e));
  $ev->{'nsessions'} = unpack('C', substr($data, $p + 0x9f));
  $ev->{'nbrackets'} = unpack('C', substr($data, $p + 0xc2)) if $isTeams;
  $ev->{'bracket_num'} = unpack('C', substr($data, $p + 0xc3)) if $isTeams;  
  $ev->{'side_game_flag'} = unpack('C', substr($data, $p + 0x253));
  $ev->{'stratify_by_avg_flag'} = unpack('C', substr($data, $p + 0x2c8));
  $ev->{'non_ACBL_flag'} = unpack('C', substr($data, $p + 0x2ca));
  # The +0 forces Perl's internal representation to be numeric instead of a string.
  # It doesn't matter for Perl but it does alter the JSON output, e.g. 0 instead of "0"
  $ev->{'final_session_flag'} = ($ev->{'session_num'} == $ev->{'nsessions'}) + 0;
  
  my $club_or_tournament = $isTourney ? 'tournament' : 'club';
  my $director_or_city   = $isTourney ? 'city' : 'director';
  zstrings($ev, $data, $p, 'event_name', 0x4, 'session_name', 0x1e, 
    $director_or_city, 0x2c, 'sanction', 0x3d, 'date', 0x48, $club_or_tournament, 0x5c,
    'event_code', 0x76, 'qual_event_code', 0xc5, 'hand_set', 0x244);

  my $rankstr;
  for (my $i=0; $i<$ev->{'nstrats'}; $i++) {
    $ev->{'strat'}[$i] = strat($data, $p + 0xd4 + $i * $STRAT_STRUCTURE_SIZE);
    $rankstr .=  $ev->{'strat'}[$i]{'letter'};
  }
  
  return $rankstr;
}

sub strat {
  if (scalar(@_) != 2) { die "function requires 2 arguments."; }
  my ($data, $p) = @_;
  
  my $st = {
    'first_overall_award' => unpack('v', substr($data, $p + 0x10, 2)) / 100,
    'ribbon_color' => $RIBBON_COLORS[unpack('C', substr($data, $p + 0x12, 1))],
    'ribbon_depth' => unpack('C', substr($data, $p + 0x13, 1)),
    'mpt_factor' => unpack('V', substr($data, $p + 0x14, 4)) / 10000,
    'overall_award_depth' => unpack('v', substr($data, $p + 0x18, 2)),
    'table_basis' => unpack('C', substr($data, $p + 0x1a, 2)),
    'min_mp' => unpack('v', substr($data, $p + 0x1e, 2)),
    'max_mp' => unpack('v', substr($data, $p + 0x20, 2)),
    'letter' => substr($data, $p + 0x22, 1),
    'club_pct_open_rating' => unpack('C', substr($data, $p + 0x23, 1)),
    'pigmentation_breakdown' => {
      'overall' => pigmentation($data, $p + 0x32),
      'session' => pigmentation($data, $p + 0x41),
      'section' => pigmentation($data, $p + 0x50)
    }
  };

}

sub pigmentation {
  if (scalar(@_) != 2) { die "function requires 2 arguments."; }
  my ($data, $p) = @_;
  
  my (@pgset, $i, $j, $mp, $tp);
  my @pct = unpack('v3', substr($data, $p, 6));
  my @mp  = unpack('v3', substr($data, $p+6, 6));
  my @tp  = unpack('C3', substr($data, $p+12, 12));
  
  for ($i=0; $i<3; $i++) {
    last if ! $pct[$i];
    push @pgset, {'pct' => $pct[$i] / 100, 'mp' => $mp[$i] / 100,
      'type' => substr($PIGMENTATION_TYPES, $tp[$i], 1) }; 
  }
  return \@pgset;
}

sub addSectionCombining {
  # Work out how sections are combined and ranked togetherr. Only 
  # combined sections may optionally be ranked together.
  if (scalar(@_) != 2) { die "function requires 2 arguments."; }
  my ($ev, $data) = @_;
  
  my ($prevScore, $prevRank, $nextScore, $nextRank);
  my @combining_and_ranking;

  # Search Master Table for all sections belonging to the event.
  my ($p, $pc, $pr);
  for (my $i=0; $i<$MAX_SECTIONS; $i++) {
    $p = $SECTION_SUMMARY_BASE + $SECTION_SUMMARY_SIZE * $i;
    next if unpack('C', substr($data, $p, 1)) != $ev->{'event_id'};
    
    $prevScore = unpack('C', substr($data, $p + 0xf, 1));
    next if $prevScore != 0;
    # Found first section in a group of combined sections.
    my @combined;
    $pc = $p;
    while (1) {
      $prevRank = unpack('C', substr($data, $pc + 0x11, 1));
      if ($prevRank == 0) {
        # Found first section in a group of sections ranked together (applies to
        # section awards, i.e. N-S and E-W can be ranked across multiple sections).
        my @rankedTogether;
        $pr = $pc;
        while (1) {
          push @rankedTogether, zstring($data, $pr + 0x1);
          $nextRank = unpack('C', substr($data, $pr + 0x12));
          if ($nextRank == 0) { push @combined, \@rankedTogether; last; }
          $pr = $SECTION_SUMMARY_BASE + $SECTION_SUMMARY_SIZE * ($nextRank-1);
        }
      }
      $nextScore = unpack('C', substr($data, $pc + 0x10, 1));
      last if $nextScore == 0;
      $pc = $SECTION_SUMMARY_BASE + $SECTION_SUMMARY_SIZE * ($nextScore-1);      
    }
    push @combining_and_ranking, \@combined;
  }
  
  $ev->{'combining_and_ranking'} = \@combining_and_ranking;
}

sub addSections {
  if (scalar(@_) != 4) { die "function requires 4 arguments."; }
  my ($ev, $data, $opt, $rankstr) = @_;
  
  # Search Master Table for all sections belonging to the event.
  my $p = $SECTION_SUMMARY_BASE;
  for (my $i=0; $i<$MAX_SECTIONS; $i++) {
    $p = $SECTION_SUMMARY_BASE + $i * $SECTION_SUMMARY_SIZE;
    next if unpack('C', substr($data, $p, 1)) != $ev->{'event_id'};
    my $sc = section($data, $p, $opt, $rankstr);
    $ev->{'section'}{$sc->{'letter'}} = $sc; 
  }
}

sub section {
  if (scalar(@_) != 4) { die "function requires 4 arguments."; }
  my ($data, $p, $opt, $rankstr) = @_;
  
  my $sc = {'letter' => zstring($data, $p+1), 'rounds' => unpack('C', substr($data, $p + 0x14)) };

  # Board Results pointer
  my $pBoardIdx = unpack('V', substr($data, $p + 8));
  
  # Move on to Section Details Structure.
  $p = unpack('V', substr($data, $p + 4));

  my @pIndex = unpack('V4', substr($data, $p + 4));
  my $isTeams = ($pIndex[1] == 0);
  my $isIndy  = ($pIndex[3] != 0);
  
  my $highest_pairnum = unpack('v', substr($data, $p + 0x1b));
  
  $sc->{'movement_type'} = $MOVEMENT_TYPE[ unpack('C', substr($data, $p + 0x18)) ] if $isTeams;
  $sc->{'is_barometer'} = unpack('C', substr($data, $p + 0x47)) if ! $isTeams;
  $sc->{'is_web'} = unpack('C', substr($data, $p + 0x60)) if ! $isTeams;
  $sc->{'is_bam'} = unpack('C', substr($data, $p + 0xd5)) if ! $isTeams;
  
  $sc->{'nboards'} = unpack('v', substr($data, $p + 0x19)) if ! $isTeams;
  $sc->{'highest_pairnum'} = $highest_pairnum if ! $isTeams;
  $sc->{'boards_per_round'} = unpack('C', substr($data, $p + 0x1d));
  $sc->{'max_results_per_board'} = unpack('C', substr($data, $p + 0x61)) if ! $isTeams;
  $sc->{'board_top'} = unpack('v', substr($data, $p + 0x1e)) if ! $isTeams;
  $sc->{'ntables'} = unpack('v', substr($data, $p + 0x48));
  
  $sc->{'match_award'} = unpack('v', substr($data, $p + 0xb5)) / 100 if $isTeams;
  $sc->{'maximum_score'} = unpack('v', substr($data, $p + 0x4e));

  return if $opt->{'sectionsonly'};

  my $isHowell = unpack('C', substr($data, $p + 0x18)) == 1 ? 1 : 0;
  my $phantom = unpack('c', substr($data, $p + 0x43));
  ## print $sc->{'highest_pairnum'}, "\n";
  
  my ($i, $j);
  if ($isHowell) {
    # Howell can be a pairs or an individual event.
    $sc->{'is_howell'} = $isHowell;
    if ( !$opt->{'noentries'} ) {    
      my $pPNM = $p + 0xdd;
      my ($pairnum, $table, $dir, $str, $pEntry);
      my @reassign = unpack('C80', substr($data, $p + 0xdd, 80));
      for ($i=1; $i<=$highest_pairnum; $i++) {
        $pairnum = $i;
        next if $pairnum == $phantom;
        $str = substr($data, $pPNM + 0x50 + 2*($pairnum-1), 2);
        ($table, $dir) = unpack('C2', $str);
        $pEntry = unpack('V', substr($data, $pIndex[$dir-1] + 0x10 + 8 * $table, 4));
  
        # Rare pair number reassignments with ACBLscore EDMOV command.
        $pairnum = $reassign[$i-1] if $reassign[$i-1];
  
        $sc->{'entry'}{$pairnum} = entry($data, $pEntry, $rankstr);
      }
    }

    $sc->{'board'} = boards($data, $pBoardIdx, $p, $isIndy) if !$opt->{'noboards'};
  }
  elsif (!$isTeams) {
    # Mitchell movement
    $sc->{'is_howell'} = $isHowell;
    if ( !$opt->{'noentries'} ) {
    my $pPNM = $p + 0xdd;
      my $ndir = $isIndy ? 4 : 2;
      my ($pairnum, $table, $pEntry);
      my @dirletter = ('N', 'E', 'S', 'W'); 
      my @reassign = unpack('C160', substr($data, $p + 0xdd, 160));
      for ($i=1; $i<=$highest_pairnum; $i++) {
        for ($j=0; $j<$ndir; $j++) {
          $pairnum = $i;
          next if $pairnum == $phantom && $j == 0 || $pairnum == -$phantom && $j == 1;
          $table = unpack('C', substr($data, $pPNM + 0xa0 + 4*($pairnum-1) + $j, 1) );
          $pEntry = unpack('V', substr($data, $pIndex[$j] + 0x10 + 8 * $table, 4));
  
          # Rare pair number reassignments with ACBLscore EDMOV command.
          $pairnum = $reassign[4*($i-1)+$j] if $reassign[4*($i-1)+$j];
          
          $sc->{'entry'}{$pairnum . $dirletter[$j]} = entry($data, $pEntry, $rankstr);
        }
      }
    }

    $sc->{'board'} = boards($data, $pBoardIdx, $p, $isIndy) if !$opt->{'noboards'};
  }
  elsif ($isTeams) {
    if ( !$opt->{'noentries'} ) {    
      my ($teamnum, $nplayers, $pTeam, $pEntry);
      my $nteams = unpack('C', substr($data, $pIndex[0] + 6, 1));
      $sc->{'nteams'} = $nteams;
      
      $pTeam = $pIndex[0] + 0x14;
      for ($i=0; $i<$nteams; $i++) {
        $teamnum  = unpack('v', substr($data, $pTeam, 2));
        $nplayers = unpack('v', substr($data, $pTeam + 2, 2));
        $pEntry   = unpack('V', substr($data, $pTeam + 4, 4));
        $sc->{'entry'}{$teamnum} = entry($data, $pEntry, $rankstr, $nplayers);
        $pTeam += 8;
      }
    }
    
    my $pTeamMatch = unpack('V', substr($data, $p + 0x23d));
    $sc->{'matches'} = teamMatches($data, $pTeamMatch, $pIndex[0]);
  }

  return $sc;
}

sub entry {
  if (scalar(@_) != 3 && scalar(@_) != 4) { die "function requires 3-4 arguments."; }
  my ($data, $p, $rankstr, $award, $nplayers) = @_;
  
  my $en;
  my @intfloats = unpack('l<6', substr($data, $p + 0x4, 24));
  
  $en->{'score_adjustment'} = $intfloats[0] / 100;
  $en->{'score_unscaled'}   = $intfloats[1] / 100;
  $en->{'score_session'}    = $intfloats[2] != -1 ? $intfloats[2] / 100 : undef;
  $en->{'score_carrover'}   = $intfloats[3] / 100;
  $en->{'score_final'}      = $intfloats[4] != -1 ? $intfloats[4] / 100 : undef;
  $en->{'score_handicap'}   = $intfloats[5] / 100;
  
  $en->{'pct'} =  unpack('v', substr($data, $p + 0x1c, 2)) / 100;
  $en->{'strat_num'} =  unpack('C', substr($data, $p + 0x1e, 1));
  $en->{'mp_average'} =  unpack('v', substr($data, $p + 0x20, 2));
  $en->{'nboards'} =  unpack('C', substr($data, $p + 0x2f, 1));
  $en->{'eligibility'} =  unpack('C', substr($data, $p + 0x33, 1));

  $award = award($data, $p + 0x34, $rankstr);
  $en->{'award'} = $award if defined $award;
  $en->{'rank'} = rank($data, $p + 0x5e);
  
  # There are three ways to determine the maximum number of players in an entry 
  # structure. The method here is based on the size of the player structure and will
  # return 1, 2, or 6. The second and probably more proper method is to use the number
  # from the entry index table. The third is to infer it from the event type.
  $nplayers = (unpack('v', substr($data, $p + 0, 2)) - 0xa2) / $PLAYER_STRUCTURE_SIZE
    if !defined $nplayers;
  
  for (my $i=0; $i<$nplayers; $i++) {
    $en->{'player'}[$i] = player($data, $p + 0xa4 + $i * $PLAYER_STRUCTURE_SIZE, $rankstr);
  }
  
  return $en;
}

sub player {
  if (scalar(@_) != 3) { die "function requires 3 arguments."; }
  my ($data, $p, $rankstr) = @_;
  
  my ($pl, $award);
  $pl->{'team_wins'} = unpack('v', substr($data, $p + 0x44, 2)) / 100;
  $pl->{'mp_total'}  = unpack('v', substr($data, $p + 0x71, 2));
  $pl->{'acbl_rank_letter'} = substr($data, $p + 0x73, 1);
  $pl->{'acbl_rank'} = $ACBL_PLAYER_RANKS{$pl->{'acbl_rank_letter'}};

  zstrings($pl, $data, $p, 'lname', 0, 'fname', 0x11, 'city', 0x22, 'state', 0x33,
    'pnum', 0x36, 'db_key', 0x3e, 'country', 0x75);
    
  $award = award($data, $p + 0x48, $rankstr);
  $pl->{'award'} = $award if defined $award;

  return $pl;
}

sub award {
  if (scalar(@_) != 3) { die "function requires 3 arguments."; }
  my ($data, $p, $rankstr) = @_;

  my ($awset, $i, $j, @v, $anyAward, $reason);
  for ($i=0; $i<3; $i++) {
    @v = unpack('(vCC)3', substr($data, $p + $i * 12, 12) );
    my @aw;
    for ($j=0; $j<=6; $j+=3) {
      last if ! $v[$j];
      $anyAward = 1;
      $reason = $v[$j+2] ?
        ($v[$j+2] >= 10 ? 'S' : 'O') . substr($rankstr, $v[$j+2] % 10 - 1, 1) : '';
      push @aw, [$v[$j] / 100, substr($PIGMENTATION_TYPES, $v[$j+1], 1), $reason, $v[$j+2]];
    }
    $awset->{ $AWARD_SETS[$i] } = \@aw;
  }
  return $anyAward ? $awset : undef;
}

sub rank {
  if (scalar(@_) != 2) { die "function requires 2 arguments."; }
  my ($data, $p) = @_;
  
  my (@rkset, $i, @v);
  for ($i=0; $i<3; $i++) {
    # Currently not unpacking pointers to next lowest rank.
    @v = unpack('v6', substr($data, $p + $i * 20, 20));
    # Don't include zeros from strats that entry or player is not eligible to
    # be ranked it.
    last if !$v[5];
    my $rk = {'section_rank_low' => $v[0], 'section_rank_high' => $v[1],
      'overall_rank_low' => $v[2], 'overall_rank_high' => $v[3],
      'qual_flag' => $v[4], 'rank' => $v[5] };
    push @rkset, $rk;
  }
  return \@rkset;
}

sub boards {
  if (scalar(@_) != 4) { die "function requires 3 arguments."; }
  my ($data, $pBoardIdx, $pSection, $isIndy) = @_; 
  
  my (%bdset, $i, $j, $k, $bnum, $p, $nresults, $dr);
  my $ncompetitors = $isIndy ? 4 : 2;
  my $fmt = 'CC(vs<V)' . $ncompetitors;
  my $resultSize = 2 + 8 * $ncompetitors;
  my $nboards = unpack('v', substr($data, $pBoardIdx + 4, 4));
  my $kupper = 3 * $ncompetitors + 2;

  # Deal with possible EDMOV pair reassignment, first checking if any reassignments
  # have occurred to minimize time spent in the loops below.
  my $isHowell = unpack('C', substr($data, $pSection + 0x18));
  my @reassign = $isHowell ? unpack('C80', substr($data, $pSection + 0xdd, 80)) :
    unpack('C160', substr($data, $pSection + 0xdd, 160));
  my $anyReassignedPairs = 0;
  # It's not clear if individual reassignments are possible in an individual event.
  # Don't both for such. Individual events are rare and reassignments are rarer.
  if (!$isIndy) { foreach my $val (@reassign) { if ($val) {$anyReassignedPairs = 1; last; } } }

  for ($i=0; $i<$nboards; $i++) {
    my @bd;
    ($bnum, $nresults, $p) = unpack('vvV', substr($data, $pBoardIdx + 0x26 + $i * 8, 8));

    $p += 6;
    for ($j=0; $j<$nresults; $j++) {
      my @v = unpack($fmt, substr($data, $p + $j * $resultSize, $resultSize));
      # Skip if board is not in play on this round.
      next if $v[3] == 999;
      for ($k=2; $k<$kupper; $k+=3) {
        if ($anyReassignedPairs) {
          if ($isHowell) { $v[$k] = $reassign[$v[$k]-1] if $reassign[$v[$k]-1] }
          else {
            # 0 for N-S, 1 for E-W
            $dr = ($k == 5);
            $v[$k] = $reassign[4*($v[$k]-1)+$dr] if $reassign[4*($v[$k]-1)+$dr];
          }  
        }
        if ($v[$k+1] < 900) { $v[$k+1] *= 10; }
        else {
          $v[$k+1] = $SPECIAL_SCORES{$v[$k+1]};
          $v[$k+1] = 'Unknown' if !defined $v[$k+1];
        }
        $v[$k+2] /= 100;
      }
      push @bd, \@v;
    }
    $bdset{$bnum} = \@bd;
  }
  return \%bdset;
}

sub teamMatches {
  if (scalar(@_) != 3) { die "function requires 3 arguments."; }
  my ($data, $p, $pIndex) = @_;
  
  my ($i, $j, $nmatches, $pTMT, $pTME, $vsTeamID);
  
  # Construct mapping from Team Entry ID to Team number.
  my ($nteams, $nrounds) = unpack('vv', substr($data, $p + 4, 4));
  my @tmap = unpack("(vx6)$nteams", substr($data, $pIndex + 0x14, 8 * $nteams));
  my @pTMT = unpack("V$nteams", substr($data, $p + 0x56, 4 * $nteams));
  
  my $tmset;
  for ($i=0; $i<$nteams; $i++) {
    my @tm;
    # Pointer to Team Match Table
    $pTMT = $pTMT[$i];
    # A team might not play all rounds of the event, e.g. when a team gets
    # knocked out of Knockout event.
    $nmatches = unpack('C', substr($data, $pTMT + 4, 1));
    for ($j=0; $j<$nmatches; $j++) {
      # Team Match Entry
      $pTME = $pTMT + 0x22 + $j * $TEAM_MATCH_ENTRY_SIZE;
      $vsTeamID = unpack('v', substr($data, $pTME + 2, 2));
      push @tm, {
        'round' => unpack('C', substr($data, $pTME + 1, 1)),
        'vs_team' => unpack('v', substr($data, $pTME + 2, 2)),
        'IMPs' => unpack('s<', substr($data, $pTME + 8, 2)),
        'VPs' => unpack('v', substr($data, $pTME + 0x0a, 2)) / 100,
        'nboards' => unpack('C', substr($data, $pTME + 0x0d, 1)),
        'wins' => unpack('v', substr($data, $pTME + 0x16, 2)) / 100
      } 
    }
    $tmset->{$tmap[$i]} = \@tm;
  }
  
  return $tmset;
}

# This is required to inform Perl that package has been loaded successfully.
1;
