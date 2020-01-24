#Create Storage account and SAS token
#Create VM E8 Run following script to download, extract, convert and upload vhd file to SA

Install-WindowsFeature Hyper-V -IncludeManagementTools -Restart

$defaultLocalPath = "C:\AzureStackOnAzureVM"
$versionContainerName = "1910-58"
$version = $versionContainerName.split("-")[0]

New-Item -Path $defaultLocalPath -ItemType Directory
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/scripts/ASDKHelperModule.psm1" -OutFile "$defaultLocalPath\ASDKHelperModule.psm1"
Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -Force
$asdkDownloadPath = "d:\"
$asdkExtractFolder = "Azure Stack Development Kit"
$d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
$vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"
$asdkFiles = ASDKDownloader -Destination $asdkDownloadPath -Version $versionContainerName

$f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
ExtractASDK -File $f -Destination $d

$diskPath = "$d\asdk$version.vhdx"
$targetDiskPath = "$d\asdk$version.vhd"
Copy-Item -Path $vhdxFullPath -Destination $diskPath -Force
$m = Mount-DiskImage $diskPath -Passthru
$size = (Get-PartitionSupportedSize -DiskNumber $m.number -PartitionNumber 2)
$size = ([math]::Ceiling($($size.SizeMin / 1gb)) + 3) * 1gb
Resize-Partition -DiskNumber $m.number -PartitionNumber 2 -Size $size
Dismount-DiskImage $m.ImagePath
Resize-Vhd -ToMinimumSize -Path $m.ImagePath
Convert-VHD -Path $m.ImagePath -DestinationPath $targetDiskPath -VHDType Fixed

$vhd = "ASDK$version.vhd"
$azcopyDestPath = "D:\azcopy.zip"
DownloadWithRetry -Uri https://aka.ms/downloadazcopy-v10-windows -DownloadLocation $azcopyDestPath
Unblock-File -Path $azcopyDestPath
Expand-Archive -Path $azcopyDestPath -DestinationPath D:\azcopy
cd D:\azcopy\*

$env:AZCOPY_CRED_TYPE = "Anonymous";

./azcopy.exe copy "$d\$vhd" "https://<Azure Blob Storage Prefix>.blob.core.windows.net/template-vhd/asdk1910.vhd?<SAS token>" --overwrite=prompt --follow-symlinks --recursive --from-to=LocalBlob --blob-type=PageBlob --put-md5;
$env:AZCOPY_CRED_TYPE = "";