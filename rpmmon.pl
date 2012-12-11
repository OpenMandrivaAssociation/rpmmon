#!/usr/bin/perl
#
# rpmmon  by Guillaume Cottenceau <gc at mandrakesoft dot com>
#
# Copyright (c) 2000-2001 by MandrakeSoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# http://people.mandrakesoft.com/~gc/html/rpmmon-tut.html
#

use File::Find;
use strict;
use vars qw($program_name $author $version $rcfile $url_maints $url_maints_source $url_cds @modes @opts @mount_points %my_packages %current_version %current_release %package2maintainer %package2cd $verbose $more_options $show_version $tell_freshmeat_info $source $who $mount_point $package_name @packages_responsible $url_maintainers);

$program_name = 'rpmmon';
$author = 'Guillaume Cottenceau <gc at mandrakesoft dot com>';
$version = '0.6.3';

$url_maints =        'http://qa.mandrakesoft.com/cgi-bin/maints.cgi';
$url_maints_source = 'http://qa.mandrakesoft.com/cgi-bin/srpmmaints.cgi';
$url_cds =           'http://qa.mandrakesoft.com/cooker.cd';


#--------------------------------------------------
# What this script will do
#--------------------------------------------------

@modes = (
	  [ '-c', "\tcheck", "check if user's packages are up-to-date in your Development branch", \&check ],
	  [ '-l', 'lint', "check one's packages with rpmlint", \&rpmlint, 'who' ],
	  [ '-b', 'build', "build user's database of packages-in-charge-of -> freshmeat appindex", \&build, 'who' ],
	  [ '-a', "\tall", 'build all packages -> freshmeat appindex', \&buildall ],
	  [ '-m', 'mountpoint', 'specify the mount point where your Development branch should be found', \&mount_point, 'mount_point' ],
	  [ '-p', 'package maintainer', 'query the package maintainer of the given package -- possibility to give multiple packages separated with commas', \&package_maintainer, 'package_name' ],
	  [ '-q', 'query', 'query the list of packages assigned to the given maintainer (use full email, or only username)', \&query_maintainer, 'who' ],
	  [ '-Q', 'Query', 'query the list of packages assigned to the given maintainer, print them fully qualified', \&query_maintainer_full, 'who' ],
	  [ '-n', "\tmaintainers", 'query the list of maintainers', \&query_list_maintainers ],
	  [ '-u', "\tunmaintained", 'print the packages without maintainer', \&print_unmaintained_packages ],
	  [ '-t', "\tmaints source", 'get maints source at given place (maybe standard file, http://, https://, or use_rpms)', \&set_maints_source, 'url_maints' ],
          [ '-d', "\tcds source", 'get cds source at given place (maybe standard file, http:// or https://)', \&set_cds_source, 'url_cds' ],
	  );

@opts = (
	 [ '-s', "\tsource", 'take SRPM maints url (will override any -t previously used)', \$source ],
	 [ '-i', "\tinfo", 'print our-version/freshmeat-version every time', \$tell_freshmeat_info ],
	 [ '-V', "\tverbose", 'display more information', \$verbose ],
	 );


#--------------------------------------------------
# Generic script stuff
#--------------------------------------------------

sub fail { die "Exiting on failure.\n" }
sub fail_with_message { print STDERR $_[0], "\n"; fail() }
sub puts { print @_, "\n" }

push @modes, (['-v', "\tversion", 'print out version and author stuff', \&show_version],
	      ['-h', "\thelp", 'more help on parameters', \&show_more_options],
	      );

{
    my %self_test;
    foreach (@modes, @opts) {
	$self_test{$_->[0]} and fail_with_message('Internal error: duplicate options names');
	$self_test{$_->[0]} = 1;
    }
}

sub show_version
{
    puts
"<$program_name> v$version helps you build better RPMs.

By $author.
Copyright (c) 2000-2001 by MandrakeSoft.
This is free software under the GPL License.";
}

sub show_options
{
    show_version();
    puts "
Usage: $program_name <mode> [options]
modes:";
    foreach (@modes) {
	print "  $_->[0]";
	my $index = 4;
	print " <$_->[$index]>" and $index++ while defined $_->[$index];
	puts "\t$_->[1]", ($more_options and "\n\t  $_->[2]");
    }
    puts "options:";
    puts "  $_->[0]\t$_->[1]", ($more_options and "\n\t  $_->[2]") foreach @opts;
    puts "  -r <rc_file>\tuse an alternate rc file";  # needs to be treated separately
    puts();
    $more_options or puts ">>> Use option -h for more details. <<<";
    $more_options and puts ">>> For a short tutorial, you may visit:                    <<<\n",
                           ">>> http://people.mandrakesoft.com/~gc/html/rpmmon-tut.html <<<\n";
}

