/*jslint browser: true, vars: true, plusplus: true, continue: true */
"use strict";

function dumphand(hand,showsymb,vert) {
  var suitHTML = ['&spades;', '<span class="hs">&hearts;<\/span>',
		'<span class="ds">&diams;<\/span>', '&clubs;'];
  var suits = hand.split('.');
  var i, ss;
  for (i=0; i<4; i++) {
    if (showsymb) {
      if (suits[i].length === 0) { suits[i] = '-'; }
      suits[i] = suitHTML[i] + suits[i];
    }
  }
  if (vert) { ss = suits.join('<br>'); } else { ss = suits.join(' '); }
  return ss;
}

function pairnameLookup(p, pair_id) {
  var i;
  for (i=0; i < p.length; i+= 3) {
    if (p[i] === pair_id) { return [p[i+1], p[i+2]]; }
  }
  return ['', ''];
}

function flipSpecialScore(str) {
  if (str === 'AVE+') { return 'AVE-'; }
  if (str === 'AVE-') { return 'AVE+'; }
  var ix = str.indexOf('|');
  if (ix === -1) { return str; }
  return str.substr(ix+1,str.length-ix-1) + '|' + str.substr(0,ix);
}

function scoreLookup(bb, mptop, pair_id_nodir, dir, hasContracts, hasLeads) {
  var i;
  var ndataPerResult = 4 + hasContracts + hasLeads;
  if (dir === 'N') {
    for (i=2; i < bb.length; i+= ndataPerResult) {
      if (bb[i] === pair_id_nodir) { return [bb[i-2], bb[i-1], bb[i+1] + 'E', bb[i+2], bb[i+3]]; }
    }
    return [-1];
  }
  if (dir === 'E') {
    for (i=3; i < bb.length; i+= ndataPerResult) {
      if (bb[i] === pair_id_nodir) {
        if (typeof(bb[i-3]) === 'number') {
          return [-bb[i-3], (mptop === undefined) ? -bb[i-2] : mptop - bb[i-2], bb[i-1] + 'N', bb[i+1], bb[i+2]];    
        }
        return [flipSpecialScore(bb[i-3]), mptop - bb[i-2], bb[i-1] + 'N', bb[i+1], bb[i+2]];
      }
    }
    return [-1];
  }

  /* For Howell movement need to check both directions for pair number. */
  for (i=2; i < bb.length; i+= ndataPerResult) {
    if (bb[i] === pair_id_nodir) { return [bb[i-2], bb[i-1], bb[i+1], bb[i+2], bb[i+3]]; }
    if (bb[i+1] === pair_id_nodir) {
      if (typeof(bb[i-2]) === 'number') {
        return [-bb[i-2], (mptop === undefined) ? - bb[i-1] : mptop - bb[i-1], bb[i], bb[i+2], bb[i+3]];
      }
      return [flipSpecialScore(bb[i-2]), mptop - bb[i-1], bb[i], bb[i+2], bb[i+3]];
    }      
  }
  return [-1];

}

function showhideClass(checkboxid, cname) {
  // Show or hide elements with specified class name based on checkbox state.
  // IE8 does not support getElementsByClassName(). However this function is
  // only used for the iPhone specific format.
  var cb = document.getElementById(checkboxid);
  var disp = cb.checked ? '' : 'none';

  document.getElementById("ACBLmerge").getElementsByClassName(cname);
  
  var ids = document.getElementById("ACBLmerge").getElementsByClassName(cname);
  var i;
  
  for(i = 0; i < ids.length; i++) {
    ids[i].style.display = disp;
  }
}

