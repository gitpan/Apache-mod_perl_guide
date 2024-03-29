package Apache::mod_perl_guide;

use ExtUtils::MakeMaker;
use strict;
use FindBin ();

# prerequisites
my %require =
  (
   "Pod::HtmlPsPdf" => "0.03",
  );

#--- Installation check

#--- Check for mod_perl, Apache::ScoreBoard, GTop
for (keys %require) {
  chk_version($_ => $require{$_}) or
    warn  "\n"
        . "*** For ".__PACKAGE__." to work you require version $require{$_}, or later, of\n"
        . "$_.pm from CPAN\n\n";
}


sub chk_version{
  my ($pkg,$wanted) = @_;
  no strict 'refs';
  local $| = 1;

  print "Checking for $pkg...";

  eval { (my $p = $pkg . ".pm") =~ s#::#/#g; require $p;};

  print("not ok\n$@"),return if $@;

  my $vstr = ${"${pkg}::VERSION"} ? "found v" . ${"${pkg}::VERSION"}
                                 : "not found";
  my $vnum = ${"${pkg}::VERSION"} || 0;

  print $vnum >= $wanted ? "ok\n" : " " . $vstr . "\n";

  $vnum >= $wanted;

}



my $target_dir = get_target_dir();

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile
  (
   NAME         => __PACKAGE__,
   VERSION_FROM => 'src/Version.pm', # finds $VERSION
   AUTHOR       => 'Stas Bekman <stas@stason.org>',
   ABSTRACT     => 'mod_perl Guide',
   clean        => {FILES => 'ps_html rel_html bin/toc_file'},
   dist => {
	    PREOP => 'pod2text mod_perl_guide.pm > README',
	    COMPRESS => 'gzip -9f',
	    SUFFIX   => '.gz', 
	    DIST_DEFAULT => 'tardist',
	   },
   PREREQ_PM => \%require,
);


# manifypods is the only section we actually need (dist and clean also)
##################
sub MY::manifypods{

  return <<END;
SRC_DIR    = $FindBin::Bin
manifypods :
	\$(SRC_DIR)/bin/build -m
	\@echo 
	\@echo "The Guide was built in \$(SRC_DIR)/rel_html"

END

## --- My split section:

#SRC_DIR    = $FindBin::Bin
#split : manifypods
#	\$(SRC_DIR)/bin/build -sf
#	\@echo "The Split Guide was built in \$(SRC_DIR)/split"



} # end of sub MY::manifypods

##################
sub MY::install{

  return <<END;
TARGET_DIR = $target_dir
SRC_DIR    = $FindBin::Bin
install : manifypods
	\@cp -r \$(SRC_DIR)/rel_html/* \$(TARGET_DIR)
	\@echo "The Guide was installed in \$(TARGET_DIR)"

END

} # end of sub MY::install



# delete all non manifypods targets from pure_all
##################
sub MY::top_targets {
  package MY; # so that "SUPER" works right
  my($inherited) = shift->SUPER::top_targets(@_);
  $inherited =~ s/pure_all ::.*/pure_all ::/;
  $inherited;
} # end of sub MY::top_targets 



#-------------------------#
#       Helper subs       #
#-------------------------#

# this one was reaped from libnet package
##########
sub Prompt{
 my($prompt,$def) = @_;
 $def = "" unless defined $def;
 chomp($prompt);
 prompt($prompt,$def);
}

###################
sub get_target_dir{
  
  my @try_dirs = qw(/home/httpd/docs /home/httpd/html /home/httpd/htdocs
                    /home/www/docs /home/www/html /home/www/htdocs
                    /Library/WebServer/Documents );

  my $suggest_dir = "/home/httpd/docs";
  for (@try_dirs) {
    $suggest_dir=$_, last if -e $_;
  }
  
  my $target_dir = '';
  
  TARGET_DIR {
    print <<END;
The guide is a collection of HTML files intended to be installed under
your webserver's DocRoot directory.  This will allow you to browse the
files through you favorite Netscape browser.

END

#'
    my $prompt = "Enter the directory to install the html files :";
    my $def    = "$suggest_dir/manual/mod_perl_guide";
    $target_dir = Prompt($prompt,$def);

    unless (-d $target_dir  and -w _) {
      my $prompt = "Directory $target_dir doesn't exist. Create it? (y/n) :";
      my $def    = "y";
      my $answer = Prompt($prompt,$def);
      if ($answer =~ /^(y|yes)/i){
	eval {system "mkdir -p $target_dir";};
	print("Error: $@\n"), redo TARGET_DIR if $@;
      } else {
	redo TARGET_DIR;
      }
    }
  }
  
  return $target_dir;
}


# to make the release under a different name:
# make dist DISTVNAME=Apache-mod_perl_guide-1.26-fix1
