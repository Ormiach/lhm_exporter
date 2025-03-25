<#    
    .SYNOPSIS
    Collects stats from the tool "Libre Hardware Monitore" and creates a prometheus ready metric file

    .DESCRIPTION
        Scripts starts LibreHardwareMonitor by itself, when the LibreHardwareMonitor-files are located in a folder named "LibreHardwareMonitor" next to the powershell script (if the lhm_exporter was not started as a service at least).
		When you run it the first time, check if all metrics are found - use parameter "-check" for that. If the numbers differ from each other, there is a problem in the script =(
		
		# Configure LibreHardwareMonitor
			Options -> Enable first 4 Options
		
		# Register as a service
			nssm install <service name> lhm_exporter.exe
		# Remove service
			nssm remove <service name>
			
		# Build a new .exe
		    PS>Install-Module ps2exe
		    PS>Invoke-ps2exe .\lhm_exporter.ps1 .\lhm_exporter.exe
  
    .COMPONENT
        Needs LibreHardwareMonitoring Tool and windows_exporter (with textfile_inputs enabled)
		
	.INPUTS
		None
		
	.OUTPUTS
		Creates a lhm_exporter.prom file with metrics ready to collect by a prometheus

    .PARAMETER promfolder
        Define Prometheus exporter folder path, if not default path (C:\Program Files\windows_exporter\textfile_inputs)

    .PARAMETER check
        Counts the number of found LibreHardwareMonitor parameter and compares it with the created prometheus metrics. If they are not the same, the scripts needs adaptation.

    .EXAMPLE
        PS>./lhm_exporter.ps1

    .EXAMPLE
        PS>./lhm_exporter.ps1 -check

    .EXAMPLE
        PS>./lhm_exporter.ps1 -promfolder "C:\Program Files\windows_exporter\textfile_inputs"

    .NOTES
        Version:        1.1
        Author:         Ormiach
        Creation Date:  2025

    .LINK
		*) lhm_exporter: https://github.com/Ormiach/lhm_exporter
		*) windows_exporter.msi: https://github.com/prometheus-community/windows_exporter
		*) Open Hardware Monitoring:  https://LibreHardwareMonitor.org/downloads/
		*) Nssm: https://nssm.cc/
		
		
#>
#####################################################################################################



########################
# Parameter
########################
param(
    [Parameter(Mandatory=$False)][string]$promfolder="C:\Program Files\windows_exporter\textfile_inputs",
    [Parameter(Mandatory=$False)][switch]$check
)

########################
# Do some checks
########################
# Is the script running with administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 
	Write-Host "Needs administrator privileges to run  -> Exit"
	break
}

# Check if Prometheus-exporter folder exists
if (-Not (Test-Path $promfolder) ) { 
    throw "Folder does not exists: $promfolder -> Exit"
}

# Check if LibreHardwareMonitor ist running
if ( -Not (Get-Process LibreHardwareMonitor -ErrorAction SilentlyContinue)) {  
    Start-Process -FilePath "./LibreHardwareMonitor/LibreHardwareMonitor.exe" -WindowStyle Hidden
    Start-Sleep -s 2
    if ( -Not (Get-Process LibreHardwareMonitor -ErrorAction SilentlyContinue)) {
        throw "LibreHardwareMonitor not running -> EXIT"
    }
}

########################
# Define Filename
########################
$filename = "lhm_exporter.prom"
$file = $promfolder+"/"+$filename