sub show_more_options { $more_options = 1; show_options() }


# Disable file buffering [to display strings on the tty even when no trailing \n is added]
$| = 1;

my $argnum = 0;
foreach (@ARGV) {
    if ($_ eq "-r") {
	(defined $ARGV[$argnum+1] and ($rcfile = $ARGV[$argnum+1])) or fail_with_message('Missing parameter rc_file after -r');
    }
    $argnum++;
}
defined $rcfile or $rcfile = "$ENV{HOME}/.rpmmonrc";

read_user_params();

foreach my $arg (@ARGV) {
    $arg eq $_->[0] and (${$_->[3]} = 1) foreach @opts;
}

$argnum = 0;
my $done_something;
foreach my $arg (@ARGV) {
    foreach my $mode (@modes) {
	if ($arg eq $mode->[0]) {
	    my $index = 4;
	    my $real_argnum = 0;
	    while (defined($mode->[$index])) {
		$argnum++; $real_argnum++;
		defined $ARGV[$argnum] or fail_with_message("Missing parameter $real_argnum ($mode->[$index]) for $mode->[0]");
		no strict 'refs';
		${$mode->[$index]} = $ARGV[$argnum];
		$index++;
	    }
	    &{$mode->[3]}();
            $done_something = 1;
            $argnum--;
	}
    }
    $argnum++;
}

$done_something or show_options();
exit;


#--------------------------------------------------
# The subfunctions to do it
#--------------------------------------------------

sub cat_ { local *F; open F, $_[0] or $_[1] ? die "cat of file $_[0] failed: $!\n" : return; my @l = <F>; wantarray ? @l : join '', @l }

sub get_http_file
{
    my ($url) = @_;
    my $is_okay if 0;
    if (!$is_okay) {
	my $curlv = `curl --version`;
	$curlv =~ /curl/ or die "You need `curl' binary for HTTP download\n";
	$curlv =~ /OpenSSL/ or die "You need an OpenSSL-enabled curl to support encrypted URLs.\n";
	$is_okay = 1;
    }
    return `curl -s $url`;
}

sub get_header_http_file { return `lynx -head -dump $_[0]` }

sub grab_freshmeat_version
{
    my ($url_frsh) = @_;
    if ($url_frsh =~ /projects/) { # let's use the XML backend: quicker, cleaner, better
	$url_frsh =~ s/projects/projects-xml/;
	my $xml_resp = get_http_file($url_frsh);
	return $1 if $xml_resp =~ m|<latest_release_version>([^<]+)</latest_release_version>|; # frsh seems to give only Default branch infos; good
    } else { # if no "projects", that may be an old-style appindex URL, if any, so try to fallback
	my $http_resp = get_http_file($url_frsh);
	return $1 if $http_resp =~ m|Default.*\n.*\n.*\n.*\n.*<a href="/releases/[0-9]+/">([^<]+)|;
    }
}

# I have to be a little bit clever than basic "gt" because it would fail on, for example, "0.9 < 0.11"
# So, I address the "standard" way, the dot-separated numbers only. The rest will have the "gt" comparison.
sub is_new_version
{
    my ($f, $d, $rel) = @_;
    if (($f =~ /^[0-9\.]+$/) && ($d =~ /^[0-9\.]+$/)) {
	while (1) {
	    my ($f_d, $f_l) = $f =~ /^\.?([^\.]+)(.*)$/ or return $f gt $d;
	    my ($d_d, $d_l) = $d =~ /^\.?([^\.]+)(.*)$/ or return $f gt $d;
	    return 1 if ($f_d > $d_d);
	    return 0 if ($f_d < $d_d);
	    ($f, $d) = ($f_l, $d_l);
	}
    }
    if ($f ne $d) {
        #- we use an upgradable naming in which release may contain the alphabetical suffix of versions such as "beta3"
        if ($f !~ /^[\d\.]+$/ && $f =~ /^\Q$d/ && $rel =~ quotemeta(substr($f, length($d)))) {
            return 0;
        } else {
            return $f gt $d;
        }
    }
}