function c1(hnum, west, north, east, south) {
  var w, d, title, css, leftpad, centerpad, marginpad;

  w = window.open('', '', 'width=480,height=720,scrollbars=yes');
  if (w.focus) { w.focus(); }
  d = w.document;

  title = 'Board ' + hnum + ' Cut-and-Paste Aid';
  css = '<style type="text/css">\n' +
    'body, h1 {\n' +
    '  font-family: Arial, Helvetica, sans-serif;\n' +
    '  font-size: 11pt;\n' +
    '  margin-top:    0.6em;\n' +
    '  margin-bottom: 0.4em;\n' +
    '}\n' +
    '.ds, .hs { color: red; }\n' +
    '.fill3x1 { width: 6em; }\n' +
    '<\/style>\n';
    
  d.write('<!DOCTYPE html>\n');
  d.write('<html lang="en">\n<head>\n');
  d.write('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">\n');
  d.write('<title>' + title +'<\/title>\n' + css + '<\/head>\n\n<body>\n\n');

  d.write('<h1>Horizontal North and South hands with and without suit symbols<\/h1>\n');
  d.write(dumphand(north,1,0) + '<br>' + dumphand(south,1,0) + '<br><br>');
  d.write(dumphand(north,0,0) + '<br>' + dumphand(south,0,0) + '<br>\n\n');

  d.write('<h1>Horizontal East and West hands with and without suit symbols<\/h1>\n');
  d.write(dumphand(east,1,0) + '<br>' + dumphand(west,1,0) + '<br><br>');
  d.write(dumphand(east,0,0) + '<br>' + dumphand(west,0,0) + '<br>\n\n');

  d.write('<h1>Bridgify ready format (West, North, East, South)<\/h1>\n');
  d.write(west + '<br>\n' + north + '<br>\n' + east + '<br>\n' + south + '<br>\n\n');
  
  d.write('<h1>Deal in 3x3 HTML table<\/h1>\n');
  d.write('<table><tr><td><\/td><td>' + dumphand(north,1,1) +
	  '<\/td><td><\/td><\/tr>');
  d.write('<tr><td>' + dumphand(west,1,1) + '<\/td><td><\/td><td>' +
	  dumphand(east,1,1) + '<\/td><\/tr>');
  d.write('<tr><td><\/td><td>' + dumphand(south,1,1) +
	  '<\/td><td><\/td><\/tr><\/table>\n\n');

  d.write('<h1>Compact preformatted deal without initial space<\/h1>\n');
  leftpad   = '            ';
  centerpad = '    ';
  d.write('<pre>\n');
  d.write(leftpad + dumphand(north,1,0) + '\n\n');
  d.write(dumphand(west,1,0) + centerpad + dumphand(east,1,0) + '\n\n');
  d.write(leftpad + dumphand(south,1,0) +'\n');
  d.write('<\/pre>\n\n');

  d.write('<h1>Compact preformatted deal with initial space<\/h1>\n');
  d.write('<pre>\n');
  marginpad = '    ';
  leftpad  = marginpad + leftpad;
  d.write(leftpad + dumphand(north,1,0) + '\n\n');
  d.write(marginpad + dumphand(west,1,0) + centerpad +
	  dumphand(east,1,0) + '\n\n');
  d.write(leftpad + dumphand(south,1,0) +'\n');
  d.write('<\/pre>\n\n');

  d.write('<h1>Vertical West and East hands in 3x1 HTML table<\/h1>\n');
  d.write('<table><tr><td>' + dumphand(west,1,1) +
	  '<\/td><td class="fill3x1"><\/td><td>' +
	  dumphand(east,1,1) + '<\/td><\/tr><\/table>\n\n');

  d.write('<h1>Vertical North and South hands in 3x1 HTML table<\/h1>\n');
  d.write('<table><tr><td>' + dumphand(north,1,1) +
	  '<\/td><td class="fill3x1"><\/td><td>' +
	  dumphand(south,1,1) + '<\/td><\/tr><\/table>\n\n');

  d.write('<\/body><\/html>');

  d.close();
}


