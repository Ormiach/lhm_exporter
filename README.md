# Table of contents
* [General Info](#general-info)
* [Setup](#setup)
* [Usage](#usage)
* [Grafana](#grafana)
* [Compatibility](#compatibility)
* [Improve Script](#imrpove-script)

# General info
"lhm_exporter" collects stats via "Libre Hardware Monitor" and creates a prometheus readable metric file.


# Setup

### Download lhm_exporter.exe
Download lhm_exporter.exe from here: 
* https://github.com/Ormiach/lhm_exporter

### Download & Configure OpenHardwareMonitor
For lhm_exporter to work, it needs the tool "Libre Hardware Monitor", which you can download from here: 
* https://github.com/LibreHardwareMonitor/LibreHardwareMonitor

Put all the files into a folder called "Libre Hardware Monitor" next to the lhm_exporter.exe.
Start once and change the following options in "Libre Hardware Monitor": 
* Options -> Enable first 4 Options

### Download windows_exporter.msi
Prometheus collect the data create via windows_exporter. Download the windows_exporter here and install it: 
* https://github.com/prometheus-community/windows_exporter
You need to start windows_exporter with at least the following collectors enabled: 'textfile'

### Download nssm.exe
If you like to install the lhm_exporter as a service you can do this with "nssm". You get the exe here: 
* https://nssm.cc/

### Register lhm_exporter as a service
```
.\nssm.exe install lhm_exporter lhm_exporter.exe
.\nssm.exe set lhm_exporter Description "Libre Hardware Monitor Exporter For Prometheus"
.\nssm set lhm_exporter AppDirectory <path to lhm_exporter.exe-directory>
```

### Remove lhm_exporter service
```
.\nssm.exe remove lhm_exporter
```

# Grafana
Use the file "grafana_dashboard.json" to import the lhm_exporter-dashboard into your Grafana instance.

![Alt text](https://github.com/Ormiach/lhm_exporter/blob/main/images/grafana_cpu.png?raw=true "Grafana CPU")
![Alt text](https://github.com/Ormiach/lhm_exporter/blob/main/images/grafana_gpu.png?raw=true "Grafana GPU")
![Alt text](https://github.com/Ormiach/lhm_exporter/blob/main/images/grafana_motherboard.png?raw=true "Grafana Motherboard")
![Alt text](https://github.com/Ormiach/lhm_exporter/blob/main/images/grafana_network.png?raw=true "Grafana Network")
![Alt text](https://github.com/Ormiach/lhm_exporter/blob/main/images/grafana_disk.png?raw=true "Grafana Disk")

# Compatibility

Tested with the following hardware. Other hardware may needs adaptation.

* Processor
	* AMD Ryzen 9 5900X
	* AMD Ryzen 7 9800X3D
* GPU
	* NVIDIA GeForce RTX 3080
	* AMD Radeon RX 6800 XT

# Improve Script

### Build a new .exe
```
PS>Install-Module ps2exe
PS>Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
PS>Invoke-ps2exe .\lhm_exporter.ps1 .\lhm_exporter.exe
PS>Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser
```