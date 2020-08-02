# Pure Perl PNG Encoder (and Minimal Zlib Implementation)

I wrote a PNG encoder over the weekend just to learn how it all works. Turns out learning PNG also requires a tiny bit of Zlib, but I did that too (sort of).

I went with the bare minimum here. The PNG doesn't use filtering, always assumes full 8 bit RGBA, and ignore palletes and interlacing. 
Basically I didn't care about file size as long as it made a valid PNG. On that note, the Zlib implementation doesn't do any compression. 
It just packs the data into a Zlib compatible uncompressed format.


# Usage: 

Run `perl Main.pl` to produce a nice image with the worst compression possible.

Run `perl Test.pl` to compare my implementation's output with output from real libraries.


# Todo:

I need to make Bitstream and Bytestream into the same class.

I also need to finish implementing compression. 

See: all the TODO comments.
