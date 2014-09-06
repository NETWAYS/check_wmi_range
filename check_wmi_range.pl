#!perl -w
# COPYRIGHT:
#
# This software is Copyright (c) 2011 NETWAYS GmbH, Christoph Niemann
#                                <support@netways.de>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from http://www.fsf.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.fsf.org.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to NETWAYS GmbH.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# this Software, to NETWAYS GmbH, you confirm that
# you are the copyright holder for those contributions and you grant
# NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.

# includes
use strict;
use Getopt::Long;
use File::Basename;
use DBI;
use Win32::OLE;

# declaration of variables
use vars qw(
	$version
	$progname
	$opt_critical
	$opt_warning
	$opt_exclude
	$opt_include
	$opt_help
	$opt_usage
	$opt_version
	$opt_class
	$opt_object
	$opt_zero
	$opt_total
	$opt_sleep
	$opt_verbose
	$opt_no_perf
	$opt_contra_indi
	%states
	%state_names
	$row
	$dbh
	$sth
	$ev
	$error_code
	$output
	$perf_data
	$instance
	@instances
	%value
	);
	

$progname = basename($0);
$version = '0.55';
$opt_exclude = 'no EXCLUDE';
# get options
Getopt::Long::Configure('bundling');
GetOptions (
   "c=s" => \$opt_critical, "critical=s" => \$opt_critical,
   "w=s" => \$opt_warning,  "warning=s"  => \$opt_warning,
   "e=s" => \$opt_exclude,  "exclude=s"	 => \$opt_exclude,
   "i=s" => \$opt_include,  "include=s"	 => \$opt_include,
   "C=s" => \$opt_class,    "class=s"    => \$opt_class,
   "o=s" => \$opt_object,   "object=s"   => \$opt_object,
   "s=s" => \$opt_sleep,      "sleep=s"   => \$opt_sleep,
   "n|no-performance-data"				 => \$opt_no_perf,
   "z"   => \$opt_zero,     "zero"       => \$opt_zero,
   "t"   => \$opt_total,    "no_total"      => \$opt_total,
   "h"   => \$opt_help,     "help"       => \$opt_help,
                            "usage"      => \$opt_usage,
   "v|verbose:s"   						 => \$opt_verbose,
   "I|idle-contra-indicator:s"   		 => \$opt_contra_indi,
   "V"   => \$opt_version,  "version"    => \$opt_version
  ) || die "Try `$progname --help' for more information.\n";

# Errorstates

$error_code = 0;
# Nagios exit states
%states = (
	OK       => 0,
	WARNING  => 1,
	CRITICAL => 2,
	UNKNOWN  => 3
	);

# Nagios state names
%state_names = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN'
	);

# subs
sub print_help() {
  print "$progname $version - checks one wmi object per instance against a threshold\n";
  print "Options are:\n";
  print "  -c, --critical                  Enter the critical threshold\n";
  print "  -w, --warning                   Enter the warning threshold \n";
  print "  -C  --class                     Enter the WMI class\n";
  print "  -o  --object                    Enter the WMI object\n";
  print "  -e  --exclude                   Enter a regex to exclude instances\n"; 
  print "      to exclude more than one instance write -e \"(instance1|instance2)\"\n";
  print "  -i  -- include                  Enter a regex to include instances\n";
  print "      other Instances will be skipped\n";
  print "  -t  --no_Total				   hide the _Total instance\n";
  print "  -z  --zero                      hide zero values\n";
  print "  -s  --sleep                     run twice and sleep between the iterations <time to sleep>\n";
  print "  -I  --idle-contra-indicator     designed for proc_process. Check's if there's enough idle time left <threshold>\n";
  print "        It becomes critical if the real idle time of the last free core falls below threshold \n";
  print "  -n, --no-perf-data               no performance data\n";
  print "  -v  --verbose                     verbose mode\n";
  print "  -h, --help                      display this help and exit\n";
  print "      --usage                     display a short usage instruction\n";
  print "  -V, --version                   output version information and exit\n";
  print "Requirements:\n";
  print " A fully qualified wmi String consists of \\Class\\Instance\\Object\\Value\n";
  print " This plugin uses perl and DBD::WMI to get values from multiple WMI Instances for each object.\n";
  print " A working WMI counter is for example Win32_PerfFormattedData_Tcpip_NetworkInterface\\\<InstanceName\>\\BytesTotalPersec\n";
  print " In most cases you want to exclude the \"_Total\" instance ( -t).\n";
  print "Examples: \n\n";
  print " Physical disktime: \n  Class = Win32_PerfFormattedData_PerfDisk_PhysicalDisk\n  Object = percentdisktime\n";
  print "  cmd: perl -w $progname -w 10 -c 20 -C Win32_PerfFormattedData_PerfDisk_PhysicalDisk -o percentdisktime -t\n";
  print "\n Interface Traffic: \n  Class = Win32_PerfFormattedData_Tcpip_NetworkInterface\n  Object = BytesTotalPersec\n";
  print "  cmd: perl -w $progname -w 1000000 -c 1500000 -C Win32_PerfFormattedData_Tcpip_NetworkInterface -o BytesTotalPersec\n";
  print "\n Process CPU usage: \n  Class = Win32_PerfFormattedData_Perfproc_Process\n  Object = PercentProcessorTime\n";
  print "  cmd: perl -w $progname -w 10 -c 20 -C Win32_PerfFormattedData_Perfproc_Process -o PercentProcessorTime -t -e Idle -z\n";
}

