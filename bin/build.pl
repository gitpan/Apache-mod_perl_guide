#!/usr/bin/perl -w

use strict;
use diagnostics;
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
getopts('htpfavlm', \%opts);

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
     porting
     performance
     install
     config
     strategy
     scenario
     frequent
     control
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

# Non pod/html files
my @other_srcs = qw(CHANGES style.css images);

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
  make_indexps_file();
  print "Generating a PostScript\n";
  my $command = "html2ps -f html2psrc -o $ps_root/mod_perl_guide.ps ";
  $command .= join " ", map {"$ps_root/$_.html"} "index", @ordered_srcs;
  print "Doing $command\n";
  system $command;
}

# Generate PDF file
if ($generate_pdf) {
  print "Generating a PDF\n";
  my $command = "ps2pdf $ps_root/mod_perl_tutorial.ps $ps_root/mod_perl_tutorial.pdf";
  print "Doing $command\n";
  system $command;
}

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
my $main_toc = join "\n", map {$$rh_main_toc{"$_.html"} } @ordered_srcs;

# create index.html
make_index_file(\$main_toc);

#  # build one long page with all pages inside
#open LONG, ">$rel_root/all.html" or die "Can't open $rel_root/all.html for writing :$!\n";
#print LONG qq{<HTML><BODY BGCOLOR="white"><CENTER>
#	      <H1>This page includes the entire guide and is suitable for printing!</H1>
#	      </CENTER><HR>
#	      };
#foreach ("index",@ordered_srcs) {
#  my $fh = IO::File->new("$rel_root/$_.html") or die "Couldn't open $rel_root/$_.html: $!\n";
#  print "$_\n";
#  print LONG <$fh>;
#  print LONG "\cL\n\n<HR SIZE=6>\n";
#}
#close LONG;

  # build the dist
make_tar_gz() if $make_tgz;

# go back to where you have from
chdir $orig_dir;

###########################################################################
###########################################################################
###########################################################################

###################
sub make_index_file{
  my $r_main_toc = shift || \undef;

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
     MAIN_TOC => $$r_main_toc,
     MODIFIED => $time_stamp,
    );

  open INDEX, "$src_root/index.tmpl" or die "Can't open $src_root/index.tmpl: $!\n";
  local $/ = "";
  my @content = <INDEX>;
  close INDEX;

  foreach (@content) {
    s/\[(\w+)\]/$replace_map{$1}/g;
  }

  open INDEX, ">$rel_root/index.html" or die "Can't open $rel_root/index.html: $!\n";
  print INDEX @content;
  close INDEX;

} # end of sub make_index_file


###################
sub make_indexps_file{

  open VERSION, "$src_root/VERSION" or die "Can't open $src_root/VERSION: $!\n";
  my $version = <VERSION>;
  close VERSION;

  my ($mon,$day,$year) = (localtime ( time ) )[4,3,5];
  $year = 1900 + $year;
  my $time_stamp = sprintf "%02d/%02d/%04d", ++$mon,$day,$year;

  my $date = sprintf "%s, %d %d", (split /\s+/, scalar localtime)[1,2,4];

  my %replace_map = 
    (
     VERSION  => $version,
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
    # copy files to a new directory
#  map { copy("$rel_root/$_","$out_dir/$_")} grep /\.html$/, DirHandle->new($rel_root)->read();

    # copy all to an out dir
  system "cp -r $rel_root/* $out_dir";

  chdir $root;

    # tar all the release files, compress them and put into a release directory
  print "tar cvf $out_name.tar $out_name\n";
  system("tar cvf $out_name.tar $out_name");
		# Compress it and save the prev copy
  print "mv $out_name.tar.gz $out_name.tar.gz.old\n" if -e "$out_name.tar.gz";
  rename "$out_name.tar.gz", "$out_name.tar.gz.old" if -e "$out_name.tar.gz";
  print "gzip $out_name.tar\n";
  system("gzip $out_name.tar");
  print "mv $out_name.tar.gz $out_name\n";
  move("$out_name.tar.gz",$out_name);

  if ($generate_ps) {
    print "gzip ./ps/mod_perl_guide.ps\n";
    system("gzip ./ps/mod_perl_guide.ps");
    print "mv ./ps/mod_perl_guide.ps.gz $out_name\n";
    move("./ps/mod_perl_guide.ps.gz",$out_name);
  }

    # tar all the source and bin files, compress them and put into a
    # release directory
    # clean the src and bin dirs
  my $src = "guide-src";
  mkdir $src, 0755;
  system("cp -r src bin $src");

  print "Ignore the error about ': No such file or directory' if it shows up\n";
  system("rm $src/src/*~ $src/bin/*~ $src/bin/*/*~");

  system("tar cvf guide-src.tar $src");
		# Compress it and save the prev copy
  rename "guide-src.tar.gz", "guide-src.tar.gz.old" if -e "guide-src.tar.gz";
  system("gzip guide-src.tar");
  move("guide-src.tar.gz",$out_name);

  system("tar cvf $out_name.tar $out_name");
  system("gzip $out_name.tar");

		# Clean up
  system("rm -rf $out_name");
  system("rm -rf $src");

  print "*** Error: PostScript did not enter the release package!\n"
    unless $generate_ps;

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

}