function recap(pair_id) {
  var p = pairdata();
  var data = boarddata();
  var top = data[0], handix = data[1];
  var hasContracts = data[3], hasLeads = data[4], b = data[5];
  var tmp, oneSection;
  var section, dir, isHowell, title_pair_id, title, pair_id_nodir, pairnames;
  var i, winwidth, w, d, ix, parenturl, parentjs, js, css;
  var bnum, pscore, nscore, pct, cname;
  var psum = 0, nboards = 0, npos = 0, nneg = 0;
  var suit, suitHTML, leadFlag, leadClass, rs, evtpct;
  // var astyle = options().americanstyle;
  var tricks, americanstyle = options().americanstyle;
  
  tmp = b[0][2].charCodeAt(0);
  oneSection = (tmp >= 48 && tmp < 59);

  tmp = pair_id.charCodeAt(1);
  section = pair_id.substr(0, (tmp >= 48 && tmp < 59) ? 1 : 2);

  tmp = pair_id.charAt(pair_id.length-1);
  isHowell = (tmp !== 'N' && tmp !== 'E');
  if (!isHowell) { dir = tmp; } else { dir = ''; }

  title_pair_id = pair_id.substring(section.length, pair_id.length - (isHowell ? 0 : 1));
    
  title = 'Recap for pair ' + title_pair_id;
  if (!isHowell) { title += (dir === 'N' ? ' North-South' : ' East-West'); }
  if (!oneSection) { title += ' (Section ' + section + ')'; }

  pairnames = pairnameLookup(p, pair_id);

  winwidth = 600;
  if (hasContracts) { winwidth += 80; }
  if (hasLeads) { winwidth += 30; }
  w = window.open('', '', 'width=' + winwidth + ',height=720,scrollbars=yes');
  if (w.focus) { w.focus(); }
  d = w.document;
  
  parenturl = window.location.origin + window.location.pathname;
    
  js = '<' + 'script type="text/javascript">\n' +    'function gotobnum(url, bnum) {\n' +
    '  var urlbnum = url + "#board_results" + bnum;\n' +
    '  window.open(urlbnum, url);\n' +
    '}\n' +
    '<\/script>\n';
  
  css = '<style type="text/css">\n' +
    'body, h1 {\n' +
    '  font-size: 11pt;\n' +
    '  margin-top:    0.6em;\n' +
    '  margin-bottom: 0.4em;\n' +
    '}\n' +
    '.center { text-align: center; }\n' +
    '.right { text-align: right; }\n' +
    '.ds, .hs { color: red; }\n' +
    '.results { border-spacing: 1em 0em; }\n' +
    '.results thead { font-weight: bold; }\n' +
    '.bnum { color: blue; }\n' +
    '.bnum:hover { background-color: yellow; text-decoration: underline; }\n' +
    '.top    { background-color: #80FF80; }\n' +
    '.top30  { background-color: #C0FFC0; }\n' +
    '.middle { background-color: white; }\n' +
    '.bottom { background-color: #FF8080; }\n' +
    '.bot30  { background-color: #FFC0C0; }\n' +
    '.opplead { background-color: #FFFFAA; border: solid #606060 1px; padding-left: 1px; padding-right: 1px; }\n' +
    '.badlead { background-color: #FFC0C0; border: solid #606060 1px; padding-left: 1px; padding-right: 1px; }\n' +
    '<\/style>\n';

  d.write('<!DOCTYPE html>\n');
  d.write('<html lang="en">\n<head>\n');
  d.write('<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">\n');
  d.write('<meta http-equiv="Content-Style-Type" content="text/css">\n');
  d.write('<meta http-equiv="Content-Script-Type" content="text/javascript">\n');  
  d.write('<title>' + title +'<\/title>\n\n' + js + '\n' + css + '<\/head>\n<body>\n\n');

  d.write('<h1 class="center">' + title + '<br>' + pairnames[0] + ' &amp; ' + pairnames[1] + '<\/h1>\n\n');
  
  /* Generate results for each board */
  d.write('<table class="results">\n');
  d.write('<thead><tr><td>Board<\/td><td class="right">Plus<\/td><td class="right">Minus<\/td><td class="right">Pts<\/td><td class="right">Pct<\/td>');
  if (hasContracts) { d.write('<td>Contract<\/td>'); }
  if (hasLeads) { d.write('<td>Ld<\/td>'); }
  d.write('<td>Opponents<\/td><\/tr><\/thead>\n');
  d.write('<tbody>\n');

  pair_id_nodir = pair_id;
  if (!isHowell)  { pair_id_nodir = pair_id_nodir.substr(0,pair_id_nodir.length-1); }
  if (oneSection) { pair_id_nodir = pair_id_nodir.substr(section.length); }
  
  for (i=0; i < handix.length; i++) {
    bnum = handix[i];
    rs = scoreLookup(b[i], top, pair_id_nodir, dir, hasContracts, hasLeads);
    if (rs[0] === -1) { continue; }
    
    if (typeof rs[0] === 'number') {
      if (rs[0] >= 0) { pscore = rs[0]; nscore = ''; npos++; }
      else { nscore = -rs[0]; pscore = ''; nneg++; }
    }
    else {
      if (rs[0] === "AVE-") { pscore = ''; nscore = rs[0]; nneg++; }
      else if (rs[0] === "AVE+") { pscore = rs[0]; nscore = ''; npos++; }
      else { pscore = rs[0]; nscore = rs[0]; }
    }

    pct = (undefined !== top) ? 100 * rs[1] / top : undefined;
    psum += pct; nboards++;
    if (oneSection) { pairnames = pairnameLookup(p, pair_id.substr(0,section.length) + rs[2]); }
    else { pairnames = pairnameLookup(p, rs[2]); }

    cname = pct >= 99 ? 'top' : pct >= 70.0 ? 'top30' : pct <= 1.0 ? 'bottom' :
      pct <= 30.0 ? 'bot30' : 'middle';

    parentjs = "gotobnum('" + parenturl + "', " + bnum + ");";

    d.write('<tr><td class="bnum" onclick="'+ parentjs + '">' + bnum + '<\/td><td class="right">' +
      pscore + '<\/td><td class="right">' + nscore + '<\/td><td class="right">' + 
      rs[1].toFixed(2) + '<\/td><td class="right ' + cname + '">' + 
      ((pct === undefined) ? '' : pct.toFixed(2)) + '<\/td>');

    if (hasContracts) {
      if (rs[3] === 'PASS') { d.write('<td>' + 'Pass Out' + '<\/td>'); }
      else if (rs[3] === '') { d.write('<td>' + 'Missing' + '<\/td>'); }
      else {
        suit = rs[3].substr(1,1);
        if (suit === 'N') { suitHTML = 'N'; }
        else if (suit === 'S') { suitHTML = '&spades;'; }
        else if (suit === 'H') { suitHTML = '<span class="hs">&hearts;</span>'; }
        else if (suit === 'D') { suitHTML = '<span class="ds">&diams;</span>'; }
        else if (suit === 'C') { suitHTML = '&clubs;'; }
        if (americanstyle) {
          d.write('<td>' + rs[3].substr(0,1) + suitHTML);
          if ( rs[3].substr(rs[3].length-3,1) === ' ' ) { 
            if ( rs[3].substr(rs[3].length-2,1) === '-' ) { 
              d.write(rs[3].substr(2,rs[3].length-2) + '<\/td>');
            }
            else {
              tricks = parseInt(rs[3].substr(0,1),10) + parseInt(rs[3].substr(rs[3].length-1,1),10);
              d.write(rs[3].substr(2,rs[3].length-4) + tricks + '<\/td>');
            }
          }
          else {
            d.write(rs[3].substr(2,rs[3].length-2) + ' ' + rs[3].substr(0,1) + '<\/td>');
          }
        }
        else {
          d.write('<td>' + rs[3].substr(0,1) + suitHTML + rs[3].substr(2,rs[3].length-2) + '<\/td>');
        }
      }
    }

    if (hasLeads) {
      if (rs[3+hasContracts].length === 0) { d.write('<td><\/td>'); }
      else {
        suit = rs[3+hasContracts].substr(0,1);
        if (suit === 'S') { suitHTML = '&spades;'; }
        else if (suit === 'H') { suitHTML = '<span class="hs">&hearts;</span>'; }
        else if (suit === 'D') { suitHTML = '<span class="ds">&diams;</span>'; }
        else if (suit === 'C') { suitHTML = '&clubs;'; }
        if (rs[3+hasContracts].length === 2) {
          d.write('<td>' + suitHTML + rs[3+hasContracts].substr(1,1) + '<\/td>');
        }
        else {
          leadFlag = rs[3+hasContracts].substr(2,1);
          if (leadFlag === '=') { leadClass = 'opplead'; }
          else if (leadFlag === '?') { leadClass = 'badlead'; }
          d.write('<td><span class="' + leadClass + '">' + suitHTML +
            rs[3+hasContracts].substr(1,1) + '<\/span><\/td>');
        }
      }
    }
    d.write('<td>' + pairnames[0] + ' - ' + pairnames[1] + '<\/td><\/tr>\n');
  }
  
  d.write('<\/tbody>\n');
  d.write('<\/table>\n\n');
  
  evtpct = psum / nboards;
  d.write('<p>Session: ' + evtpct.toFixed(2) + '%&nbsp;&nbsp;&nbsp;Plus Scores: ' + npos  +
    '&nbsp;&nbsp;&nbsp;Minus Scores: ' + nneg + '</p>\n');

  d.write('<\/body><\/html>');

  d.close();
}


