#!/usr/bin/perl -w

#
##
### explanation and documentation
### => execute 'perldoc build.pl' to get the built in docs rendered
##
#

use strict;

$|=1;

# allow to this script from any path and not only from the current directory
use FindBin qw($Bin);
use lib $Bin;
use Cwd ();
my $orig_dir = Cwd::cwd;
chdir $Bin;

		# Get the global variables from build.cfg
require "./config.pl";

use strict;

use vars qw($root $bin_root $src_root $ps_root $rel_root $out_name
	    $out_dir $last_modified $toc_file $version_file
	   );

use Guide::Pod2Html ();
use Guide::Pod2HtmlPS ();
use Getopt::Std;
use Symbol;
use File::Copy;

# process command line arguments
my %opts;
getopts('hvtpdfalm', \%opts);

# set defaults if no options given
my $verbose        = 1;  # verbose?
my $make_tgz       = 0;  # create the rel and bin+src archives?
my $generate_ps    = 0;  # generate PS file
my $generate_pdf   = 0;  # generate PDF file
my $rebuild_all    = 0;  # ignore the timestamp of ../src/.last_modified
my $print_anchors  = 0;  # print the available anchors
my $validate_links = 0;  # validate %links_to_check against %valid_anchors
my $makefile_mode  = 0;	 # executed from Makefile (forces rebuild, no
                         # PS/PDF file, no tgz archive created!)

usage() if $opts{h};

if (keys %opts) {   # options given
  $verbose        = $opts{v} || 0;
  $make_tgz       = $opts{t} || 0;
  $generate_ps    = $opts{p} || 0;
  $generate_pdf   = $opts{d} || 0;
  $rebuild_all    = $opts{f} || 0; # force
  $print_anchors  = $opts{a} || 0;
  $validate_links = $opts{l} || 0;
  $makefile_mode  = $opts{m} || 0;
}

if ($makefile_mode) {
  $verbose        = 1;
  $make_tgz       = 0;
  $generate_ps    = 0;
  $generate_pdf   = 0;
  $rebuild_all    = 1;
  $print_anchors  = 0;
  $validate_links = 0;
} else {
    # I'm not sure all users have this module installed.
    # I neither put it into prerequisites list

    # it just saves me time when I change only a few files and don't
    # want to wait for everything to get rebuilt
  require Storable;
}


# when we will finish to parse the pod files, %valid_anchors will
# include all the valid anchors
# $valid_anchors{target_page#anchor} = "title";
my %valid_anchors = ();

# when we will finish to parse the pod files, %links_to_check will
# include all the crossreference links
# $links_to_check{srcpage}[3] = "target_page#anchor";
my %links_to_check = ();

my @ordered_srcs =
  qw(intro
     start
     perl
     install
     config
     control
     strategy
     scenario
     porting
     performance
     frequent
     obvious
     troubleshooting
     correct_headers
     security
     databases
     dbm
     multiuser
     debug
     browserbugs
     modules
     snippets
     hardware
     advocacy
     help
     download
    );

# Non pod/html files or dirs to be copied unmodified
my @other_srcs = qw(CHANGES style.css images code);

# Main Table of Contents for index.html
my $rh_main_toc = {};

# there is a chance that users don't have Storable installed
$rh_main_toc = Storable::retrieve($toc_file) 
  if -e $toc_file and !$makefile_mode;

  # read the available pods 
#my @srcs = DirHandle->new($src_root)->read();

# we need a PS in order to create a pdf
$generate_ps = 1 if $generate_pdf;

mkdir $rel_root,0700 unless -e $rel_root;
mkdir $ps_root, 0700 unless -e $ps_root;

  # Process each html

