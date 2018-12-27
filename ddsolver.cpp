//  ddsolver.cpp
//
//  Matthew J. Kidd (San Diego, CA)
//
//  Simple wrapper for Bo Haglund's Double Dummy Solver (dds.dll)
//
//  Note: This code works but Windows C++ development isn't my strength. This
//  code shouldn't be considered a model reference.
//
//  To compile the code using the Microsoft C compiler from the Visual Studio
//  Command Prompt on a 32-bit Windows computer
//
//    cl /EHsc ddsolver.cpp
//
//  You don't need to compile this code with optimization (e.g. /O2). All
//  the CPU intensive work is done in Bo Haglund's dds.dll, which is compiled
//  with optimization on.
//
//  If you are compiling on a 64-bit Windows platform, you need to make sure
//  you create a 32-bit executable (target) instead of a 64-bit executable
//  because a 64-bit one will not be able to use the 32-bit dds.dll. You
//  might think this would be done with a compiler switch, but you would be
//  wrong. If you have MSVC installed on a 64-bit platform, you will have
//  several versions of the compile/linker program (cl). See this web page:
//  http://msdn.microsoft.com/en-us/library/x4d2c09s.aspx. You should be okay
//  if you run cl from the "Visual Studio Command Prompt". Do not choose the
//  "Visual Studio x64 Win64 Command Prompt" or the "Visual Studio x64 Cross
//  Tools Command Prompt".
//
//  To compile the code for Mac OS X with gcc, use:
//
//    gcc-4.9 -o ddsolver -O2 -Wall ddsolver.cpp dds.a -lstdc++ -lgomp
//
//  A specific version of gcc (4.9) is referenced here (installed via Homebrew,
//  see http://brew.sh/) though other recent versions should work. The issue is
//  that DDS 2.1 (2010-05-29) and later use OpenMP for parallelization on
//  non-Windows platforms. GCC supports OpenMP but the Apple XCode clang (LLVM)
//  compiler doesn't. But out of the box, XCode 4.2 and later symlinks gcc to
//  clang. Specifying gcc-#.# ensures you are really using GCC.
//
//  Here dds.a is a library created from all the C++ files as follows:
//
//    gcc-4.9 -c -W -O2 -fopenmp foo.cpp  (for each C++ file)
//    ar rc dds.a *.o  (create an archive)
//    ranlib dds.a  (index it to make a static library)
//
//  Of course a simple make file will save manually compiling each C++ file.
//
//  14-Nov-2014 - Last revsion
//  08-Mar-2012 - Original code by Matthew Kidd

// Not necessary, but might speed up compilation.
#if defined(_MSC_VER)
#define WIN32_LEAN_AND_MEAN
#endif

#define VER_STR "1.1"

#define SUCCESS                 0
#define ERR_DDS_LOAD_FAILED     1
#define ERR_NO_CalcDDtablePBN   2
#define ERR_BAD_INPUT_FILE      3
#define ERR_BAD_OUTPUT_FILE     4

#if defined(_WIN32)
// Minimum version of Windows (0x0501 = XP).
// If this is not defined, Microsoft compiler will generate a warning.
// See http://msdn.microsoft.com/en-us/library/aa383745%28VS.85%29.aspx
#define _WIN32_WINNT 0x0501
#include <afxwin.h>
#endif

#if defined(__APPLE__)
#include <unistd.h>
#endif

#include <stdio.h>
#include <string.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <ctime>
#include "dll.h"

using namespace std;


double diffclock(clock_t clock1, clock_t clock2) {
  double diffticks = clock1 - clock2;
  double diff = diffticks / CLOCKS_PER_SEC;
  return diff;
}


