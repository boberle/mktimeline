#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;


BEGIN {
   unshift @INC, '.';
}

use SVGTL;

$0 = 'mktl';
our $VERSION = "02-feb-2013 (c) Bruno Oberle";

########################################################################
# WHAT IT DOES:
#
# See the help text.
########################################################################


########################################################################
# GLOBAL VARIABLES
########################################################################

# the .tl config file
my $TL_FILE = '';

# the .svg output file
my $OUTPUT_FILE = '';


########################################################################
# Look for options at the beginning of ARGV.
########################################################################

my $HELP_TEXT = <<"END";
USAGE:
  $0 [OPTIONS] TIMELINE_FILE

DESCRIPTION:
  Convert a text-based timeline file into a svg graphic.

  Data are divided in two types of files:
    - a timeline file (.tl) which contains a list of date files, parameters
      specific to each data file and parameters for the whole svg graphic;
    - one or more date file (.events) which contains raw dates and events.

  Format of the timeline file:
  ----------------------------
    # this is a comment
    # white lines ignored
    # order IS important (only if OFFSET_LEVEL is -)
    DATA_FILE_1 : DEFAULT_COLOR [ : TITLE ]
    DATA_FILE_2 etc.
    ...
    # format options are explained in the SVGTL perl module
    FORMAT_OPTION_1=VALUE
    FORMAT_OPTION_2=VALUE
    ...

  If OFFSET_LEVEL is '-', then the highest level encountered so far will
  be used.  The best way to manage levels is to put '-' everywhere.

  Format of the events file:
  --------------------------
    # comment
    # white lines ignored
    # order is not important
    # START_DATE/END_DATE = [~] [day] [month] year [bc|ad]
    START_DATE [ - END_DATE ] [~] : LEVEL [ : COLOR ]
    EVENT_DESCRIPTION
    START_DATE [ - END_DATE ] [~] : LEVEL [ : COLOR ]
    EVENT_DESCRIPTION
    ...

OPTIONS (only allowed with the format -o=param):
  -h        Print this.
  -o=FILE   Output file.  Default 'output.svg'.

Version: $VERSION
END

sub get_options {

   # default:
   $OUTPUT_FILE = 'output.svg';
   $TL_FILE = '';

   for (@ARGV) {

      if (m/^\-o=(.++)$/) {
         $OUTPUT_FILE = $1;
      } elsif (m/^\-h$/) {
         print $HELP_TEXT;
         exit;
      } elsif (m/^\-(.*+)/) {
         die "$0: *** bad option '$1' ***\n";
      } else {
         die "$0: *** too many options ***\n" if $TL_FILE;
         $TL_FILE = $_ unless m/^\s*+#/;
      }

   }

   die "$0: *** no source files ***\n" unless $TL_FILE;

   @ARGV = ();

}

########################################################################
# Read the $TL_FILE which contains a list of .events file and some
# global config options for the timeline.
########################################################################

