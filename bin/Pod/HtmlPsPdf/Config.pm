package Pod::HtmlPsPdf::Config;

use strict;

# META: probably move FindBin here

########
sub new{
  my $class = shift;

    # pod files in the order you want to see them in the linked html
    # (and the book)
  my @ordered_pod_files =
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

  # Non-pod/html files or dirs to be copied unmodified
  my @non_pod_files =
    qw(
       CHANGES style.css images code
      );

    # The root of the project relative to the binary
  my $root      = "..";

    # The dir of the src files (DataBases)
  my $src_root  = "$root/src";
    # The dir of the executables
  my $bin_root  = "$root/bin";

  my $self = bless
    {
     pod_files     => \@ordered_pod_files,
     nonpod_files  => \@non_pod_files,
     root          => $root,
     src_root      => $src_root,
     ps_root       => "$root/ps", # The dir of the ps files
     split_root    => "$root/split", # The dir of the split HTML files
     rel_root      => "$root/rel", # The dir of the static output files (end product)
     tmpl_index_html => "$root/tmpl/index.tmpl",  # tmpl files
     tmpl_index_ps   => "$root/tmpl/indexps.tmpl",  # tmpl files
     tmpl_page_html  => "$root/tmpl/page.tmpl",  # tmpl files
     tmpl_page_split_html  => "$root/tmpl/splitpage.tmpl",  # tmpl files
     tmpl_page_ps    => "$root/tmpl/pageps.tmpl",  # tmpl files
     out_name      => "mod_perl_guide",
     out_dir       => "$root/mod_perl_guide",
     last_modified => "$src_root/.last_modified",
     toc_file      => "$bin_root/toc_file",
     version_file  => "$src_root/Version.pm",
     dir_mode      => 0755,
     html2ps_exec  => "$bin_root/html2ps/html2ps",
     html2ps_conf  => "$bin_root/html2ps/html2ps.conf"
    };

  
  return $self;

} # end of sub new


# you can only retrieve data from this class, you cannot modify it.
##############
sub get_param{
  my $self = shift;

  return () unless @_;
  return unless defined wantarray;	
  my @values = map {defined $self->{$_} ? $self->{$_} : ''} @_;

  return wantarray ? @values : $values[0];

} # end of sub get_param


1;
__END__