sub scan_package
{
    puts "Package $_[0]." if $verbose;
    return if $my_packages{$_[0]} eq 'NOFRESHMEATPAGE'; # special case, if you want to have a package in the rcfile only for linting

    my $stable_version = grab_freshmeat_version($my_packages{$_[0]});

    $verbose and ($stable_version != '' ? puts "    Last Stable Version: $stable_version" :
                                          puts "\t*** No Default Branch found");

    if ($stable_version != '' && defined $current_version{$_[0]}) {
	$verbose and puts "  Version in distrib is: $current_version{$_[0]} (release $current_release{$_[0]})";
	if (is_new_version($stable_version, $current_version{$_[0]}, $current_release{$_[0]}) || $tell_freshmeat_info) {
	    my $maint = defined $package2maintainer{$_[0]} ? $package2maintainer{$_[0]} : 'NOT_FOUND';
	    return sprintf "%-32s %-18s %12s %12s\n", $maint, $_[0], $current_version{$_[0]}, $stable_version;
	}
    }
}

# each_package { CODE }
# scans through each package from the @mount_points and:
# - sets $::a, $::b, $::c, $::d to package_name, package_version, package_release, full_filename
# - calls CODE
sub each_package(&) {
    my ($f) = @_;
    verify_mount_point();
    my @current_distrib_files;

    foreach my $mp (@mount_points) {
	puts "Looking for *.rpm files in $mp..." if $verbose;
	find(sub { $File::Find::name =~ /\.rpm$/ and push @current_distrib_files, $File::Find::name }, $mp);
    }
    puts 'Total ', int(@current_distrib_files), ' files.' if $verbose;

    foreach $::d (@current_distrib_files) {
	($::a, $::b, $::c) = $::d =~ m|([^/]+)-([^-]+)-([^-]+)\.[^\.]+\.rpm|;
	&$f;
    }
}

sub build_current_versions
{
    each_package { ($current_version{$::a}, $current_release{$::a}) = ($::b, $::c) };
}

sub package_to_version($)
{
    my $package_name = shift;
    defined %current_version or build_current_versions();
    $current_version{$package_name} or 'MISSING';
}

sub package_to_release($)
{
    my $package_name = shift;
    defined %current_release or build_current_versions();
    $current_release{$package_name} or 'MISSING';
}


sub build_package2maintainer
{
    my $url_maintainers = $source ? $url_maints_source : $url_maints;
    puts "Getting information about packages from: $url_maintainers" if $verbose;
    if ($url_maintainers ne 'use_rpms') {
	my @lines = $url_maintainers =~ /^http/ ? get_http_file($url_maintainers) : cat_($url_maintainers);
	/([^ ]+)\s+([^ @]*@.+)/ and $package2maintainer{$1} = $2 foreach @lines;
    }
    puts 'Found maintainers for ', int(keys %package2maintainer), ' different packages.' if $verbose;
}

sub build_package2cd
{
    puts "Getting information about packages2cd from: $url_cds" if $verbose;
    my @lines = $url_cds =~ /^http/ ? get_http_file($url_cds) : cat_($url_cds);
    print "lines: ", scalar(@lines), "\n";
    foreach (@lines) {
	my ($cdnumber, $fullname) = $_ =~ /(\S+)\s(\S+)/ or next;
	$fullname =~ /\.src$/ and next;
	$fullname =~ m|([^/]+)-([^-]+)-([^-]+)\.[^\.]+$| or next;
	$package2cd{$1} = [ $fullname, $cdnumber ];
    }
    if ($verbose) {
	my %cds_info;
	$cds_info{$package2cd{$_}->[1]}++ foreach keys %package2cd;
	print "Found CDs/packages: ";
	print "$_/$cds_info{$_} " foreach sort keys %cds_info;
	puts();
    }
}

sub verify_uptodate
{
    build_current_versions();
    build_package2maintainer();

    puts int(keys %my_packages), ' packages to watch.
Scanning Freshmeat to grab the last registered versions:' if $verbose;

    printf "%-32s %-18s %12s %12s\n\n", 'Maintainer', 'Package', 'Our-version', 'Frsh-version';
    print sort map { scan_package($_) } keys %my_packages;
}

sub addpackage
{
    $_[0] =~ s/\s//g;
    push @packages_responsible, $_[0];
}

