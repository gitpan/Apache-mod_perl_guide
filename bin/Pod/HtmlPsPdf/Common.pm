package Pod::HtmlPsPdf::Common;

use strict;
use Symbol ();

### Common functions

# write_file($filename,$ref_to_array);
# content will be written to the file from the passed array of
# paragraphs
###############
sub write_file{
  my ($fn,$ra_content) = @_;

  my $fh = Symbol::gensym;
  open $fh, ">$fn" or die "Can't open $fn for writing: $!\n";
  print $fh @$ra_content;
  close $fh;

} # end of sub write_file

# read_file_paras($filename,$ref_to_array);
# content will be returned in the passed array of paragraphs
###############
sub read_file{
  my ($fn,$ra_content) = @_;

  my $fh = Symbol::gensym;
  open $fh, $fn  or die "Can't open $fn for reading: $!\n";
  local $/ = "";
  @$ra_content = <$fh>;
  close $fh;

} # end of sub read_file


1;
__END__
