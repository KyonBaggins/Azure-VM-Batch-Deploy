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
$networkSecurityGroupName = $_.NetworkSecurityGroup
#$publicIp = $_.PublicIp
$imageResourceGroup = $_.imageresourceGroup
$imageName = $_.imageName 

$nicName = $VMName + 'nic'

#创建公共IP资源
#$pip = new-Azpublicipaddress -name $vip -resourcegroupname $resourceGroup -location $location -allocationmethod dynamic -Force -ipaddressversion ipv4

#获取虚拟网络和子网
$vnet = Get-Azvirtualnetwork -name $vNetName -resourcegroupname $vNetResourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -virtualnetwork $vnet

#获取或创建网络安全组
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $networkSecurityGroupName -ErrorAction Ignore
if($nsg -eq $null)
{
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $networkSecurityGroupName
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

#创建虚拟机及磁盘配置
$vm = New-AzVMConfig -vmName $VMName -vmSize $VMSize -availabilitysetid $aset.id
$osDiskName = $VMName + 'osdisk'
if ($OSType -eq "linuximage") 
{
    $image = Get-AzImage -ImageName $imageName -ResourceGroupName $imageResourceGroup
    $vm = Set-AzVMSourceImage -VM $vm -Id $image.Id
    $vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $VMName -Credential $credential
    $vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType Premium_LRS -DiskSizeInGB 50 -CreateOption FromImage

}
elseif ($OSType -eq "winserver2008r2")
{
    $vm = Set-AzVMSourceImage -VM $vm -publishername "microsoftwindowsserver" -offer "windowsserver" -skus "2008-R2-SP1-zhcn" -version "latest"
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $credential
    $vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType Premium_LRS -DiskSizeInGB 120 -CreateOption FromImage
}
elseif ($OSType -eq "winserver2012r2")
{
    $vm = Set-AzVMSourceImage -VM $vm -publishername "microsoftwindowsserver" -offer "windowsserver" -skus "2012-R2-Datacenter-zhcn" -version "latest"
    $vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $credential
    $vm = Set-AzVMOSDisk -VM $vm -Name $osDiskName -StorageAccountType Premium_LRS -DiskSizeInGB 120 -CreateOption FromImage
}

#为虚拟机绑定网络接口
$vm = Add-AzVMNetworkinterface -VM $vm -ID $nic.id

#创建启动诊断配置
$dsa = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageName -ErrorAction Ignore
if($null -eq $dsa)
{
    $dsa = New-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageName -Location $location -SkuName Standard_LRS
}
$vm = Set-AzVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $resourceGroup -StorageAccountName $dsa.StorageAccountName

#部署虚拟机
New-AzVM -VM $vm -ResourceGroupName $resourceGroup -Location $location
Get-AzVM -ResourceGroupName $resourceGroup -Name $VMName
}