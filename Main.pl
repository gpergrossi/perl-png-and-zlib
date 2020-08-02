use strict;
use warnings;
use Data::Dumper;

use File::Basename;
use lib dirname (__FILE__);
use Image;
use Zlib;
use Png;

my $image = new Image(256, 256);
foreach my $y (0 .. 255) {
   foreach my $x (0 .. 255) {
      my $z = ($x < $y) ? $x : $y;
      
      my $r = $z*$z/255;
      my $g = 255-$y;
      my $b = $x;
      
      if ($b > 255) {
         my $div = $b / 255;
         $r /= $div;
         $g /= $div;
         $b /= $div;
      }
      $image->SetColor($x, $y, $r, $g, $b, 255); # maybe 192
   }
}
my $image_bytes = Png::CreatePng($image);

open(my $fh, '>', "test.png") or die;
binmode($fh);
foreach my $byte ($image_bytes->@*) {
   die if ($byte > 0xFF);
   print $fh chr($byte);
}
close($fh);