sub read_tl_file {

   my $file = shift;
   my $r_events = shift; # array of all the events (empty)
   my $r_titles = shift; # array of all the file titles (empty)
   my $r_options = shift; # hash of all the timeline options (already
                          # filled with default value)

   my $current_level = 1;

   print "$0: Reading timeline file $file...\n";

   open my $fh, $file
      or die "$0: *** can't open $file ***\n";

   while (<$fh>) {

      chomp;

      # comment or white line

      if (m/^ \s*+ (?: \# .*+ )? $/x) {

         # nothing

      # .events file (file name : default color [ : file title ])

      } elsif (m/^ \s*+ ( [^\s:]++ ) \s*+
            : \s*+ ( [a-zA-Z]++ ) \s*+
            (?: : \s*+ ( .+? ) \s*+ )? $/x) {

         push @$r_titles, { title=>$3, level=>$current_level++ }
            if defined $3;

         $current_level = read_events_file($1, $2, $r_events,
                                                      $current_level);

      # config options (option = value)

      } elsif (m/^ \s*+ (\w++) \s*+ = \s*+ (.+?) \s*+ $/x) {

         die "$0: *** unknown timeline option: $1 ***\n"
            unless exists $r_options->{$1};

         $r_options->{$1} = $2;

      # error

      } else {

         die "$0: *** invalid line: '$_' ***\n";

      }

   }

   close $fh or die "$0: *** can't close $file ***\n";

   return $current_level;
   
}


########################################################################
# Compute the date, positive or negative. If the year is not defined,
# return undef (end year not given).
########################################################################

sub compute_date {

   my $year = shift;   # if not defined, means end year missing
   my $bcad = shift;   # the string actually specified (or not)
   my $all_bc = shift; # the option all_dates_bc (-1 or 1)

   return undef unless defined $year;

   return $year * (defined $bcad ? ($bcad eq "BC" ? -1 : 1) : $all_bc);

}



########################################################################
# Read the given events file.
########################################################################

sub read_events_file {

   my $file = shift;
   my $default_color = shift;
   my $r_events = shift;
   my $current_level = shift;

   my $highest_level = $current_level;

   my $all_dates_bc = 1;

   print "$0: Reading events file: $file...\n";

   open my $fh, $file or die "$0: *** can't open $file ***\n";

   while (<$fh>) {

      chomp;

      # comment or white line

      if (m/^ \s*+ (?: \# .*+ )? $/x) {

         # nothing

      # options

      } elsif (m/^ \s*+ all_dates_bc \s*+ = \s*+ (1|0) \s*+ $/x) {

         $all_dates_bc = $1 ? -1 : 1;

      # subfile

      } elsif (m/^ \s*+ subfile \s*+ = (\S) \s*+ $/x) {

         my $sub_level = read_events_file($1, $default_color,
                                          $r_events, $current_level);
         $highest_level = $sub_level if $sub_level > $highest_level;

      # an event

      } elsif (m/^ \s*+ (c)? \s*+ (\d++) \s*+ (BC|AD)? \s*+
            (?: - \s*+ (c)? \s*+ (\d++) \s*+ (BC|AD)? \s*+ )?
            ; \s*+ (\d++) \s*+
            (?: ; \s*+ ([a-zA-Z]++) \s*+ )?
            : \s*+ (.+?) \s*+ $/x) {

         my %h = (
            start_year        => compute_date($2, $3, $all_dates_bc),
            end_year          => compute_date($5, $6, $all_dates_bc),
            date_string       => sprintf("%s%d%s", $1 || '', $2,
               defined $5 ? sprintf("-%s%d", $4 || '', $5) : ''),
            level             => $current_level + $7 - 1,
            color             => defined $8 ? $8 : $default_color,
            description       => $9,
         );

         push @$r_events, { %h };

         $highest_level = $h{level} if $h{level} > $highest_level;

      } else {

         die "$0: *** invalid line: '$_' ***\n";

      }

   }

   close $fh or die "$0: *** can't close $file ***\n";

   return $highest_level + 1;

}


########################################################################
# main.
########################################################################

sub main {

   get_options();

   # list of events: each element of the array is as follows:
   #    { start_year         => < a floating point >,
   #      end_year           => < a floating point or undef >,
   #      level              => < the vertical level of the event >,
   #      color              => < the color of the event >,
   #      description        => < the text to be printed in the caption >,
   #    }
   my @events = ();

   # list of title: each element of the array is as follows:
   #   { level => < the level to be used >,
   #     title => < the text of the title >,
   #   }
   my @titles = ();

   my $levels = read_tl_file($TL_FILE, \@events, \@titles, \%SVGTL::CFG);

   die "$0: *** no data ***\n" unless @events;

   #print Dumper \@events;

   my $svg = SVGTL::build_svg(\@events, \@titles, $levels);

   print "$0: Writing $OUTPUT_FILE...\n";

   open my $fh, '>', $OUTPUT_FILE
      or die "$0: *** can't open $OUTPUT_FILE ***\n";

   print $fh $svg;

   close $fh or die "$0: *** can't close $OUTPUT_FILE ***\n";

}


main();
print "$0: done!\n";

