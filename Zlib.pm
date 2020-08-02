package Zlib;
# Zlib.pm

use strict;
use warnings;

use File::Basename;
use BitStream;

my $LEVEL = 1; # default log level

sub min {
   my ($a, $b) = @_;
   return ($a < $b) ? $a : $b;
};

sub max {
   my ($a, $b) = @_;
   return ($a > $b) ? $a : $b;
};

# A naive algorithm to back references in compressible data
sub _Lz77FindBackRefs {
   my ($input, $sliding_window_size, $backref_callback, $backref_callback_args) = @_;
   
   my $input_length = scalar($input->@*);
   return if $input_length == 0;
   
   for (my $i = 0; $i < $input_length;) {
      my $best_index = 0;
      my $best_length = 0;
      
      my $window_start = max(0, $i - $sliding_window_size);
      my $window_end = $i-1;
      
      # Find best back reference
      for (my $j = $window_start; $j <= $window_end; $j++) {
         my $k = 0;
         while (($k < $sliding_window_size) && (($i + $k) < $input_length)) {
            if ($input->[$j + $k] == $input->[$i + $k]) {
               $k++;
            } else {
               last;
            }
         }
         
         if ($k > $best_length) {
            $best_length = $k;
            $best_index = $j;
         }
      }
      
      my $distance = $i - $best_index;
      my $length = $best_length;
      
      # Last symbol cannot be part of a back reference, each backref needs to have a 'next' value (I.E. dist, len, next)
      my $next_index = $i + $length;
      if ($next_index >= $input_length) {
         $next_index--;
         $length--;
         die "Error!" if ($length < 0);
      }
      
      # Get next character in input (there should always be one)
      my $next = $input->[$next_index];
      
      # Get context of this back ref (i.e. the entire string the backref call represents)
      my @context = ();
      foreach my $i (0 .. $length-1) {
         push @context, $input->[$best_index + $i];
      }
      push @context, $next;
      
      # Try the backref callback
      my $accepted = $backref_callback->($distance, $length, $next, $backref_callback_args, \@context);
      
      # Callback can deny this back ref. If it does, send a non-back-referenced value
      if (!$accepted) {
         $distance = 0;
         $length = 0;
         $next = $input->[$i];
         
         # Send only the current value:
         $accepted = $backref_callback->($distance, $length, $next, $backref_callback_args, [$next]);
         die "Callback refused fallback" unless $accepted;
      }
      
      $i += $length + 1;
   }
}

our $DEFLATE_COMPRESSED_LENGTHS = {
   257 => { extra_bits => 0, length_min =>   3, length_max =>   3 },
   258 => { extra_bits => 0, length_min =>   4, length_max =>   4 },
   259 => { extra_bits => 0, length_min =>   5, length_max =>   5 },
   260 => { extra_bits => 0, length_min =>   6, length_max =>   6 },
   261 => { extra_bits => 0, length_min =>   7, length_max =>   7 },
   262 => { extra_bits => 0, length_min =>   8, length_max =>   8 },
   263 => { extra_bits => 0, length_min =>   9, length_max =>   9 },
   264 => { extra_bits => 0, length_min =>  10, length_max =>  10 },
   265 => { extra_bits => 1, length_min =>  11, length_max =>  12 },
   266 => { extra_bits => 1, length_min =>  13, length_max =>  14 },
   267 => { extra_bits => 1, length_min =>  15, length_max =>  16 },
   268 => { extra_bits => 1, length_min =>  17, length_max =>  18 },
   269 => { extra_bits => 2, length_min =>  19, length_max =>  22 },
   270 => { extra_bits => 2, length_min =>  23, length_max =>  26 },
   271 => { extra_bits => 2, length_min =>  27, length_max =>  30 },
   272 => { extra_bits => 2, length_min =>  31, length_max =>  34 },
   273 => { extra_bits => 3, length_min =>  35, length_max =>  42 },
   274 => { extra_bits => 3, length_min =>  43, length_max =>  50 },
   275 => { extra_bits => 3, length_min =>  51, length_max =>  58 },
   276 => { extra_bits => 3, length_min =>  59, length_max =>  66 },
   277 => { extra_bits => 4, length_min =>  67, length_max =>  82 },
   278 => { extra_bits => 4, length_min =>  83, length_max =>  98 },
   279 => { extra_bits => 4, length_min =>  99, length_max => 114 },
   280 => { extra_bits => 4, length_min => 115, length_max => 130 },
   281 => { extra_bits => 5, length_min => 131, length_max => 162 },
   282 => { extra_bits => 5, length_min => 163, length_max => 194 },
   283 => { extra_bits => 5, length_min => 195, length_max => 226 },
   284 => { extra_bits => 5, length_min => 227, length_max => 257 },
   285 => { extra_bits => 0, length_min => 258, length_max => 258 }
};