for(my $i=0;$i<@ordered_srcs;$i++) {

  my $file     = "$ordered_srcs[$i].pod";
  my $src_file = "$src_root/$file";

  print("$file: Not modified\n"),next
    if !$rebuild_all and -e $last_modified and -M $src_file > -M $last_modified;

  print "Working on $file\n";

  my $prev_page = ($i and defined $ordered_srcs[$i-1]) ? "$ordered_srcs[$i-1].html" : '';
  my $next_page = (       defined $ordered_srcs[$i+1]) ? "$ordered_srcs[$i+1].html" : '';
  my $curr_page = "$ordered_srcs[$i].html";
  my $curr_page_index = $i+1;

    # file change timestamp
  my ($mon,$day,$year) = (localtime ( (stat($src_file))[9] ) )[4,3,5];
  $year += 1900;
  my $time_stamp = sprintf "%02d/%02d/%04d", ++$mon,$day,$year;

    # open the file
  open IN, $src_file or die "Can't open $src_file: $!\n";
    # read a paragraph at a time
  local $/ = "";
  my @content = <IN>;
  close IN;
  my @ps_content = ();

    # convert pod to html
  if ($file =~ /\.pod/) {

    if ($generate_ps){
      @ps_content = @content;

      my $htmlroot = '.';
      my @podpath = ('.');
      my $podroot = $src_root;
      my $verbose = 1;
      # @content enters as pod, when returns - it's html
      Guide::Pod2HtmlPS::pod2html(\@podpath,$podroot,$htmlroot,$verbose,
				  \@ps_content,$time_stamp,
				  $prev_page,$next_page,
				  $curr_page,$curr_page_index,
			       );
    }

    my $htmlroot = '.';
    my @podpath = ('.');
    my $podroot = $src_root;
    my $verbose = 1;
      # @content enters as pod, when returns - it's html
    Guide::Pod2Html::pod2html(\@podpath,$podroot,$htmlroot,$verbose,
			      \@content,$rh_main_toc,$time_stamp,
			      $prev_page,$next_page,
			      $curr_page,$curr_page_index,
			      \%valid_anchors,\%links_to_check
			     );

    # add the <a name="anchor##"> for each para
    my $anchor_count = 0;
    s|\n<P>\n|qq{\n<P><A NAME="anchor}.$anchor_count++.qq{"></A>\n}|seg for @content;

      # make it html ext if it was pod
    $file =~ s/\.pod/.html/;
  }

  open RELEASE , ">$rel_root/$file" or die "Can't open $rel_root/$file for writing:$!\n";
  print RELEASE join "\n",@content;
  close RELEASE;

  if ($generate_ps){
    open RELEASE , ">$ps_root/$file" or die "Can't open $ps_root/$file for writing:$!\n";
    print RELEASE join "\n",@ps_content;
    close RELEASE;
  }

}

# update TOC
Storable::store($rh_main_toc, $toc_file) unless $makefile_mode;

  # refresh the last_modified flag
my $updated = gensym;
open $updated, ">$last_modified"
  or die "Can't open $last_modified for writing: $! \n";
close $updated;

# Handle the rest of the files
foreach my $file (@other_srcs) {
  system "cp -r $src_root/$file $rel_root";
}

# Generate PS files
if ($generate_ps) {

  print "Generating a PostScript file\n";

  if (`which html2ps`) {
    make_indexps_file();
    my $command = "html2ps -f html2psrc -o $ps_root/mod_perl_guide.ps ";
    $command .= join " ", map {"$ps_root/$_.html"} "index", @ordered_srcs;
    print "Doing $command\n";
    system $command;

  } else {

      # reset the flag 
    $generate_ps = 0;
    $generate_pdf = 0;
    
    print qq{It seems that you do not have html2ps package installed!
	     You have to install it if you want to generate the PS
	     file, or a PDF (since we need PS to get PDF).  You can
	     install it from http://www.tdb.uu.se/~jan/html2ps.html
	   };
  }

} # end of if ($generate_ps)

# Generate PDF file
if ($generate_pdf) {

  print "Generating a PDF file\n";
  if (`which ps2pdf`) {
    my $command = "ps2pdf $ps_root/mod_perl_guide.ps $ps_root/mod_perl_guide.pdf";
    print "Doing $command\n";
    system $command;
  } else {
    $generate_pdf = 0;
    
    print qq{It seems that you do not have ps2pdf installed! You have
	     to install it  if you want to generate the PDF file
	   };
  }
  
} # end of if ($generate_pdf)

# Validate pod's L<> links
if ($validate_links) {
  print "Validating anchors\n";
  foreach my $srcpage (sort keys %links_to_check) {
    foreach (@{$links_to_check{$srcpage}}) {
      print "*** Broken $srcpage.pod: $_\n" unless exists $valid_anchors{$_};
    }
  }

}

