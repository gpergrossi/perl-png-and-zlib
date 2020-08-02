package Image;
# Image.pm

use strict;
use warnings;
use Data::Dumper;

my $LEVEL = 1; # default log level

our $CHANNEL_RED = 0;
our $CHANNEL_GREEN = 1;
our $CHANNEL_BLUE = 2;
our $CHANNEL_ALPHA = 3;

sub min {
   my ($a, $b) = @_;
   return ($a < $b) ? $a : $b;
}

# Can be called with `new Image($width, $height)`
sub new {
   my ($class, $width, $height) = @_;
   my $self = {
      _width => $width,
      _height => $height,
      _pixels => undef
   };
   
   my @pixels = (0) * $self->{_height};
   for my $y (0 .. $self->{_height}-1) {
      my @raster = (0) x $self->{_width};
      for my $x (0 .. $self->{_width}-1) {
         my @pixel = (0) x 4;
         $raster[$x] = \@pixel;
      }
      @pixels[$y] = \@raster;
   }
   $self->{_pixels} = \@pixels;
   
   bless $self, $class; # Allows "method" calls on $self
   return $self;
}

sub GetRed {
   my ($self, $x, $y) = @_;
   die "Coordinate ($x,$y) is out of bounds!" if ($x < 0 || $y < 0 || $x >= $self->{_width} || $y >= $self->{_height});
   return $self->{_pixels}->[$y]->[$x]->[$CHANNEL_RED];
}

sub GetGreen {
   my ($self, $x, $y) = @_;
   die "Coordinate ($x,$y) is out of bounds!" if ($x < 0 || $y < 0 || $x >= $self->{_width} || $y >= $self->{_height});
   return $self->{_pixels}->[$y]->[$x]->[$CHANNEL_GREEN];
}

sub GetBlue {
   my ($self, $x, $y) = @_;
   die "Coordinate ($x,$y) is out of bounds!" if ($x < 0 || $y < 0 || $x >= $self->{_width} || $y >= $self->{_height});
   return $self->{_pixels}->[$y]->[$x]->[$CHANNEL_BLUE];
}

sub GetAlpha {
   my ($self, $x, $y) = @_;
   die "Coordinate ($x,$y) is out of bounds!" if ($x < 0 || $y < 0 || $x >= $self->{_width} || $y >= $self->{_height});
   return $self->{_pixels}->[$y]->[$x]->[$CHANNEL_ALPHA];
}

sub SetColor {
   my ($self, $x, $y, $red, $green, $blue, $alpha) = @_;
   $alpha //= 255;
   
   $red = int($red);
   $green = int($green);
   $blue = int($blue);
   $alpha = int($alpha);
   
   die "Color ($red, $green, $blue, $alpha) is not valid!" if ($red < 0 || $red > 255 || $green < 0 || $green > 255 || $blue < 0 || $blue > 255 || $alpha < 0 || $alpha > 255);
   die "Coordinate ($x,$y) is out of bounds!" if ($x < 0 || $y < 0 || $x >= $self->{_width} || $y >= $self->{_height});
   
   $self->{_pixels}->[$y]->[$x]->[$CHANNEL_RED] = $red;
   $self->{_pixels}->[$y]->[$x]->[$CHANNEL_GREEN] = $green;
   $self->{_pixels}->[$y]->[$x]->[$CHANNEL_BLUE] = $blue;
   $self->{_pixels}->[$y]->[$x]->[$CHANNEL_ALPHA] = $alpha;
}

sub GetRaster {
   my ($self, $y) = @_;
   die "Coordinate (0,$y) is out of bounds!" if ($y < 0 || $y >= $self->{_height});
   my @raster = (0) x ($self->{_width} * 4);
   for my $x (0 .. $self->{_width}-1) {
      for my $chan (0 .. 3) {
         $raster[$x*4 + $chan] = $self->{_pixels}->[$y]->[$x]->[$chan];
      }
   }
   return \@raster;
}

sub GetRasters {
   my ($self) = @_;
   my @rasters = () x $self->{_height};
   for my $y (0 .. $self->{_height}-1) {
      $rasters[$y] = $self->GetRaster($y);
   }
   return \@rasters;
}

sub GetWidth {
   my ($self) = @_;
   return $self->{_width};
}

sub GetHeight {
   my ($self) = @_;
   return $self->{_height};
}

