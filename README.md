# Azure-VM-Batch-Deploy

通过PowerShell脚本快速批量部署Azure虚拟机。

虚拟机参数配置在vmconfig.csv中，通过createvms.ps1逐行读取并用于部署。

vmconfig.csv中可配置虚拟机及大部分相关资源参数，包括虚拟网络、网络安全组、可用性集等。

使用的PowerShell Azure Module为Az。
