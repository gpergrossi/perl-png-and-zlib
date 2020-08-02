package Png;
# Png.pm

use strict;
use warnings;

use File::Basename;
use ByteStream;
use Zlib;

my $LEVEL = 1; # default log level

our $CHUNK_TYPE_IHDR = 0x49484452; # In ASCII: "IHDR"
our $CHUNK_TYPE_IDAT = 0x49444154; # In ASCII: "IDAT"
our $CHUNK_TYPE_IEND = 0x49454E44; # In ASCII: "IEND"

my $CRC_Table = [];

sub _MakeCrcTable {
   for my $n (0 .. 255) {
      my $c = $n;
      for my $k (0 .. 7) {
         if ($c & 1) {
            $c = 0xEDB88320 ^ ($c >> 1);
         } else {
            $c = $c >> 1;
         }
      }
      $CRC_Table->[$n] = $c;
   }
};

sub UpdateCrc {
   my ($crc, $array) = @_;
   _MakeCrcTable() if scalar($CRC_Table->@*) == 0;
   
   my $c = $crc;
   for my $n (0 .. scalar($array->@*) - 1) {
      $c = $CRC_Table->[($c ^ $array->[$n]) & 0xFF] ^ ($c >> 8);
   }
   return $c & 0xFFFFFFFF;
};

sub CreateCrc {
   my ($array) = @_;
   return UpdateCrc(0xFFFFFFFF, $array) ^ 0xFFFFFFFF;
};



sub _WritePngHeader {
   my ($bytestream) = @_;
   my $pos = $bytestream->GetPosition();
   
   #print "Writing PNG Header\n";
   $bytestream->WriteByte(0x89);
   $bytestream->WriteAsciiString("PNG");
   $bytestream->WriteAsciiString("\r\n");
   $bytestream->WriteByte(0x1A);
   $bytestream->WriteAsciiString("\n");
   
   my $len = $bytestream->GetPosition() - $pos;
   die "Error! Incorrect length." if $len != 8;
};

sub _WritePngChunk {
   my ($bytestream, $chunk_type, $body) = @_;
   
   my $body_length = scalar($body->@*);
   die "Body too large!" if $body_length > 0xFFFFFFFF;
   $bytestream->WriteInt($body_length);
   
   my $crc_data = new ByteStream();
   $crc_data->WriteInt($chunk_type);
   $crc_data->WriteByteArray($body);
   my $crc = CreateCrc($crc_data->GetBytes());
   
   $bytestream->WriteInt($chunk_type);
   $bytestream->WriteByteArray($body);
   $bytestream->WriteInt($crc);
   
   #printf("PNG Chunk: Type = 0x%08x, Length = %d, CRC = 0x%08x\n", $chunk_type, scalar($body->@*), $crc);
};

sub _WritePngIhdr {
   my ($bytestream, $width, $height) = @_;
   
   my $body = new ByteStream();
   $body->WriteInt($width);  # width
   $body->WriteInt($height); # height
   $body->WriteByte(8);      # bit depth
   $body->WriteByte(6);      # color type (6 = RGBA)
   $body->WriteByte(0);      # compression method (0 = deflate w/ sliding window <= 32768 bytes)
   $body->WriteByte(0);      # filter method (0 = 5 predefined filter types from PNG standard)
   $body->WriteByte(0);      # interlace method (0 = none)
   
   #print "Writing PNG IHDR Chunk: Width = $width, Height = $height\n";
   _WritePngChunk($bytestream, $CHUNK_TYPE_IHDR, $body->GetBytes());
};

sub _WritePngIdat {
   my ($bytestream, $compressed_pixel_data) = @_;   
   #print "Writing PNG IDAT Chunk...\n";
   _WritePngChunk($bytestream, $CHUNK_TYPE_IDAT, $compressed_pixel_data);
};

sub _WritePngIend {
   my ($bytestream) = @_;   
   #print "Writing PNG IEND Chunk\n";
   _WritePngChunk($bytestream, $CHUNK_TYPE_IEND, []);
};


# TODO: choose better filters
sub _FilterRaster {
   my ($raster, $prev_raster) = @_;
   my @filtered = ();
   push @filtered, 0; # filter type 0 is no filtering
   push @filtered, $raster->@*; # rest of unfiltered data
   return \@filtered;
};

# TODO rgb compaction, alpha compaction, palletes?
sub _CreatePngPixelData {
   my ($image) = @_;
   
   my $pixel_bytestream = new ByteStream();
   
   # Declare raster storage
   my $prev_raster = [(0) x ($image->GetWidth() * 4)];
   
   foreach my $raster ($image->GetRasters()->@*) {
      my $filtered = _FilterRaster($raster, $prev_raster);
      
      #print "Writing raster: Length = " . (scalar($filtered->@*)) . ", Filter = $filtered->[0]\n";
      #my @bytes = $filtered->@*;
      #shift @bytes;
      #foreach my $byte (@bytes) {
      #   printf("0x%02x, ", $byte);
      #}
      #print "\n";
      
      $pixel_bytestream->WriteByteArray($filtered);
      $prev_raster = $raster;
   }
   
   return Zlib::Compress($pixel_bytestream->GetBytes());
}

# TODO: IDAT chunking
sub CreatePng {
   # pixels is a 3D array of bytes (values 0-255) sized [height][width][4] (in that order). 
   # The last index is the 'channel', which is represented 0 => red, 1 => green, 2 => blue, 3 => alpha.
   my ($image) = @_;
   my $bytestream = new ByteStream();
   _WritePngHeader($bytestream);
   _WritePngIhdr($bytestream, $image->GetWidth(), $image->GetHeight());
   _WritePngIdat($bytestream, _CreatePngPixelData($image));
   _WritePngIend($bytestream);
   return $bytestream->GetBytes();
};

# Return 1, indicating this perl module was successfully loaded.
1;