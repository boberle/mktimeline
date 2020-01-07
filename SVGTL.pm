package SVGTL;
use strict;
use warnings;

########################################################################
# CONFIGURATION

our %CFG = (

   # user options:
   # -------------
   # first and last year
   first_year => -2000,
   last_year => 2000,
   # show each year line out of...
   year_ratio => 1,
   # show each year caption out of...
   year_caption_ratio => 1,
   # print dates (btw parentheses after the caption)
   print_dates => 0,

   margin => 10, # svg unit

   # horizontal dimensions:
   # ----------------------
   # the interval btw two year lines
   year_interval => 50, # svg unit

   # vertical dimensions:
   # --------------------
   # the space before the first-level invisible line
   level_offset => 50, # svg unit
   # the interval btw two level lines
   level_interval => 50, # svg unit

   # text:
   # -----
   # space btw year line and year text
   year_text_offset => 2, # svg unit
   # 'links' are little corners event symbols and event texts
   link_height => 10, # svg unit
   link_width => 10, # svg unit
   # space btw event link and event text
   event_text_x_offset => 5, # svg unit
   event_text_y_offset => 3, # svg unit

   # event symbols:
   # --------------
   # the height (the width is event-dependant) of the rectangle
   event_height => 10, # svg unit
   # the radius for rounded angle and rectangle offset
   event_radius => 5, # svg unit

   # style:
   # ------
   font_family        => 'Verdana',
   grid_stroke_color  => 'LightGray',
   grid_stroke_width  => '1px',
   grid_text_color    => 'Gray',
   grid_font_size     => '10pt',
   event_stroke_color => 'black',
   event_stroke_width => '3px',
   event_text_color   => 'Black',
   event_font_size    => '10pt',
   link_stroke_color  => 'black',
   link_stroke_width  => '3px',
   title_font_family  => 'Verdana',
   title_text_color   => 'Black',
   title_font_size    => '10pt',
   title_stroke_color => 'none',
   title_stroke_width => '0px',
   title_bg_color     => 'LightGray',
   #TODO TITLE
);

########################################################################


########################################################################
# Get the pre/postambles.
########################################################################

sub get_preamble {

   my $time = scalar(gmtime);

   my $res = <<"END";
<!--
     Document automatically generated
     by mktimeline - text to svg timeline convertor
     version $main::VERSION
     on $time.

     DO NOT MODIFY THIS FILE!
-->

<svg xmlns="http://www.w3.org/2000/svg" version="1.1">

<style type="text/css" >
   <![CDATA[
   /* --- text --- */
   text {
      font-family:      $CFG{font_family};
   }
   /* --- grid --- */
   line.grid {
      stroke:           $CFG{grid_stroke_color};
      stroke-width:     $CFG{grid_stroke_width};
   }
   text.grid {
      fill:             $CFG{grid_text_color};
      font-size:        $CFG{grid_font_size};
   }
   /* --- event --- */
   circle.event {
      stroke:           $CFG{event_stroke_color};
      stroke-width:     $CFG{event_stroke_width};
   }
   rect.event {
      stroke:           $CFG{event_stroke_color};
      stroke-width:     $CFG{event_stroke_width};
   }
   text.event {
      fill:             $CFG{event_text_color};
      font-size:        $CFG{event_font_size};
   }
   /* --- link --- */
   polyline.link {
      stroke:           $CFG{link_stroke_color};
      stroke-width:     $CFG{link_stroke_width};
      fill:             none;
   }
   /* --- title --- */
   rect.title {
      stroke:           $CFG{title_stroke_color};
      stroke-width:     $CFG{title_stroke_width};
      fill:             $CFG{title_bg_color};
   }
   text.title {
      font-family:      $CFG{title_font_family};
      fill:             $CFG{title_text_color};
      font-size:        $CFG{title_font_size};
   }
   ]]>
</style>

<!-- this rectangle is used as background color for the whole doc -->
<rect width="100%" height="100%" style="fill: white"/>

END

   return $res;

}