sub maint_equals
{
    my ($pkg1, $pkg2) = @_;
    $pkg1 eq $pkg2 and return 1;
    $pkg1 =~ s/@.*//;
    $pkg2 =~ s/@.*//;
    $pkg1 eq $pkg2 and return 1;
    return 0;
}

sub calc_packages_responsible_for
{
    build_package2maintainer();
    puts "Packages for $who are:";

    maint_equals($package2maintainer{$_}, $who) and addpackage($_) foreach keys %package2maintainer;
    @packages_responsible or fail_with_message("No packages found for user $who in list provided by QA.");
    puts $_ foreach @packages_responsible;
}

sub calc_all_packages
{
    each_package { addpackage($::a); print '.' if $verbose };
    puts 'done.' if $verbose;
}


sub grab_information_location
{
    puts "\nContacting host freshmeat.net several times to find entries in their database.";

    foreach my $pack (@packages_responsible) {
	puts "\npackage `$pack'";
	my $response = get_http_file("http://freshmeat.net/projects/$pack");
	if ($response !~ / Invalid project ID/) { #'
		$my_packages{$pack} = "http://freshmeat.net/projects/$pack";
		puts "  Directly exists as /projects/$pack";
	} else {
	    my $response = get_header_http_file("http://freshmeat.net/search/?q=$pack");
	    if ($response =~ /Location: (.+)/) {
		$my_packages{$pack} = $1;
		$1 =~ m|/([^/]+)/$|;
		puts "  Direct match (project `$1')";
	    } else {
		$response = get_http_file("http://freshmeat.net/search/?q=$pack");
		if ($response =~ />0 projects found/) {
		    puts '       -- 0 projects found --';
		} else {
		    if ($response =~ m|EXACT MATCH:</b><br><a href="/projects/([^/]+)/|) {  #";
			puts "  Project `$1' is an exact match.";
			$my_packages{$pack} = "http://freshmeat.net/projects/$1";
		    } else {
			puts '       -- no exact match with query --';
		    }
		}
	    }
	}
    }

    puts '

I am now configured to watch new versions of the following packages:';

    puts $_ foreach keys %my_packages;

    puts "
  *** If you feel you can find more pages (often the package name in Cooker and
  *** in Freshmeat are different..), insert the lines in your rcfile";

}


sub fail_on_rc_file
{
    my ($line) = @_;
    puts
"Failed while parsing your rcfile at line:
>>>
$line
<<<
You need to validate the value by hand, or remove the file.
";
    fail();
}

sub read_user_params
{
    my $line = 0;
    foreach (cat_($rcfile)) {
	chomp;
	/([^ ]+)/ or fail_on_rc_file($_);

	if ($1 eq 'MOUNT_POINT') {
	    /([^ ]+) ([^ ]+)/ or fail_on_rc_file($_);
	    push @mount_points, $2 if !grep { $_ eq $2 } @mount_points;
	} elsif ($1 eq 'RPM_TO_CHECK') {
	    /([^ ]+) ([^ ]+) ([^ ]+)/ or fail_on_rc_file($_);
	    $my_packages{$2} = $3;
	} elsif ($1 eq 'URL_MAINTS') {
	    /([^ ]+) ([^ ]+)/ or fail_on_rc_file($_);
	    $url_maints = $2;
	} elsif ($1 eq 'MAINT') {
	    /([^ ]+) ([^ ]+) ([^ ]+)/ or fail_on_rc_file($_);
	    $package2maintainer{$2} = $3;
	}
    }
}


sub write_user_params
{
    open PARAMS, ">$rcfile" or fail_with_message("Can't open rcfile for writing.");
    print PARAMS "MOUNT_POINT $_\n" foreach @mount_points;
    print PARAMS "URL_MAINTS $url_maints\n";
    print PARAMS "RPM_TO_CHECK $_ $my_packages{$_}\n" foreach keys %my_packages;
    if ($url_maints eq 'use_rpms') {
	print PARAMS "MAINT $_ $package2maintainer{$_}\n" foreach keys %package2maintainer;
    }
}


