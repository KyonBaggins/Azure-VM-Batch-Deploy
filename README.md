# Azure-VM-Batch-Deploy
通过PowerShell脚本快速批量部署Azure虚拟机
虚拟机参数配置在vmconfig.csv中，通过createvms.ps1逐行读取并用于部署。
vmconfig.csv中可配置虚拟机及大部分相关资源参数，包括虚拟网络、网络安全组、可用性集等。
亦可指定部署虚拟机所用的操作系统类型，目前针对Windows硬编码为WindowsServer 2012 Datacenter，针对Linux硬编码为CentOS 7.5。
