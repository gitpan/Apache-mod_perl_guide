#################################################################################################################
# config.pl - params for mod_perl guide builder 
##################################################################################################################

#################################################################################################################
#				Definitions									#
#################################################################################################################

		# Change only these variables

$root 	= "..";

		# These are the directories of the project

$bin_root  = "$root/bin";   # The dir of the executables
$src_root  = "$root/src";   # The dir of the src files (DataBases)
$ps_root   = "$root/ps";    # The dir of the ps files
$rel_root  = "$root/rel";   # The dir of the static output files (end product)
$out_name  = "guide";
$out_dir   = "$root/guide";
$last_modified = "$src_root/.last_modified";
$toc_file  = "toc_file";
$version_file = "$src_root/Version.pm";
# Don't remove!
1;
