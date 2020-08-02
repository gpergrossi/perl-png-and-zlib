package ByteStream;
# ByteStream.pm

use strict;
use warnings;

my $LEVEL = 1; # default log level

our $BIG_ENDIAN = 0;
our $LITTLE_ENDIAN = 1;

# Can be called with `new ByteStream()`
sub new {
   my ($class, $mode) = @_;
   $mode //= $BIG_ENDIAN; # Set if undefined
   my $self = {
      _bytes => [],
      _pos => 0,
      _mark => 0,
      _mode => $mode
   };
   
   bless $self, $class; # Allows "method" calls on $self
   return $self;
}

sub GetLength {
   my ($self) = @_;
   return scalar($self->{_bytes}->@*);
}

sub GetPosition {
   my ($self) = @_;
   return $self->{_pos};
}

sub GetMark {
   my ($self) = @_;
   return $self->{_mark};
}

# Sets the mark to the current position
sub Mark {
   my ($self) = @_;
   $self->{_mark} = $self->{_pos};
}

# Resets the current position to the mark
sub Reset {
   my ($self) = @_;
   $self->{_pos} = $self->{_mark};
}

# Clears all bytes and resets the position and mark
sub Clear {
   my ($self) = @_;
   $self->{_bytes} = [];
   $self->{_pos} = 0;
   $self->{_mark} = 0;
}

# Returns a copy of this stream's bytes
sub GetBytes {
   my ($self) = @_;
   my @bytes = ();
   for (my $i = 0; $i < $self->{_pos}; $i++) {
      push @bytes, $self->{_bytes}->[$i];
   }
   return \@bytes;
}

sub WriteByte {
   my ($self, $byte) = @_;
   $self->{_bytes}->[$self->{_pos}] = ($byte & 0xFF);
   $self->{_pos}++;
};

sub WriteShort {
   my ($self, $short) = @_;
   $short = int($short);
   if ($self->{_mode} == $BIG_ENDIAN) {
      $self->WriteByte($short >> 8);
      $self->WriteByte($short);
   } else {
      $self->WriteByte($short);
      $self->WriteByte($short >> 8);
   }
};

sub WriteInt {
   my ($self, $int) = @_;
   $int = int($int);
   if ($self->{_mode} == $BIG_ENDIAN) {
      $self->WriteByte($int >> 24);
      $self->WriteByte($int >> 16);
      $self->WriteByte($int >> 8);
      $self->WriteByte($int);
   } else {
      $self->WriteByte($int);
      $self->WriteByte($int >> 8);
      $self->WriteByte($int >> 16);
      $self->WriteByte($int >> 24);
   }
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