sub get_postamble {

   my $res = <<"END";

</svg>
END

   return $res;

}



########################################################################
# Given the first year, last year and nb of levels, return the svg
# elements that draw the grid (year lines + year labels).
########################################################################

sub build_grid {

   my $first_year = shift;
   my $last_year = shift;
   my $nb_of_levels = shift;

   print "$0: Building grid ($first_year -> $last_year, "
      ."$nb_of_levels levels)...\n";

   # make the background rect

   my $tl_height = $CFG{level_offset}
         + $nb_of_levels * $CFG{level_interval};
   my $total_width = ($last_year-$first_year+1) * $CFG{year_interval};

   my $res = sprintf '<rect x="0" y="0" height="%d" width="%d" '
      .'style="fill: white;"/>'."\n",
      $tl_height + $CFG{margin}*2,
      $total_width + $CFG{margin}*2;

   my $i = -1;
   for ($first_year..$last_year) {

      $i++;
      next unless ($i % $CFG{year_ratio} == 0);

      $res .= sprintf
         '<line class="grid" x1="%d" y1="%d" x2="%d" y2="%d"/>'."\n",
         $CFG{margin}+$i*$CFG{year_interval},
         $CFG{margin},
         $CFG{margin}+$i*$CFG{year_interval},
         $CFG{margin}+$tl_height;

      next unless ($i % $CFG{year_caption_ratio} == 0);

      $res .= sprintf
         '<text class="grid" x="%d" y="%d">%d</text>'."\n",
         $CFG{margin}+$i*$CFG{year_interval}+$CFG{year_text_offset},
         $CFG{margin}+$tl_height,
         abs($_);

   }

   return $res;

}


########################################################################
# Make and return the whole text of the svg file.
########################################################################

sub build_svg {

   my $r_events = shift; # the events array
   my $r_titles = shift; # the titles array
   my $nb_of_levels = shift;

   my $svg = '';

   # make the svg grid

   $svg .= build_grid($CFG{first_year}, $CFG{last_year}, $nb_of_levels);

   for my $e (@$r_events) {

      # get the coordinates (note that y is the top edge of the rect,
      # so, later, for a circle, you will need to add half or so the
      # radius of the circle)

      my $x_start = $CFG{margin}
            +($e->{start_year}-$CFG{first_year})*$CFG{year_interval};
      my $x_end = defined $e->{end_year} ? $CFG{margin}
            +($e->{end_year}-$CFG{first_year})*$CFG{year_interval} :
            $x_start;
      my $y = $CFG{margin}
            +$CFG{level_offset}+($e->{level}-1)*$CFG{level_interval};

      my $text = sprintf('%s%s', $e->{description},
         $CFG{print_dates} ? sprintf(' (%s)', $e->{date_string}) : '');

      $svg .= sprintf '<rect class="event" x="%d" y="%d" rx="%d" ry="%d" '
         .'width="%d" height="%d" style="fill: %s;"/>'."\n",
         $x_start - $CFG{event_radius},                # x
         $y,                                           # y
         $CFG{event_radius},                           # cx
         $CFG{event_radius},                           # cy
         $x_end - $x_start + $CFG{event_radius} * 2,   # width
         $CFG{event_radius} * 2,                       # height
         $e->{color};                                  # color

      $svg .= sprintf
         '<polyline class="link" points="%d,%d %d,%d %d,%d"/>'."\n",
         $x_start, $y,                                        # 1st pt
         $x_start, $y - $CFG{link_height},                    # 2nd pt
         $x_start + $CFG{link_width}, $y - $CFG{link_height}; # 3rd pt

      $svg .= sprintf
         '<text class="event" x="%d" y="%d">%s</text>'."\n",
         $x_start + $CFG{link_width} + $CFG{event_text_x_offset}, # x
         $y - $CFG{link_height} + $CFG{event_text_y_offset},      # y
         $text;                                                   # text

   } # end for

   # add pre/postamble

   $svg = get_preamble().$svg.get_postamble();

   return $svg;

}

1;