sub print_usage() {
  print "Usage: $progname -w <warning> -c <critical> -C <class> -o <object> -e <exclude>(optional)\n";
  print "       $progname --help\n";
  print "       $progname --version\n";
}

sub print_version() {
	print "$progname $version\n";
}

# verbose
sub beVerbose {
        my $type = shift;
        my $text = shift;

        if (defined $opt_verbose) {
                # generate message
                my $message = localtime(time)." | Verbose: $type: $text\n";

                # should write log to file or STDOUT?
                if ($opt_verbose ne "") {
                        open(LOGF,">>$opt_verbose") || die $!;
                        print LOGF $message;
                        close(LOGF);
                } else {
                        print $message;
                }
        }
}

# sub calls
if ($opt_help) {
  print_help();
  exit $states{'UNKNOWN'};
}

if ($opt_usage) {
  print_usage();
  exit $states{'UNKNOWN'};
}

if ($opt_version) {
  print_version();
  exit $states{'UNKNOWN'};
}

unless ($opt_warning or $opt_critical) {
  print_usage();
  exit $states{'UNKNOWN'};
}

# main
    my $dbh = DBI->connect('dbi:WMI:');
   
    my $sth = $dbh->prepare(<<WQL);
        select * from $opt_class
WQL
  
$sth->execute();

while (defined (my $row = $sth->fetchrow_arrayref())) {
	my $ev = $row->[0];
	$instance = $ev->{Name};
	#print "I1=$instance\n";
	# exclude options
	if ($instance=~m/$opt_exclude/i) {next;}
	if (defined $opt_include) {
		if ($instance!~m/$opt_include/i) {next;}
	}
	if ($opt_total && $instance=~m/_Total/) {next;}
	push (@instances, $instance);
	$value{$instance} = $ev->{$opt_object};
	#print "V=$value{$instance}\n";
}
if (defined $opt_sleep) {
	sleep $opt_sleep;
	$sth->execute();
	while (defined ($row = $sth->fetchrow_arrayref())) {
		$ev = $row->[0];
		$instance = $ev->{Name};
		#print "I2=$instance\n";
		# exclude options
		if ($instance=~m/$opt_exclude/i) {next;}
		if (defined $opt_include) {
			if ($instance!~m/$opt_include/i) {next;}
		}
		if ($opt_total && $instance=~m/_Total/) {next;}
		if (defined $value{$instance} && defined $ev->{$opt_object}) {
			beVerbose("Addition", "Value1: $value{$instance} + Value2: $ev->{$opt_object}");
			$value{$instance} = ($value{$instance} + $ev->{$opt_object})/2;
		}
	}
	
}

	# zero option
	

while (@instances) {
	$instance = shift(@instances);
	#print "Auswertung: Instanz = $instance - Wert $value{instance}\n";
	if ($opt_zero && $value{$instance} == 0) {next;}
	if ($value{$instance} > $opt_warning && $error_code < 2) {
		$error_code = 1;
    }
    if ($value{$instance} > $opt_critical) {
		$error_code = 2;
    } 
	$output .= " \'$instance\' = $value{$instance},"; 
	$perf_data .= "\'$instance\'=$value{$instance};$opt_warning;$opt_critical;$value{$instance};$value{$instance} ";
}

# -I contra_indicator
my $idle;
if (defined $opt_contra_indi) {
	my $sth = $dbh->prepare(<<WQL);
    	select PercentIdleTime from Win32_PerfFormattedData_PerfOS_Processor where name like '_Total'
WQL
  	$sth->execute();
	$row = $sth->fetchrow_arrayref();
	$idle = $row->[0];
	#print "IDLE = $idle\n";
    #$idle = $ev->{PercentIdleTime};
	#print $idle;
}

unless ($output) {
	print "OK";
	if (defined $opt_contra_indi && defined $idle) { print " - IDLE = $idle"};
	print "\n";
	exit 0;
} else {
	chop($output);
	unless (defined $opt_no_perf) {
		if (defined $opt_contra_indi && defined $idle && $idle > $opt_contra_indi) {
			$error_code = 0;
		}
		print "$state_names{$error_code}";
		if (defined $opt_contra_indi && defined $idle) { print " - IDLE = $idle"};
		print " -$output | $perf_data\n";
	}
	else {
		if (defined $opt_contra_indi && defined $idle && $idle > $opt_contra_indi) {
			$error_code = 0;
		}
		print "$state_names{$error_code}";
		if (defined $opt_contra_indi && defined $idle) { print " - IDLE = $idle"};
		print " -$output\n";
	}
		exit $error_code;    	
    }

