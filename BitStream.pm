package BitStream;
# BitStream.pm

use strict;
use warnings;

my $LEVEL = 1; # default log level

our $BIG_ENDIAN = 0;
our $LITTLE_ENDIAN = 1;

sub min {
   my ($a, $b) = @_;
   return ($a < $b) ? $a : $b;
}

# Can be called with `new BitStream()`
sub new {
   my ($class, $mode) = @_;
   $mode //= $BIG_ENDIAN; # Set if undefined
   my $self = {
      _bytes => [],
      _mode => $mode,
      _next_bit => 0,
      _partial_byte => 0
   };
   
   bless $self, $class; # Allows "method" calls on $self
   return $self;
}

# Returns a copy of this stream's bytes
sub GetBytes {
   my ($self) = @_;
   my @bytes = ();
   push @bytes, $self->{_bytes}->@*;
   if ($self->{_next_bit} > 0) {
      push @bytes, $self->{_partial_byte};
   }
   return \@bytes;
}

my @LOWER_BYTE_MASKS = (0x00, 0x01, 0x03, 0x07, 0x0F, 0x1F, 0x3F, 0x7F, 0xFF);
my @UPPER_BYTE_MASKS = (0x00, 0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE, 0xFF);
my @REVERSE_BITS = (0b0000, 0b1000, 0b0100, 0b1100, 0b0010, 0b1010, 0b0110, 0b1110, 0b0001, 0b1001, 0b0101, 0b1101, 0b0011, 0b1011, 0b0111, 0b1111);

sub ReverseNibble {
   my ($nibble) = @_;
   return $REVERSE_BITS[$nibble & 0x0F];
}

sub ReverseByte {
   my ($byte) = @_;
   return (ReverseNibble($byte) << 4) | ReverseNibble($byte >> 4);
}

sub ReverseShort {
   my ($byte) = @_;
   return (ReverseByte($byte) << 8) | ReverseByte($byte >> 8);
}

sub ReverseInt {
   my ($byte) = @_;
   return (ReverseShort($byte) << 16) | ReverseShort($byte >> 16);
}

sub ReverseBits {
   my ($value, $bit_count) = @_;
   
   if ($bit_count < 8) {
      return ReverseByte($value & 0xFF) >> (8 - $bit_count);
   } elsif ($bit_count < 16) {
      return ReverseShort($value & 0xFFFF) >> (16 - $bit_count);
   } elsif ($bit_count < 32) {
      return ReverseInt($value & 0xFFFFFFFF) >> (32 - $bit_count);
   } else { 
      die "Cannot reverse that many bits!";
   }
}

sub FinishByte {
   my ($self) = @_;
   if ($self->{_next_bit} == 0) {
      return 0;
   } else {
      push $self->{_bytes}->@*, $self->{_partial_byte};
      $self->{_partial_byte} = 0;
      $self->{_next_bit} = 0;
      return 1;
   }
}

sub WriteBits {
   my ($self, $value, $bit_count, $reversed) = @_;
   $reversed //= 0;

   # Reverse?
   if ($reversed) {
      $value = ReverseBits($value, $bit_count);
   }
   
   # Easy cases
   if ($self->{_next_bit} == 0) {
      if ($bit_count == 8) {
         push $self->{_bytes}->@*, $value & 0xFF;
         return;
      } elsif ($bit_count < 8) {
         $self->{_partial_byte} = $value;
         $self->{_next_bit} = $bit_count;
         return;
      }
   }

   # How many bits can fit into the current word?
   my $bits_writable = (8 - $self->{_next_bit});
   
   if ($bit_count < $bits_writable) {
      # Make sure to only include the bits below $bit_count
      my $lower = $value & $LOWER_BYTE_MASKS[$bit_count];
      
      # And into the _partial_byte and advance the _next_bit counter
      $self->{_partial_byte} |= $lower << $self->{_next_bit};
      $self->{_next_bit} += $bit_count;
   } else {
      # Get bits that will fit
      my $lower = $value & $LOWER_BYTE_MASKS[$bits_writable];
      
      # And into the _partial_byte
      $self->{_partial_byte} |= $lower << $self->{_next_bit};
      $self->{_next_bit} += $bits_writable;
      
      # Push the current byte and get a new one
      $self->FinishByte();
      
      # Handle remaining bits with recursive call
      my $remaining_bits = $bit_count - $bits_writable;
      if ($remaining_bits > 0) {
         $self->WriteBits($value >> $bits_writable, $remaining_bits)
      }
   }
};

sub WriteByte {
   my ($self, $byte) = @_;
   $self->WriteBits($byte, 8);
};

sub WriteShort {
   my ($self, $short, $mode) = @_;
   $short = int($short);
   $mode //= $self->{_mode};
   
   if ($mode == $BIG_ENDIAN) {
      $self->WriteByte($short >> 8);
      $self->WriteByte($short);
   } elsif ($mode == $LITTLE_ENDIAN) {
      $self->WriteByte($short);
      $self->WriteByte($short >> 8);
   } else { die; }
};

sub WriteInt {
   my ($self, $int, $mode) = @_;
   $int = int($int);
   $mode //= $self->{_mode};
   
   if ($mode == $BIG_ENDIAN) {
      $self->WriteByte($int >> 24);
      $self->WriteByte($int >> 16);
      $self->WriteByte($int >> 8);
      $self->WriteByte($int);
   } elsif ($mode == $LITTLE_ENDIAN) {
      $self->WriteByte($int);
      $self->WriteByte($int >> 8);
      $self->WriteByte($int >> 16);
      $self->WriteByte($int >> 24);
   } else { die; }
};

sub WriteByteArray {
   my ($self, $arr) = @_;
   for my $elem ($arr->@*) {
      $self->WriteByte($elem);
   }
};

sub WriteAsciiString {
   my ($self, $str) = @_;
   for (my $i = 0; $i < length($str); $i++) {
      $self->WriteByte(ord(substr($str, $i, 1)));
   }
};

# Return 1, indicating this perl module was successfully loaded.
1;