our $DEFLATE_COMPRESSED_DISTANCES = {
    0 => { extra_bits =>  0, distance_min =>     1, distance_max =>     1 },
    1 => { extra_bits =>  0, distance_min =>     2, distance_max =>     2 },
    2 => { extra_bits =>  0, distance_min =>     3, distance_max =>     3 },
    3 => { extra_bits =>  0, distance_min =>     4, distance_max =>     4 },
    4 => { extra_bits =>  1, distance_min =>     5, distance_max =>     6 },
    5 => { extra_bits =>  1, distance_min =>     7, distance_max =>     8 },
    6 => { extra_bits =>  2, distance_min =>     9, distance_max =>    12 },
    7 => { extra_bits =>  2, distance_min =>    13, distance_max =>    16 },
    8 => { extra_bits =>  3, distance_min =>    17, distance_max =>    24 },
    9 => { extra_bits =>  3, distance_min =>    25, distance_max =>    32 },
   10 => { extra_bits =>  4, distance_min =>    33, distance_max =>    48 },
   11 => { extra_bits =>  4, distance_min =>    49, distance_max =>    64 },
   12 => { extra_bits =>  5, distance_min =>    65, distance_max =>    96 },
   13 => { extra_bits =>  5, distance_min =>    97, distance_max =>   128 },
   14 => { extra_bits =>  6, distance_min =>   129, distance_max =>   192 },
   15 => { extra_bits =>  6, distance_min =>   193, distance_max =>   256 },
   16 => { extra_bits =>  7, distance_min =>   257, distance_max =>   384 },
   17 => { extra_bits =>  7, distance_min =>   385, distance_max =>   512 },
   18 => { extra_bits =>  8, distance_min =>   513, distance_max =>   768 },
   19 => { extra_bits =>  8, distance_min =>   769, distance_max =>  1024 },
   20 => { extra_bits =>  9, distance_min =>  1025, distance_max =>  1536 },
   21 => { extra_bits =>  9, distance_min =>  1537, distance_max =>  2048 },
   22 => { extra_bits => 10, distance_min =>  2049, distance_max =>  3072 },
   23 => { extra_bits => 10, distance_min =>  3073, distance_max =>  4096 },
   24 => { extra_bits => 11, distance_min =>  4097, distance_max =>  6144 },
   25 => { extra_bits => 11, distance_min =>  6145, distance_max =>  8192 },
   26 => { extra_bits => 12, distance_min =>  8193, distance_max => 12288 },
   27 => { extra_bits => 12, distance_min => 12289, distance_max => 16384 },
   28 => { extra_bits => 13, distance_min => 16385, distance_max => 24576 },
   29 => { extra_bits => 13, distance_min => 24577, distance_max => 32768 }
};

sub _Deflate_BackRef_Callback {
   # $dist - the distance backward to the current back reference
   # $len - the length of the back reference
   # $next - the next value in the input (always present)
   # $args - a pass-through value from the original lz77_back_refs call
   # $context - the array of values represented by this back ref
   my ($dist, $len, $next, $args, $context) = @_;
   my ($symbols) = $args->@*;
   
   return 0 if ($len < 3);
   
}

sub Adler32Checksum {
   my ($input_byte_array) = @_;
   my $s1 = 1;
   my $s2 = 0;
   foreach my $byte ($input_byte_array->@*) {
      $byte = $byte & 0xFF;
      $s1 = ($s1 + $byte) % 65521;
      $s2 = ($s2 + $s1) % 65521;
   }
   return (($s2 << 16) | $s1);
}