sub Print {
   my ($self) = @_;
   my $chars = " .,-~_`':;^*+\"!/\\|(){}[]<>=?&%\$\#\@0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
   
   my $colors = {
      '.' => [0, 0, 0],       # [.] Black
      'r' => [128, 0, 0],     # [r] Dark Red
      'R' => [255, 0, 0],     # [R] Red
      'g' => [0, 128, 0],     # [g] Dark Green
      'y' => [128, 128, 0],   # [y] Dark Yellow
      'O' => [255, 128, 0],   # [O] Orange
      'G' => [0, 255, 0],     # [G] Green
      'L' => [128, 255, 0],   # [L] Lime
      'Y' => [255, 255, 0],   # [Y] Yellow
      'b' => [0, 0, 128],     # [b] Dark Blue
      'm' => [128, 0, 128],   # [m] Dark Magenta
      'u' => [255, 0, 128],   # [u] Dark Rouge
      'c' => [0, 128, 128],   # [c] Dark Cyan
      '+' => [128, 128, 128], # [+] Gray
      'D' => [255, 128, 128], # [D] Light Red
      'M' => [0, 255, 128],   # [M] Mint
      'E' => [128, 255, 128], # [E] Light Green
      'W' => [255, 255, 128], # [W] Light Yellow
      'B' => [0, 0, 255],     # [B] Blue
      'U' => [128, 0, 255],   # [U] Purple
      'M' => [255, 0, 255],   # [M] Magenta
      'S' => [0, 128, 255],   # [S] Sky blue
      'l' => [128, 128, 255], # [l] Light blue
      'P' => [255, 128, 255], # [P] Pink
      'C' => [0, 255, 255],   # [C] Cyan
      'N' => [128, 255, 255], # [N] Light Cyan
      '#' => [255, 255, 255]  # [#] White
   };
   
   for my $y (0 .. $self->{_height}-1) {
      for my $x (0 .. $self->{_width}-1) {     
         my $r = $self->GetRed($x, $y);
         my $g = $self->GetGreen($x, $y);
         my $b = $self->GetBlue($x, $y);
         my $a = $self->GetAlpha($x, $y);
         
         my $char = undef;
         if ($a < 128) {
            $char = " ";
         } else {
            my $best = undef;
            my $best_dist = undef;
            for my $c (keys $colors->%*) {
               my $color = $colors->{$c};
               my $dr = $r - $color->[0];
               my $dg = $g - $color->[1];
               my $db = $b - $color->[2];
               my $dist = $dr*$dr + $dg*$dg + $db*$db;
               if (!defined($best) || $dist < $best_dist) {
                  $best_dist = $dist;
                  $best = $c;
               }
            }
            $char = $best;
         }
         print "$char ";
      }
      print "\n";
   }
};

sub Test {
   my $image = new Image(16, 16);
   
   foreach my $x (0 .. 15) {
      foreach my $y (0 .. 15) {
         $image->SetColor($x, $y, $x*15, $y*15, min($x,$y)*min($x,$y), 255);
         
         my $r = $image->GetRed($x, $y);
         my $g = $image->GetGreen($x, $y);
         my $b = $image->GetBlue($x, $y);
         my $a = $image->GetAlpha($x, $y);
         die "Mismatch ($x, $y) red " . ($x*15) . " != $r!" if ($x*15 != $r);
         die "Mismatch ($x, $y) green " . ($y*15) . " != $g!" if ($y*15 != $g);
         die "Mismatch ($x, $y) blue " . (min($x,$y)*min($x,$y)) . " != $b!" if (min($x,$y)*min($x,$y) != $b);
         die "Mismatch ($x, $y) alpha 255 != $a!" if (255 != $a);
      }
   }
   
   foreach my $x (0 .. 9) {
      foreach my $y (0 .. 9) {
         my $r = $image->GetRed($x, $y);
         my $g = $image->GetGreen($x, $y);
         my $b = $image->GetBlue($x, $y);
         my $a = $image->GetAlpha($x, $y);
         die "Mismatch ($x, $y) red " . ($x*15) . " != $r!" if ($x*15 != $r);
         die "Mismatch ($x, $y) green " . ($y*15) . " != $g!" if ($y*15 != $g);
         die "Mismatch ($x, $y) blue " . (min($x,$y)*min($x,$y)) . " != $b!" if (min($x,$y)*min($x,$y) != $b);
         die "Mismatch ($x, $y) alpha 255 != $a!" if (255 != $a);
      }
   }
   
   $image->Print();
}

# Return 1, indicating this perl module was successfully loaded.
1;