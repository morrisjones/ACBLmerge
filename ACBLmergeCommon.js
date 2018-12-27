/*jslint browser: true, vars: true, plusplus: true, continue: true */
/*global ActiveXObject */
"use strict";

var xmlhttp = null;

function CreateXmlHttpReq(handler) {
  var xmlhttp = null;

  if (window.XMLHttpRequest) { xmlhttp = new XMLHttpRequest(); }
  else if (window.ActiveXObject) {
    // Fallback to Active-X but catch users with Active-X turned off.
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) {}
  }

  if (xmlhttp) { xmlhttp.onreadystatechange = handler; }
  return xmlhttp;
}

function XmlHttpGET(xmlhttp, url) {
  try {
    xmlhttp.open("GET", url, false);
    xmlhttp.send(null);
  } catch (e) {}
}

function resultHandler () {
  // request is 'ready'
  if (xmlhttp.readyState === 4) {
    if (xmlhttp.status !== 200 && typeof console && typeof console.log) {
        console.log("Problem retrieving the data:\n" + xmlhttp.statusText);
    }
  }
}

function binaryIsIn(v, num) {
  if (v === undefined || !v.length) { return 0; }

  var high = v.length - 1, low = 0, mid, element;

  while (low <= high) {
    mid = parseInt((low + high) / 2, 10);
    element = v[mid];
    if (element > num) { high = mid - 1; }
    else if (element < num) { low = mid + 1; }
    else { return 1; }
  }
  return 0;
}

var tooltip = ( function() {
  var id = 'tooltip';
  var top = 3, left = 3, maxw = 300;
  var speed = 10, timer = 20;
  var endalpha = 95, alpha = 0;
  var tt, img, spn, h;
  var ie = document.all ? true : false;
  var FACEJSON = '/cgi-bin/facejson.pl';
  var faceCB, faceOption, faceShow, facedir, faceids;
  var jsonfailed;

  return {
    show:function(pnum,pname,str,width) {
      var data;
      if (faceOption === undefined) {
        faceCB = document.getElementById('showfacesCB');
        faceOption = (faceCB !== null);
      }
      faceShow = faceOption && faceCB.checked && !jsonfailed && pnum;
      if (faceShow && facedir === undefined) {
        // Get face directory and list of player numbers for players
        // who have a face images on the server.
        // console.log('Retrieving face data (as JSON) from ' + FACEJSON);
        xmlhttp = new CreateXmlHttpReq(resultHandler);
        if (xmlhttp) {
          XmlHttpGET(xmlhttp, FACEJSON);
          var response = xmlhttp.responseText;
          if (window.JSON) { data = JSON.parse(response); }
          else {
            // Legacy handling for IE6, IE7, and IE in Quirks document mode.
            // Sanitization (See http://tools.ietf.org/html/rfc4627)
            data = !(/[^,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]/.test(
              response.replace(/"(\\.|[^"\\])*"/g, ''))) && eval('(' + response + ')');
          }    
          facedir = data[0];
          faceids = data[1];
        }
        else { jsonfailed = 1; faceShow = 0; }
      }
      if (faceShow) { faceShow = binaryIsIn(faceids, pnum); }
    
      if (tt === undefined) {
        tt = document.createElement('div');
        tt.setAttribute('id', id);
        document.body.appendChild(tt);
        tt.style.opacity = 0;
        tt.style.filter = 'alpha(opacity=0)';
        document.onmousemove = this.pos;
        spn = document.createElement('span');
        tt.appendChild(spn);
      }
      if (!faceShow && !str) { tt.style.display = 'none'; return; }
      
      if (faceShow) {
        if (!img) { img = tt.insertBefore(document.createElement('img'), spn); }
        img.src = facedir + '/' + pnum + '.jpg';
        if (str) {
          tt.style.textAlign = 'left';
          img.align = 'left';
          img.style.marginRight = '0.6em';
          spn.innerHTML = pname + '<br><br>' + str;
        }
        else {
          tt.style.textAlign = 'center';
          img.align = 'center';
          spn.innerHTML = '<br clear=all>' + pname;
        }             
      }
      else {
        if (img) { tt.removeChild(img); img = undefined; }
        spn.innerHTML = str;
      }

      tt.style.display = 'block';
      tt.style.width = width ? width + 'px' : 'auto';
      if (!width && ie) { tt.style.width = tt.offsetWidth; }
      if (tt.offsetWidth > maxw) { tt.style.width = maxw + 'px'; }
      h = parseInt(tt.offsetHeight,10) + top;

      clearInterval(tt.timer);
      tt.timer = setInterval( function(){ tooltip.fade(1); }, timer);
    },

    pos:function(e) {
      if (tt.style.display === 'none') { return; }
      var u = ie ? event.clientY + document.documentElement.scrollTop  : e.pageY;
      var l = ie ? event.clientX + document.documentElement.scrollLeft : e.pageX;
      tt.style.top = (u - tt.offsetHeight) + 'px';
      tt.style.left = (l + left) + 'px';
    },

    fade:function(d) {
      var a = alpha;
      if ((a !== endalpha && d === 1) || (a !== 0 && d === -1)) {
        var i = speed;
        if (endalpha - a < speed && d === 1) { i = endalpha - a; }
        else if (alpha < speed && d === -1) { i = a; }
        alpha = a + (i * d);
        tt.style.opacity = alpha * 0.01;
        tt.style.filter = 'alpha(opacity=' + alpha + ')';
      }
      else {
        clearInterval(tt.timer);
        if (d === -1) { tt.style.display = 'none'; }
      }
    },

    hide:function() {
      clearInterval(tt.timer);
      tt.timer = setInterval( function(){ tooltip.fade(-1); }, timer);
    }
  };
}() );


