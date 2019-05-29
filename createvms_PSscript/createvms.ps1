#导入csv文件
Import-Csv -Path '.\vmconfig.csv' |

#依次获取csv文件中定义的参数
ForEach-Object{

#必要参数
$resourceGroup = $_.ResourceGroup
$vNetResourceGroup = $_.vNetResourceGroup
$vNetName = $_.vNetName
$subnetName = $_.subnet
$privateIp = $_.PrivateIp
$VMName = $_.VMName
$OSType = $_.VMOS
$VMSize = $_.VMSize
$location = $_.Location
$user = $_.UserName
$password = ConvertTo-SecureString -string $_.Password -AsPlainText -Force
$credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $password

#可选参数
$storageName = $_.StorageAccountName
$availabilitySetName = $_.availabilitySet
$networkSecurityGroup = $_.NetworkSecurityGroup
#$publicIp = $_.PublicIp
#$imageResourceGroup = $_.imageresourceGroup
#$imageName = $_.imageName 

$nicName = $VMName + 'nic'

#创建公共IP资源
#$pip = new-Azpublicipaddress -name $vip -resourcegroupname $resourceGroup -location $location -allocationmethod dynamic -Force -ipaddressversion ipv4

#获取虚拟网络和子网
$vnet = Get-Azvirtualnetwork -name $vNetName -resourcegroupname $vNetResourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -virtualnetwork $vnet

#获取或创建网络安全组
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $networkSecurityGroup -ErrorAction Ignore
if($nsg -eq $null)
{
    $nsgname = $VMName + 'nsg'
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $nsgname
}

#创建网络接口
#$nic = new-Aznetworkinterface -name $nicName -ResourceGroupName $resourceGroup -location $location -subnet $subnet -Force -Publicipaddress $pip -PrivateIpAddress $privateIp -NetworkSecurityGroup $nsg
$nic = new-Aznetworkinterface -name $nicName -ResourceGroupName $resourceGroup -location $location -subnet $subnet -Force -PrivateIpAddress $privateIp -NetworkSecurityGroup $nsg

#获取或创建可用性集
$aset = Get-AzAvailabilityset -ResourceGroupName $resourceGroup -Name $availabilitySetName -ErrorAction Ignore
if($aset -eq $null)
{
    $aset = New-AzAvailabilityset -ResourceGroupName $resourceGroup -Name $availabilitySetName -Location $location -sku aligned -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 3
}

#获取镜像文件信息
#$image = Get-AzImage -ImageName $imageName -ResourceGroupName $imageResourceGroup

#创建虚拟机配置
$vm = New-AzVMConfig -vmName $VMName -vmSize $VMSize -availabilitysetid $aset.id
if($OSType -eq "windows")
{
    #Windows系统镜像配置
    $vm = Set-AzVMSourceImage -VM $vm -publishername microsoftwindowsserver -offer windowsserver -skus 2012-r2-datacenter -version "latest"
}
elseif($OSType -eq "linux")
{
    #Linux系统镜像配置
    $vm = Set-AzVMSourceImage -VM $vm -PublisherName "openlogic" -Offer "centos" -Skus "7.5" -version "latest"
}

#$vm = Set-AzVMSourceImage -VM $vm -Id $image.Id

$computerName = $VMName
if($OSType -eq "windows")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $computerName -Credential $credential
}
elseif($OSType -eq "linux")
{
    $vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $computerName -Credential $credential
}

$vm = Add-AzVMNetworkinterface -VM $vm -ID $nic.id

#创建系统磁盘配置
#$storageaccount = get-Azstorageaccount -resourcegroupname $resourceGroup -accountname $storagename
#$disk = Get-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName
#$osdiskuri = $storageacc.primaryendpoints.blob.tostring()+"vhds/"+$osDiskName+".vhd"
$osDiskName = $VMName + 'osdisk'
if($OSType -eq "windows")
{
    Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType Premium_LRS -DiskSizeInGB 128 -CreateOption FromImage
}
elseif($OSType -eq "linux")
{
    Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType Premium_LRS -DiskSizeInGB 30 -CreateOption FromImage
}

#创建诊断配置
$dsa = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageName -ErrorAction Ignore
if($dsa -eq $null)
{
    $dsa = New-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageName -Location $location -SkuName Standard_LRS
}
Set-AzVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $resourceGroup -StorageAccountName $dsa.StorageAccountName

#创建虚拟机
New-AzVM -VM $vm -resourcegroupname $resourceGroup -location $location
}