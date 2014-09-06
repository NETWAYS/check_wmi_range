check_wmi_range
===============

Plugin for monitoring WMI with Perl on Windows.

### Requirements

* Perl for Windows

    
### Usage

    call_perl=extra\Perl\bin\perl.exe -I extra\perl\lib -I extra\perl\site\lib $ARG1$

    check_wmi_range.pl 0.55 - checks one wmi object per instance against a threshold
    Options are:
      -c, --critical                  Enter the critical threshold
      -w, --warning                   Enter the warning threshold
      -C  --class                     Enter the WMI class
      -o  --object                    Enter the WMI object
      -e  --exclude                   Enter a regex to exclude instances
            to exclude more than one instance write -e "(instance1|instance2)"
      -i  -- include                  Enter a regex to include instances
            other Instances will be skipped
      -t  --no_Total                  hide the _Total instance
      -z  --zero                      hide zero values
      -s  --sleep                     run twice and sleep between the iterations <time to sleep>
      -I  --idle-contra-indicator     designed for proc_process. Check's if there's enough idle time left <threshold>
            It becomes critical if the real idle time of the last free core falls below threshold
      -n, --no-perf-data              no performance data
      -v  --verbose                   verbose mode
      -h, --help                      display this help and exit
          --usage                     display a short usage instruction
      -V, --version                   output version information and exit
      
    Requirements:
     A fully qualified wmi String consists of \Class\Instance\Object\Value
     This plugin uses perl and DBD::WMI to get values from multiple WMI Instances for each object.
     A working WMI counter is for example Win32_PerfFormattedData_Tcpip_NetworkInterface\<InstanceName>\BytesTotalPersec
     In most cases you want to exclude the "_Total" instance ( -t).
     
    Examples:
     Physical disktime:
      Class = Win32_PerfFormattedData_PerfDisk_PhysicalDisk
      Object = percentdisktime
      cmd: perl -w check_wmi_range.pl -w 10 -c 20 -C Win32_PerfFormattedData_PerfDisk_PhysicalDisk -o percentdisktime -t
     Interface Traffic:
      Class = Win32_PerfFormattedData_Tcpip_NetworkInterface
      Object = BytesTotalPersec
      cmd: perl -w check_wmi_range.pl -w 1000000 -c 1500000 -C Win32_PerfFormattedData_Tcpip_NetworkInterface -o BytesTotalPersec
     Process CPU usage:
      Class = Win32_PerfFormattedData_Perfproc_Process
      Object = PercentProcessorTime
      cmd: perl -w check_wmi_range.pl -w 10 -c 20 -C Win32_PerfFormattedData_Perfproc_Process -o PercentProcessorTime -t -e Idle -z -I 60