int main(int argc, char* argv[]) {
  char *infname = NULL;
  char *outfname = NULL;

#if defined(_WIN32)
  HRESULT hResult;
  LPVOID lpMsgBuf;
#endif

  struct ddTableDealPBN pbn;
  struct ddTableResults ddtable; 
  int rs;
  int verbose = 1;
  int showVersion = 0;
  int assumePBN = 0;
  ifstream fd;
  FILE *ofd;
  int slen, soff;
  string fline;
  char hline[70];
  clock_t stime, etime;
  double elapsedTime;

  if (argc < 2) {
    cout << "\n" <<
      "  Usage ddsolver [-q] [-v] [-p] infname [outfname]\n\n" <<

      "  Calculates full double dummy results (5 denominations x 4 seats) for a\n" <<
      "  set of boards using Bo Haglund's double dummy solver (dds.dll).\n\n" <<

      "  -q  - Quiet. Do not show progress on the command line.\n" <<
      "  -v  - Print version and compilation date on stdout.\n" <<
      "  -p  - Assume PBN format even if file extension is not .pbn or .PBN\n\n" <<

      "  infname  - Filename of boards (one per line) in PBN / GIB format, e.g.\n\n" <<

      "     W:T5.K4.652.A98542 K6.QJT976.QT7.Q6 432.A.AKJ93.JT73 AQJ987.8532.84.K\n\n" <<

      "     Hands are clockwise, starting with the one indicated by the first\n" <<
      "     letter. If the first hand designator is missing, West is assumed (the\n" <<
      "     GIBlib default). Extra characters on a line (e.g. existing double dummy\n" <<
      "     results) are ignored.\n\n" <<

      "  outfname - Output filename. If not specified, output is written to STDOUT\n" <<
      "             All other messages are written to STDERR.\n\n" <<

      "  ddsolver is open source released under the GNU General Public License GPLv3.\n" <<
      "  Written by Matthew Kidd (San Diego, CA)\n" << endl;

    return SUCCESS;
  }

  int nonSwitchCnt = 0;
  for (int i=1; i<argc; i++) {
    if (argv[i][0] == '-') {
      if ( strcmp(argv[i], "-q") == 0 ) { verbose = 0; }
      else if ( strcmp(argv[i], "-v") == 0 ) { showVersion = 1; }
      else if ( strcmp(argv[i], "-p") == 0 ) { assumePBN = 1; }
      else {
        fprintf(stderr, "Unrecognized switch %s ignored.\n", argv[i]);
      }
    }
    else {
      nonSwitchCnt++;
      if (nonSwitchCnt == 1) { infname = argv[i]; }
      else if (nonSwitchCnt == 2) { outfname = argv[i]; }
    }
  }

  if (showVersion) {
    fprintf(stderr, "ddsolver %s (compiled %s %s)\n", VER_STR, __DATE__, __TIME__);
  }
  if (!infname) {
    fprintf(stderr, "No input file specified.\n");
    return SUCCESS;
  }

  if ( strlen(infname) >= 4 && ( strcmp(&infname[strlen(infname)-4], ".pbn") == 0 ||
    strcmp(&infname[strlen(infname)-4], ".PBN") == 0 ) ) {
    assumePBN = 1;
  }


#if defined(_WIN32)
  HINSTANCE hDLL = LoadLibrary("dds.dll");
  if (!hDLL) {
    hResult = GetLastError();
    DWORD dwNumChar = FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, hResult, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &lpMsgBuf, 0, NULL);
    if (dwNumChar) {
      fprintf(stderr, "Unable to load dds.dll (error 0x%08x)\n%s\n", hResult, (LPTSTR) lpMsgBuf);
    }
    else {
      fprintf(stderr, "Unable to load dds.dll (error 0x%08x)\n", hResult);
    }
    if (hResult == 0x7E) {
      cerr <<
        "The dds.dll file can be obtained from http://privat.bahnhof.se/wb758135\n" <<
        "Use version 2.1.2 or later, compiled with PBN support. Place dds.dll in\n" <<
        "the same folder as this program or elsewhere on the system search path.\n" << endl;
    }
    else if (hResult == 0xC1) {
      cerr <<
        "This error is usually the result of a 64-bit application trying to use a\n" <<
        "32-bit DLL or vice versa. If you are recompiling this program on a 64-bit\n" <<
        "Windows platform, set the compiler to create a 32-bit target.\n" << endl;
    }
    LocalFree(lpMsgBuf);
    return ERR_DDS_LOAD_FAILED;
  }
  
  FARPROC hFunc = GetProcAddress(HMODULE (hDLL), "CalcDDtablePBN");
  if (!hFunc) {
    hResult = GetLastError();
    DWORD dwNumChar = FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, hResult, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &lpMsgBuf, 0, NULL);
    fprintf(stderr, "Unable to resolve CalcDDtablePBN() in dds.dll (error 0x%08x)\n%s\n",
      hResult, (LPTSTR) lpMsgBuf);
    if (hResult == 0x7F) {
      cerr <<
        "Make sure you have version 2.1.2 or later of the dds.dll, compiled with PBN\n" <<
        "support. Earlier versions do not contain the CalcDDtablePBN() function. The\n" <<
        "current dds.dll can be obtained from http://privat.bahnhof.se/wb758135\n" << endl;
    }
    LocalFree(lpMsgBuf);
    return ERR_NO_CalcDDtablePBN;
  }

  typedef int (__stdcall * pICFUNC)(struct ddTableDealPBN, struct ddTableResults *);
  pICFUNC CalcDDtablePBN = pICFUNC(hFunc);
#endif

#if defined(__APPLE__)
  // DDS 2.7.0 Init.cpp doesn't have logic to determine the number of cores and amount
  // of free memory for Mac OS in order to determine the maximum number of threads. Set
  // a value appropriate for the Mac Air though higher end Mac Books may have more cores.
  // If no value is set SolveBoard will return error -15 when used by CalcDDtablePBN().
  int ncores = sysconf(_SC_NPROCESSORS_ONLN);
  SetMaxThreads(ncores);