# print the available target anchors by the pod's L<> fashion, to be
# copied and pasted directly into a pod.
if ($print_anchors) {
  print "Available anchors\n";
  foreach my $key (sort keys %valid_anchors) {
    print "L<$valid_anchors{$key}|$key>\n";
  }
}


# build a complete toc
my $main_long_toc  = join "\n", 
  map {$$rh_main_toc{"$_.html"} } @ordered_srcs;
my $main_short_toc = join "\n", 
  map {$$rh_main_toc{"$_.html"} =~ s|<UL>.*</UL>||ism;
       $$rh_main_toc{"$_.html"} =~ s|<B><FONT SIZE=\+1>([^<]+)</FONT></B></A></LI><P>|$1</A></LI>|ism;
       $$rh_main_toc{"$_.html"} =~ s^<P>^^gism;
       $$rh_main_toc{"$_.html"} } @ordered_srcs;

#				     $$rh_main_toc{"$_.html"} =~ s^<B>|</B>|<P>^^gism;
#				     $$rh_main_toc{"$_.html"} =~ s^<FONT.*?>|</FONT>^^gism;

# create index.html
make_index_file(\$main_long_toc,\$main_short_toc);

  # build the dist
make_tar_gz() if $make_tgz;

# go back to where you have from
chdir $orig_dir;

###########################################################################
###############               Subroutines           #######################
###########################################################################


# Using the same template file create the long and the short index
# html files
###################
sub make_index_file{
  my $r_main_long_toc  = shift || \undef;
  my $r_main_short_toc = shift || \undef;

  my %r_toc = (
	     long  => $r_main_long_toc,
	     short => $r_main_short_toc,
	    );

  my %file = (
	      long  => "$rel_root/index_long.html",
	      short => "$rel_root/index.html",
	     );

  my %toc_link = (
		  long  => qq{[ <A HREF="#toc">TOC</A> ] 
			      [ <A HREF="index.html">Dense TOC</A> ]},
		  short => qq{[ <A HREF="#toc">TOC</A> ] 
			      [ <A HREF="index_long.html">Full TOC</A> ]},
		 );

  use vars qw($VERSION);
  require $version_file;

  my ($mon,$day,$year) = (localtime ( time ) )[4,3,5];
  $year = 1900 + $year;
  my $time_stamp = sprintf "%02d/%02d/%04d", ++$mon,$day,$year;

  my $date = sprintf "%s, %d %d", (split /\s+/, scalar localtime)[1,2,4];

  open INDEX, "$src_root/index.tmpl" or die "Can't open $src_root/index.tmpl: $!\n";
  local $/ = "";
  my @orig_content = <INDEX>;
  close INDEX;

  my %replace_map = 
    (
     VERSION  => $VERSION,
     DATE     => $date,
     MODIFIED => $time_stamp,
    );

  for (qw(short long)) {

    $replace_map{MAIN_TOC} = ${$r_toc{$_}};
    $replace_map{TOC} = $toc_link{$_};

    my @content = @orig_content;

    foreach (@content) {
      s/\[(\w+)\]/$replace_map{$1}/g;
    }

    open INDEX, ">$file{$_}" or die "Can't open $file{$_}: $!\n";
    print INDEX @content;
    close INDEX;

  }

} # end of sub make_index_file


###################
sub make_indexps_file{

  use vars qw($VERSION);
  require $version_file;

  my ($mon,$day,$year) = (localtime ( time ) )[4,3,5];
  $year = 1900 + $year;
  my $time_stamp = sprintf "%02d/%02d/%04d", ++$mon,$day,$year;

  my $date = sprintf "%s, %d %d", (split /\s+/, scalar localtime)[1,2,4];

  my %replace_map = 
    (
     VERSION  => $VERSION,
     DATE     => $date,
     MODIFIED => $time_stamp,
    );

  open INDEX, "$src_root/indexps.tmpl" or die "Can't open $src_root/indexps.tmpl: $!\n";
  local $/ = "";
  my @content = <INDEX>;
  close INDEX;

  foreach (@content) {
    s/\[(\w+)\]/$replace_map{$1}/g;
  }

  open INDEX, ">$ps_root/index.html" or die "Can't open $ps_root/index.html: $!\n";
  print INDEX @content;
  close INDEX;

} # end of sub make_indexps_file