while($true)
{
	########################
	# Get LibraHardwareMonitor informations
	########################
   
    # Get sensor information
	$lhm_query = get-wmiobject -namespace "root/LibreHardwareMonitor" -Class Sensor #| Select-Object #-Property Name,__CLASS,Parent,w,SensorType,Identifier,Index,Value
	$lhm_query = $lhm_query | Sort-Object -Property Name,Identifier -Unique
	$promhash  = @{}
	$promhash_counter = 0
	$checkitems = 0
	$checkmetrics = 0


	########################
	# Open promfile
	########################
	New-Item -Path "." -Name $filename -ItemType File -ErrorAction stop -Force | Out-Null

	foreach($element in $lhm_query)
	{
		$need_calc = 1
		$metricname = ""
		$metricname_name = ""
		$metricname_end = ""
		$addparent = ""
		$checkitems = $checkitems + 1
		
        # Get parent information
        $match = "Identifier='"+($element.Parent)+"'"
        $parent = get-wmiobject -namespace "root/LibreHardwareMonitor" -Class Hardware -filter "$match" 
		
        ########################
        # Make Metrics Beautiful 
        ########################
        # Add parent name to metric, for better sorting
        if ($parent.HardwareType.ToLower()) {
            if ($parent.HardwareType.ToLower() -Match "superio") { $parent.HardwareType = "Motherboard" }
            elseif ($parent.HardwareType.ToLower() -Match "storage") { $parent.HardwareType = "Disk" }
            # Match gpuamd and others as gpu
            elseif ($parent.HardwareType.ToLower() -Match "gpu") { $parent.HardwareType = "Gpu" }
            $addparent = $parent.HardwareType.ToLower() + "_" 
        }
        
        # Replace some stuff
        $metricname_name = $element.Name.ToLower().Replace(' ','_')
        $metricname_name = $metricname_name -Replace '_#.*',''
        $metricname_name = $metricname_name -Replace '_\d+',''
        
        ######
        # Adapt metrics by SensorType
        # Units: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/blob/master/LibreHardwareMonitorLib/Hardware/ISensor.cs
        ######
        $metricname_name = $element.SensorType.ToLower()
		if ( $element.SensorType -Eq "Clock" )   { $metricname_end = "_mhz" }
		if ( $element.SensorType -Eq "Control" ) { $metricname_end = "_percent" }
		if ( $element.SensorType -Eq "Current" ) { $metricname_end = "_amperes" }
		if ( $element.SensorType -Eq "Data" ) {
            # Always in GB
            $metricname_end = "_bytes" 
            $need_calc = 1024*1024*1024 }
		if ( $element.SensorType -Eq "Factor" )  { $metricname_end = "_total" }
		if ( $element.SensorType -Eq "Fan" )     { $metricname_end = "_rpm" }
		if ( $element.SensorType -Eq "Level" )   { $metricname_end = "_percent" }
		if ( $element.SensorType -Eq "Load" )    { $metricname_end = "_percent" }
		if ( $element.SensorType -Eq "Power" )   { $metricname_end = "_watts"  }
        if ($element.SensorType -Eq "Smalldata") {
            # Seems to be in MB
            $metricname_name = "data"
            $metricname_end = "_bytes"
            $need_calc = 1024*1024 }
		if ( $element.SensorType -Eq "Throughput" ) {
            # Seems to always be in Bytes/s
			$metricname_end = "_bytes_per_seconds" }
		if ( $element.SensorType -Eq "Voltage" ) { $metricname_end = "_volts" }
		if ( $element.SensorType -Eq "Temperature" ) { $metricname_end = "_celsius" }

		
		# Calculate units to bytes
		if ($metricname_end -Match "bytes" -And $need_calc -Eq 1) { $need_calc = 1024 }
		$metricname = "lhm_"+$addparent+$metricname_name+$metricname_end

		######
		# Write metric to prometheus-hash
		######
		if ($promhash.$metricname.Count -Eq 0 ) { 
			$promhash[$metricname] = @{} 
			$promhash[$metricname]["metric_help"] = $metricname+" "+ $metricname
			$promhash[$metricname]["metric_type"] = $metricname+" "+ "gauge"
		}
		$promhash[$metricname][$promhash_counter] = @{} 
		$promhash[$metricname][$promhash_counter]['parent_identifier'] = $element.Parent
		$promhash[$metricname][$promhash_counter]['parent_name'] = $parent.Name
		$promhash[$metricname][$promhash_counter]['identifier'] = $element.Identifier
		$promhash[$metricname][$promhash_counter]['device'] = $parent.HardwareType
		$promhash[$metricname][$promhash_counter]['name'] = $element.Name
		$promhash[$metricname][$promhash_counter]['index'] = $element.Index
		$promhash[$metricname][$promhash_counter]['type'] = $element.SensorType
		$promhash[$metricname][$promhash_counter]['value'] = ($need_calc * $element.Value)
		$promhash_counter = $promhash_counter +1
	}

	##########
	# Create prometheus file output
	##########
	$last_metricname = ""
	foreach($metricname in $promhash.keys) {
		if ($last_metricname -Ne $metricname) {
			Add-Content $filename ("# HELP "+$promhash[$metricname].metric_help)
			Add-Content $filename ("# TYPE "+$promhash[$metricname].metric_type)
		}
		foreach($metricnumber in $promhash[$metricname].keys) {
			$metric = $metricname+"{"
			if ($promhash[$metricname][$metricnumber]['name'] -Match "\w+") {
				$checkmetrics = $checkmetrics + 1
				foreach ($key in $promhash[$metricname][$metricnumber].keys) { 
					if ($key -Eq "value" -Or $promhash[$metricname][$metricnumber][$key] -Eq "") { continue }
					$metric = $metric+$key+'="'+$promhash[$metricname][$metricnumber][$key]+'",'
				}
				$metric = $metric.Substring(0,$metric.Length-1)
				Add-Content $filename ( $metric+"} "+$promhash[$metricname][$metricnumber]['value'] )
			}
		}
        Add-Content $filename ("")
	}

	# Move file to prometheus folder
	Move-Item -Path $filename -Destination $file -force

	if ($check) { 
		Write-Host ("LibreHardwareMonitor-Items found: "+$checkitems)
		Write-Host ("Prometheus Metrics created:      "+$checkmetrics)	
        Write-Host("Sleeping 25s")
	}

	Start-Sleep -s 25
}
