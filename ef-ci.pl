#!/usr/bin/env ec-perl
#############################################################################
#
# Copyright 2015 Electric-Cloud Inc.
#
# Author: L. Rochette (lrochette@electric-cloud.com)
#
# Changelog
#
# Date          Who         Comment
# ---------------------------------------------------------------------------
# 2015-12-31    lrochette   Manage projects created with projectAsCode
#############################################################################
use strict;
use English;
use Fcntl ':mode';
use ElectricCommander;
use Data::Dumper;
use Getopt::Long 'GetOptions';
use File::Find;
use Term::ANSIColor;

$| = 1;             # Force flush

# Check for the OS Type
my $osIsWindows = $^O =~ /MSWin/;

#############################################################################
#
# Global variables
#
#############################################################################
my $version = "0.2";
my $tsFile = ".efci";          # filename where the timestamp is saved
my $DEBUG=1;
my $server="localhost";         # Default server name
my $user="admin";              # default user name
my $password="changeme";       # Default password
my $efciDir=".";               # Default directory where to pick up code
my $timestamp="1";             # a long time ago (Default timestamp)
my $force="0";                 # To force all files parsing
my $ntest="ec-testing/ntest";  # Testing mode

# color Definitions
my $plusColor='blue';
my $errorColor='red';
my $okColor='green';

# Create a single instance of the Perl access to ElectricCommander
my $ec = undef;

#############################################################################
# invokeCommander
#    Invoke any API call
# Args:
#   optionFlags: SuppressLog, SuppressResult and/or IgnoreError as a string
#   function:    API call to make
#   parameters: in the same form than a normal API call
#
# Return:
#   success: 1 for success, 0 for error
#   result:  the JSON block returned by the API
#   errMsg: full error message
#   errCode: error code
#############################################################################
sub invokeCommander {

    my $optionFlags = shift;
    my $commanderFunction = shift;
    my $result;
    my $success = 1;
    my $errMsg;
    my $errCode;

    my $bSuppressLog = $optionFlags =~ /SuppressLog/i;
    my $bSuppressResult = $bSuppressLog || $optionFlags =~ /SuppressResult/i;
    my $bIgnoreError = $optionFlags =~ /IgnoreError/i;

    # Run the command
    # print "Request to Commander: $commanderFunction\n" unless ($bSuppressLog);

    $ec->abortOnError(0) if $bIgnoreError;
    $result = $ec->$commanderFunction(@_);
    $ec->abortOnError(1) if $bIgnoreError;

    # Check for error return
    if (defined ($result->{responses}->[0]->{error})) {
        $errCode=$result->{responses}->[0]->{error}->{code};
        $errMsg=$result->{responses}->[0]->{error}->{message};
    }

    if ($errMsg ne "") {
        $success = 0;
    }
    if ($result) {
        print "Return data from Commander:\n" .
               Dumper($result) . "\n"
            unless $bSuppressResult;
    }

    # Return the result
    return ($success, $result, $errMsg, $errCode);
}

#############################################################################
# login
#   initiate a login session with commander server
# Args:
#     None
#############################################################################
sub login {
  $ec->login($user, $password);
}