sub verify_mount_point
{
    defined @mount_points or fail_with_message(
"First, you need to define one mount point for your Development branch.
This is the directory where the hottest RPM's of your distrib sit, on
your local system (called Cooker in Mandrake, Rawhide in RedHat). It must
be a local filesystem. (therefore, it can be NFS, for example)

Use option -m <mount-point>.

That's only needed one time per mountpoint, and allows to specify
multiple mountpoints (for example if you want to add contrib).

");
}

sub check
{
    verify_mount_point();
    defined %my_packages or fail_with_message('No package to watch. You should use option "-b" to build the database.'); 
    verify_uptodate();
}


sub rpmlint
{
    verify_mount_point();
    build_package2maintainer();
    each_package {
	next if !grep { $_ eq $::a && maint_equals($package2maintainer{$_}, $who) } keys %package2maintainer;
	puts "*** Rpmlinting package $::d" if $verbose;
	print `rpmlint $::d`;
    };
}


sub build
{
    calc_packages_responsible_for();
    grab_information_location();
    write_user_params();
}

sub buildall
{
    calc_all_packages();
    grab_information_location();
    write_user_params();
}


sub print_unmaintained_packages
{
    calc_all_packages();
    build_package2maintainer();
    defined $package2maintainer{$_} or puts $_ foreach @packages_responsible;
}


sub mount_point
{
    puts "Adding mount-point in rcfile being: '$mount_point' (if not duplicate)";
    $mount_point =~ s|/$||;
    push @mount_points, $mount_point if !grep { $_ eq $mount_point } @mount_points;
    puts "You now have these mount point:\n", map { "\t$_\n" } @mount_points;
    $verbose = 1;
    build_current_versions();  # to test if given mountpoint seems to be ok
    write_user_params();
}

sub set_maints_source
{
    puts
"Setting the source for maintainers elsewhere. You can provide
a normal URL (http://..), an encrypted URL (https://..), a
local file, or the special 'use_rpms'. You're about to set it as:
\t", $url_maints, '

If a local or distant file, it must contain lines matching:
PACKAGE_NAME\s+MAINTAINER_NAME@

For example:

telnet  john@distro.com
kernel  smith@distro.com

If the special \'use_rpms\', the RPM\'s found at the mount point(s)
will be used to calculate the maintainers.
';

    if ($url_maints eq 'use_rpms') {
	@mount_points or fail_with_message(
"You're using the 'use_rpms' method, therefore you need
to set up at least one mount point before proceeding.");
	puts
"You're using the 'use_rpms' method: I will examine your
mount points, calculate the maintainers, and cache the
results in your rcfile. Re-run this option whenever you
want to update them.

Now examining RPMs. This may be long.";
	%package2maintainer = ();
	each_package {
	    my $pack = `rpm -qp --queryformat %{packager} $::d`;
	    if ($pack =~ /<([^<]+)\@[^>]+>/ || $pack =~ /(\S+)\@\S+/) {
		$package2maintainer{$::a} = $1;
		printf "%-32s %-18s\n", $1, $::a if $verbose;
	    }
	};
	puts 'Found ', int(keys %package2maintainer), ' entries.';
    }

    write_user_params();
}

sub set_cds_source {}

sub package_maintainer_recurse
{
    $package_name =~ m|^([^,]*/)?([^,]+)-([^-]+)-([^-]+)\.[^\.]+\.rpm| or $package_name =~ /()([^,]+)/;
    my @out;
    push @out, "$2:" if $verbose;
    defined $package2maintainer{$2} and push @out, $package2maintainer{$2} or push @out, 'NOT_FOUND';
    push @out, "($package2cd{$2}->[1])" if ($verbose && defined $package2cd{$2}->[1]);
    puts "@out";
    package_maintainer_recurse() if $package_name =~ s/^[^,]+,//;
}

sub package_maintainer
{
    build_package2maintainer();
    build_package2cd() if $verbose;
    package_maintainer_recurse();
}

sub query_list_maintainers
{
    my %temp_hash;
    build_package2maintainer();
    $temp_hash{$_} = 1 foreach values %package2maintainer;
    puts $_ foreach keys %temp_hash;
}

sub query_maintainer
{
    build_package2maintainer();
    build_package2cd() if $verbose;
    my $found = 0;
    foreach (keys %package2maintainer) {
	if (maint_equals($package2maintainer{$_}, $who)) {
	    my @out;
	    push @out, $_;
	    push @out, "($package2cd{$_}->[1])" if ($verbose && defined $package2cd{$_}->[1]);
	    $found = 1;
	    puts "@out";
	}
    }
    $found or puts "E: no packager by that name";
}

sub query_maintainer_full
{
    build_package2maintainer();
    foreach (keys %package2maintainer) {
	maint_equals($package2maintainer{$_}, $who) and puts "$_-", package_to_version($_), '-', package_to_release($_);
    }
}


# 0.6.3 Thu Dec 11 17:05:56 2003
#   - comply to new freshmeat xml responses
#
# 0.6.2 Fri Jun 13 17:29:07 2003
#   - better compare versions, case when we put a part of the version in the release to ease upgrades (1.0beta3 -> 1.0-0.beta3.1mdk)
#
# 0.6.1 Wed Jun 11 11:59:17 2003
#   - allow changing cds source
#
# 0.6.0 Wed Apr  2 18:13:03 2003
#   - comply to new freshmeat responses (when project/$name doesn't exist)
#   - use fully qualified maintainers
#
# 0.5.0.1 Fri Mar  1 14:46:10 2002
#   - exclude src rpm's from package2cd list
#
# 0.5.0
#   - have mountpoints recursively scanned (coded for Guillaume Rousse)
#   - print "no packager by that name" when -q is used when a non-existent packager
#   - make use of CD <-> RPM association
#   - use curl, it seems less bugged than wget
#
# 0.4.1 Fri Aug 10 16:15:48 2001
#   - pixelize a bit more with Damien and me
#   - rename to `rpmmon' in order to get an available project name at Freshmeat
#
# 0.4.0 Fri Aug 10 13:00:29 2001
#   - use encrypted URL version of "maints.cgi" in order to be able to use
#     this program from outside mandrake, especially for Cooker people
#   - remove all mdk specializations, become distro generic
#   - enable multiple mountpoints (so we can use Cooker and Contrib for example)
#   - enable package maintainers alternative source (url or local file)
#   - write a short tutorial at http://people.mandrakesoft.com/~gc/html/rpmmon-tut.html
#   - clean (try to pixelize) code to ease further release
#
# 0.3.1 Fri Jun  8 19:08:31 2001
#   - integrate chmou patch to show source
#   - beautify output
#
# 0.3.0 Thu Apr 26 16:23:21 2001
#   - comply to Freshmeat II (which sucks bigtime, infos are not in standard locations)
#
# 0.2.10 Fri Dec 15 13:58:04 2000
#   - comply to new maints.cgi format
#
# 0.2.9 Thu Oct 26 15:58:02 2000
#   - add option "-Q" to query packages for a given maintainers, obtaining fully qualified name of packages 
#
# 0.2.8 Mon Sep 25 13:45:19 2000
#   - add option "-M" to list all maintainers
#
# 0.2.7 Sun Sep 24 18:42:08 2000
#   - changes behaviour of "linting" option, now lints all packages of a given maintainer
#
# 0.2.6 Sun Sep 24 16:29:19 2000
#   - changes a little bit -V -p output for Pixel
#
# 0.2.5 Wed Sep 20 00:00:42 2000
#   - make it compliant with latest Freshmeat changes
#   - removed option "-e" [essential printings], replaced by the opposite "-V" [verbose printings]
#   - less annoying printings in "rpmlint" mode
#   - added multiple packages query for "-p", separated by commas
#
# 0.2.4 Fri Jun 23 19:35:20 2000
#   - added the option "print unmaintained packages"
#
# 0.2.3 Wed Jun 21 12:08:35 2000
#   - added the query of which packages for given maintainer
#
# 0.2.2 Tue Jun 20 10:57:08 2000
#   - added support for alternate config file
#
# 0.2.1 Mon Jun 19 11:09:58 2000
#   - added the query of package maintainer
#
# 0.2.0 Fri Jun 16 16:56:29 2000
#   - updated the location of the responsible of packages (now I have the latest ones, with help of mdk bugzilla) 
#   - bugfixed the "-b" option which was broken since 0.1.4
#   - rework internals of the script
#   - if no stable version in freshmeat, now uses the devel version as a comparison (instead of skipping the comp)
#   - more flexible way of telling cooker mount point (you tell the location of the RPM's, before it was the base of the CDROM branch)
#
# 0.1.6 Thu Jun 15 18:12:18 2000
#   - updated the location of the responsible of packages (list-rpms.txt on intranet)
#
# 0.1.5 Tue Jun 13 19:07:47 2000
#   - added option "-e" to print only essential stuff (needed for a daily report)
#   - better output display of the essential information
#   - added option "-a" to build the resource file for all packages
#
# 0.1.4 Sun Jun 11 22:47:48 2000
#   - fix to fit the new output of Freshmeat -> now uses "wget" instead of a socket connection