###############
sub make_tar_gz{

  mkdir $out_dir, 0755 unless -d $out_dir;

    # copy all to an out dir
  system "cp -r $rel_root/* $out_dir";

  if ($generate_pdf) {
    print "gzip $ps_root/mod_perl_guide.pdf\n";
    system("gzip $ps_root/mod_perl_guide.pdf");
    print "mv $ps_root/mod_perl_guide.pdf.gz $out_name\n";
    move("$ps_root/mod_perl_guide.pdf.gz","$root/$out_name");
  }

  chdir $root;

  print "mv $out_name.tar.gz $out_name.tar.gz.old\n" if -e "$out_name.tar.gz";
  rename "$out_name.tar.gz", "$out_name.tar.gz.old" if -e "$out_name.tar.gz";
  system "tar czvf $out_name.tar.gz $out_name";

		# Clean up
  system "rm -rf $out_name";

  print "*** Error: PDF did not enter the release package!\n"
    unless $generate_pdf;

} # end of sub make_tar

sub usage{

  print <<USAGE;
    ./build.pl [options]

  -h    this help
  -v    verbose
  -t    create tar.gz
  -p    generate PS file
  -d    generate PDF file
  -f    force a complete rebuild
  -a    print available hypertext anchors
  -l    do hypertext links validation
  -m    executed from Makefile (forces rebuild,
				no PS/PDF file,
				no tgz archive!)

USAGE

  exit;

}


__END__

=head1 NAME

Pod::HTML-n-PDF::Builder -- builds HTML, PS and PDF from multiple POD files

=head1 SYNOPSYS

 ./bin/build.pl -<options>

Options:

  -h    this help
  -v    verbose
  -t    create tar.gz
  -p    generate PS file
  -d    generate PDF file
  -f    force a complete rebuild
  -a    print available hypertext anchors
  -l    do hypertext links validation
  -m    executed from Makefile (forces rebuild,
				no PS/PDF file,
				no tgz archive!)

=head1 DESCRIPTION

This code knows to do three things with your POD files.

=over

=item 1.

Generate HTMLs

=item 2.

Generate a special version of HTMLs and convert them into a single
PostScript file

=item 3.

Generate a special version of HTMLs and convert them into a single
PostScript file and then into a PDF file.

=back

You can customise the look and feel of the PS and therefore the PDF by
tweaking the I<./bin/html2ps> file. You might need to read the html2ps
manual to do some complex changes.

Be careful that if your documentation that you want to put in one PS
or PDF file is very big and you tell html2ps to put the TOC at the
beginning you will need lots of memory because it won't write a single
byte to the disk before it gets all the HTML markup converted to PS.

When you want to use your own files in this convertor, make sure you
list them in I<./bin/build.pl> using the order you want them to show
up in the PS or PDF format.


=head1 EXTENSION

Note that this tool uses Guide::Pod2Html and Guide::Pod2HtmlPS which
understand an extended POD symantics. It's described in
I<docs/extended_pod.pod>


=head1 PREREQUISITES

All these are not required if all you want is to generate only the
html version.

=over 

=item * html2ps

from http://www.tdb.uu.se/~jan/html2ps.html

Needed to generate the PS and PDF versions

=item * ps2pdf

Needed to generate the PDF version

=item * Storable

Perl module available from CPAN (http://cpan.org/)

Allows source modification control, so if you modify only one file you
will not have to rebuild everything to get the updated HTML files.

=back



=head1 SUPPORT

Notice that this tool relies on two tools (ps2pdf and html2ps) which I
don't support. So if you have any problem first make sure that it's
not a problem of these tools.

=head1 BUGS

Huh?

=head1 AUTHOR

Stas Bekman <stas@stason.org>

=head1 SEE ALSO

perl(1), Pod::HTML, html2ps, ps2pod(1), Storable(3)

=head1 COPYRIGHT

This program is distributed under the Artistic License.