#############################################################################
# processDirectory
#   parse all files and directories inside the current directory
# Args:
#     directory name
#     level
#############################################################################
sub processDirectory {
  my ($dir, $level)=@_;

  my $indent=" +" x $level;
  #printf ("%s %s\n", colored($indent,$plusColor), $dir);
  opendir(my $dh, $dir) or die("Cannot open $dir: $!");
  my @content=readdir $dh;

  foreach my $filename (@content) {
    next if $filename =~ /^\./;   # skip ., .. and hidden files
    # get file information
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
    $atime, $mtime, $ctime, $blksize, $blocks) = stat("$dir/$filename");


    if (S_ISDIR($mode)) {
      processDirectory("$dir/$filename", $level+1);
    }
    next if ($mtime <= $timestamp);

    my $path="$dir/$filename";
    if ($filename =~ /.(pl|sh)$/) {
      my ($project, $nothing, $procedure, $file) = ($path =~
        m#([^/]+)(/src/project)?/procedures/([^/]+)/steps/(.+)$#);
      # step name is name of command minus extension
      my ($step) = ($file =~ m/([^\.]+)\./);
      next if (($step eq "") );
      printf ("%s %s\n", colored($indent,$plusColor), $dir);
      printf("  %s %s", "  "x $level, $filename);
      #printf("\npath: $path\n");
      #printf("\tpj: $project, pc: $procedure, s: $step, f: $file");
      my($ok, $json, $errMsg, $errCode)=
        invokeCommander("SuppressLog IgnoreError",
            'setProperty', 'command', {
               projectName => $project,
               procedureName => $procedure,
               stepName => $step,
               valueFile => $path
             }
      );
      if ($ok) {
         printf (" (%s)\n", colored("OK", $okColor));
      } else {
         printf("\n%s\n", colored($errMsg, $errorColor));
      }
    } elsif ($filename =~ /.ntest$/) {
        system("$ntest --testout=/tmp/ --target=$server $dir/$filename");
    } elsif ($filename =~ /help.xml$/) {
      my ($project) = ($path =~ m#([^/]+)/src/pages/help.xml$#);
      # step name is name of command minus extension
      next if (($project eq "") );
      printf ("%s %s\n", colored($indent,$plusColor), $dir);
      printf("  %s %s", "  "x $level, $filename);
      #printf("\npath: $path\n");
      #printf("\tpj: $project, pc: $procedure, s: $step, f: $file");
      my($ok, $json, $errMsg, $errCode)=
        invokeCommander("SuppressLog IgnoreError",
            'setProperty', 'help', {
               projectName => $project,
               valueFile => $path
             }
      );
      if ($ok) {
         printf (" (%s)\n", colored("OK", $okColor));
      } else {
         printf("\n%s\n", colored($errMsg, $errorColor));
      }

    }
  }
  closedir $dh;
}

#############################################################################
# Usage
#
#############################################################################
sub usage {
  printf("
Copyright 2015 Electric Cloud
efci.pl $version: import step commands into ElectricFlow

Options:
 --server    SERVER     ElectricFlow server
 --user      USER       username
 --password  PASSWORD   password
 --directory DIR        server directory to monitor and parse
 --test      PATH       path to ntest
 --force                ignore timestamp and re-eval DSL
 --help                 This page
");
  exit(1);
}

#############################################################################
#
# Main
#
#############################################################################

# parse optionFlags
#
GetOptions(
  'server=s'    => \$server,
  'user=s'      => \$user,
  'password=s'  => \$password,
  'directory=s' => \$efciDir,
  'test=s'      => \$ntest,
  'force'       => \$force,
  'help'        => \&usage) || usage();

# Create a single instance of the Perl access to ElectricCommander
$ec = new ElectricCommander({server=>$server, format => "json"});

login();

# Reset existing timestamp if  in FORCE mode
if ($force || ! -f "$efciDir/$tsFile") {
  open(my $fh, "> $efciDir/$tsFile")
    || print("Warning: cannot save timestamp in $efciDir/$tsFile!\n$!\n");
  print $fh "1";
  close($fh);
  utime  1,1, "$efciDir/$tsFile"
}

# Read timestamp
$timestamp=`cat "$efciDir/$tsFile"`;

printf("Slurping steps and tests from $efciDir:\n");

while(1) {
  my @newFiles=`find $efciDir -type f -newer $efciDir/$tsFile`;
  #print(@newFiles) if ($DEBUG);

  if (@newFiles) {
    # found new files
    # save previous timestamp (so files created during process will be eval'ed next round)
    my $newTimestamp=time();
    processDirectory($efciDir, 0);

    # Write old timestamp just after the find
    # so next roud, files modified during the process will be found
    open(my $fh, "> $efciDir/$tsFile")
      || print("Warning: cannot save the timestamp in $efciDir/$tsFile!\n$!\n");
    print $fh $newTimestamp;
    # set time used for processDirectory
    $timestamp=$newTimestamp;
    close($fh);

    printf("\n\n");
    system("date");
  }
  else {
    # print (".") if ($DEBUG);
  }
  sleep(2);
}