#endif


  fd.open(infname, ios::in);
  if (! fd.is_open()) {
    cerr << "Unable to open/read file: " << infname << endl; return ERR_BAD_INPUT_FILE;
  }
  if (outfname) {
    if ( (ofd = fopen(outfname, "w")) == NULL ) {
      cerr << "Unable to open/write file: " << outfname << endl; return ERR_BAD_OUTPUT_FILE;
    }
  }
  else {
    ofd = stdout;
  }

  stime = clock();
  int firstHandDefined, nBlankLines = 0;
  unsigned int nboards = 0;

  soff = assumePBN ? 7 : 0;
  while ( fd.good() ) {
    getline(fd, fline);
    if (fline.length() == 0) { nBlankLines++; continue; }

    // Echo back empty lines (except at end of file) for GIB format so there is a one
    // to one correspondence between input and output file lines.
    if (! assumePBN) {
      for (int i=0; i<nBlankLines; i++) { fprintf(ofd, "\n"); }
      nBlankLines = 0;
    }

    // Skip lines in PBN files that are not Deal lines.
    if (assumePBN && fline.compare(0, 7, "[Deal \"") != 0) { continue; }
    
    // Start clean. PBN.CARDS is 80 characters but the dds.dll reference doesn't say
    // how to fill the extra characters at the end. Assume spaces with null termination.
    memset(pbn.cards, ' ', sizeof(pbn.cards)); pbn.cards[79] = '\0';
    
    // Each hand is 13 card + 3 suit separators (periods) for 16 characters. For hands
    // plus three hand separators (spaces) is 67 characters. Add two more if first hand
    // has a prefix designator, e.g. W:
    slen = fline.length() - soff;
    if (assumePBN) { slen -= 2; }
    if (slen > 69) { slen = 69; }
    strcpy(hline, fline.substr(soff,slen).c_str());

    firstHandDefined = (hline[0] == 'W' || hline[0] == 'N' || hline[0] == 'E' || hline[0] == 'S');
    if (firstHandDefined) {
      strncpy(pbn.cards, hline, 69);
    }
    else {
      // Assume first hand is West if not specified.
      strcpy(pbn.cards, "W:");
      strncpy(&pbn.cards[2], hline, 67);
    }

    // cerr << fline << endl;
    // fprintf(stderr, "[%s]\n", pbn.cards);

    // Note: CalcDDtablePBN can hang if the hands do not have the same number of cards.
    // Internally, SolveBoard() appears to return Error -14 (Wrong number of remaining
    // cards for a hand) but this code does not seem to ripple up through CalcDDtablePBN.
    // Instead a dump.txt file is created and the DLL hangs. Therefore, it might be good
    // to add tighter input checking later.
    rs = CalcDDtablePBN(pbn, &ddtable);
    if (rs == 1) {
      // Success. Write out GIBlib order that ACBLmerge.pl expects, i.e. No Trump, Spades,
      // Hearts, Diamonds, Club assuming LEAD is from South, East, North, West respectively
      // (Note this order is counterclockwise rather than the clockwise order one might
      // expect from how bridge hands are played). This is slightly different than the order
      // CalcDDtablePBN() presents the results.
      fprintf(ofd, "%s:", fline.substr(soff,firstHandDefined ? 69 : 67).c_str());
      
      int denom, seat, tricks;
      for (int i=0; i<5; i++) {
        // CalcDDtablePBN() reports S,H,D,C,N. Rotate to N,S,H,D,C.
        if (i == 0) { denom = 4; } else { denom = i-1; }
        for (int j=0; j<4; j++) {
          // CalcDDtablePBN() reports declarer N,E,S,W. Switch order to E,N,W,S.
          if (j < 2) { seat = 1-j; } else { seat = 5-j; }
          // CalcDDtablePBN() reports the number of tricks for declarer but GIBlib format
          // records the number of tricks for N-S. Flip E-W trick values.
          tricks = ddtable.resTable[denom][seat];
          fprintf(ofd, "%X", j % 2 ? tricks : 13-tricks);
        }
      }
      fprintf(ofd, "\n");
      nboards++;

      if (verbose) {
        etime = clock();
        elapsedTime = diffclock(etime,stime);
        fprintf(stderr,
          "\rDouble dummy analysis completed for %d board%s in %d m %d s (%0.2f sec/board ave)",
          nboards, nboards == 1 ? "" : "s",
          (int) elapsedTime / 60, (int) elapsedTime % 60, elapsedTime / nboards);
      }
    }
    else {
      fprintf(ofd, "Error %d\n", rs);
    }

  }

  fd.close();
  if (ofd != stdout) { fclose(ofd); }
  if (verbose) fprintf(stderr, "\n");


  // Test code.
  if (0) {
    strncpy(pbn.cards,
      "W:AQT96.42.65.K543 873.6.AKT9.AQT87 KJ52.AKQJT8.8.J6 4.9753.QJ7432.92          ",
      // "W:T5.K4.652.A98542 K6.QJT976.QT7.Q6 432.A.AKJ93.JT73 AQJ987.8532.84.K          ",
      80);

    rs = CalcDDtablePBN(pbn, &ddtable);
    if (rs == 1) {
      // Success
      for (int denom=0; denom < 5; denom++) {
        for (int seat=0; seat < 4; seat++) {
          printf("%X", ddtable.resTable[denom][seat]);
        }
        if (denom < 4) { printf(" "); }
      }
    }
    else {
      printf("CalcDDtablePBN returned error code: %d\n", rs);
    }
  }

#if defined(_WIN32)
  FreeLibrary(hDLL);
#endif

  return SUCCESS;
}