# TODO Compression
sub Compress {
   my ($input_byte_array, $options) = @_;
   
   # Default options
   $options //= {
      level => 0
   };
   
   my $bitstream = new BitStream($BitStream::LITTLE_ENDIAN);
   
   # Zlib header (See RFC 1950 https://www.ietf.org/rfc/rfc1950.txt)
   my $cm = 8;    # CM ("Compression Method") = 8 ("deflate"). Must be 8 for compatability with PNG
   my $cinfo = 7; # CINFO ("Compression Info") = 7 (32768 sliding window size). Must be 7 for compatability with PNG
   my $cmf = (($cinfo & 0x0F) << 4) | ($cm & 0x0F); # CMF is the first byte of the Zlib  header and contains CM and CINFO.
   
   # Compute Zlib header FLG (Flags)
   my $compression_level = int($options->{level}); # Can be anything from 0 to 3
   my $fdict = 0; # Always 0 for compatability with PNG
   
   # FLG
   my $flg = (($compression_level & 0x03) << 6) | (($fdict & 0x01) << 5);
   
   # Compute FCHECK
   foreach my $i (0 .. 31) {
      my $fcheck = $i;
      $flg = ($flg & 0xE0) | ($fcheck & 0x1F);
      
      my $cmf_and_flg = ($cmf << 8 | $flg);
      if ($cmf_and_flg % 31 == 0) {
         # Zlib specification says FCHECK needs to make ((CMF << 8) | FLG) a multiple of 31.
         last;
      }
   }
   
   #print "Writing Zlib header\n";
   $bitstream->WriteByte($cmf);
   $bitstream->WriteByte($flg);
   
   
   # How many blocks?
   my $input_length = scalar($input_byte_array->@*);
   my $num_blocks = int(($input_length + 65534) / 65535);
   
   # Write blocks...
   for (my $block_i = 0; $block_i < $num_blocks; $block_i++) {
      my $block_start = $block_i * 65535;
      my $block_end = min($block_i * 65535 + 65534, $input_length - 1);
      my $block_length = $block_end - $block_start + 1;
      
      # BFINAL
      my $is_final = ($block_i >= $num_blocks-1);
      $bitstream->WriteBits($is_final ? 0b1 : 0b0, 1);
      
      # BTYPE 00 - no compression
      $bitstream->WriteBits(0b00, 2);
      
      # Restore byte alignment
      $bitstream->FinishByte();
      
      # Length and Length 1's Complement
      $bitstream->WriteShort($block_length);
      $bitstream->WriteShort($block_length ^ 0xFFFF);
      
      # Block bytes
      #print "Writing block: Final = $is_final, Compression = 00, Length = $block_length\n";
      foreach my $i ($block_start .. $block_end) {
         #printf("0x%02x, ", $input_byte_array->[$i]);
         $bitstream->WriteByte($input_byte_array->[$i]);
      }
      #print "\n";
   }
   die "Bad byte alignment!" if ($bitstream->FinishByte());
   
   # Zlib checksum
   my $checksum = Adler32Checksum($input_byte_array);
   #printf("Writing Adler32 Checksum: 0x%08x\n", $checksum);
   $bitstream->WriteInt($checksum, $BitStream::BIG_ENDIAN);
   
   return $bitstream->GetBytes();
   
   #my $symbols = [];
   #_Lz77FindBackRefs($byte_array, 32768, _Deflate_BackRef_Callback, $symbols)
}

sub Test {
   my $array = [1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0, 
                5, 2, 5, 1, 0, 7, 9, 9,
                1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0, 
                1, 1, 1, 1, 0, 0, 0, 0];

   print "[" . join("", $array->@*) . "]\n";

   sub Print_BackRef {
      # $dist - the distance backward to the current back reference
      # $len - the length of the back reference
      # $next - the next value in the input (always present)
      # $args - a pass-through value from the original lz77_back_refs call
      # $context - the array of values represented by this back ref
      my ($dist, $len, $next, $args, $context) = @_;
      
      if ($len > 0 && $len < 3) {
         return 0; # Not OK, give me a single value instead.
      }
      
      my $str = join(",", $context->@*);
      print "$str   = (back ref: dist=$dist, len=$len) char $next\n";
      
      return 1; # OK
   };

   _Lz77FindBackRefs($array, 32768, \&Print_BackRef, []);

   #print "Compress::Zlib::adler32 : " . Compress::Zlib::adler32();
   #print "Our adler32 : " . Adler32Checksum($input);

}

# Return 1, indicating this perl module was successfully loaded.
1;