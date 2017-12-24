#region Fuctions
function Print-Output ($message)
{
    $t = get-date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Output "$message - $t"
}

function FindReplace-ZipFileContent ($ZipFileFullPath, $FilenameFullPath, $ItemToFind, $ReplaceWith)
{
        $ZipFileFullPath = Resolve-Path $ZipFileFullPath
        $file = $FilenameFullPath.split("/")[-1]
        $tempFileFullPath = Join-Path -Path $env:temp -ChildPath $file
        Add-Type -Assembly System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::Open($ZipFileFullPath,"update")
        $zip.Entries | where {$_.Name -eq $file} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $tempFileFullPath, $true)}
        (Get-Content $tempFileFullPath) -replace "$ItemToFind", "$ReplaceWith" | Out-File $tempFileFullPath
        $fileName = [System.IO.Path]::GetFileName($file)
        ($zip.Entries | where {$_.Name -eq $file}).delete()
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$tempFileFullPath,$FilenameFullPath,"Optimal") | Out-Null
        $zip.Dispose()
}

function findLatestASDK ($version, $asdkURIRoot, $asdkFileList)
{
    try
    {
        $r = (Invoke-WebRequest -Uri $($asdkURIRoot + $version + '/' + $asdkFileList[0]) -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue).StatusCode
        if ($r -eq 200)
        {
            $version
        }
    }
    catch [System.Net.WebException],[System.Exception]
    {
        $i++
        $version = (Get-Date (Get-Date).AddMonths(-$i) -Format "yyMM")
        findLatestASDK -version $version -asdkURIRoot $asdkURIRoot -asdkFileList $asdkFileList
    }
}
#endregion

#region Variables
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development"
$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork

do {
$adminPass = Read-Host -Prompt "Enter for Administrator Password" -AsSecureString
$adminPass1 = Read-Host -Prompt "Re-Enter for Administrator Password" -AsSecureString
$adminPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass))
$adminpass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass1))
    if ($adminPass_text -cne $adminpass1_text)
    {
        Write-Output "Password does not match, re-enter password"
    }

} until ($adminPass_text -ceq $adminpass1_text)

do {
$aadAdminUser = Read-Host -Prompt "`nMake sure the user will have Global Administrator Permission on Azure Active Directory`nThe username format must be as follows: <Tenant Admin>@<Tenant name>.onmicrosoft.com`n`nEnter Azure AD user"

} until ($aadAdminUser -match "(^[A-Z0-9._-]{1,64})@([A-Z0-9]{1,27}\.)onmicrosoft\.com$")

$aadAdmin  = $aadAdminUser.Split("@")[0]
$aadTenant = $aadAdminUser.Split("@")[1]

do {
$aadPass = Read-Host -Prompt "Enter password for $aadAdminUser" -AsSecureString
$aadPass1 = Read-Host -Prompt "Re-Enter password for $aadAdminUser" -AsSecureString
$aadPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($aadPass))
$aadPass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($aadPass1))
    if ($aadPass_text -cne $aadpass1_text)
    {
        Write-Output "Password does not match, re-enter password"
    }

} until ($aadPass_text -ceq $aadpass1_text)

$localAdminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $adminPass)
$aadcred = New-Object System.Management.Automation.PSCredential ($aadAdminUser, $aadPass)
$timeServiceProvider = @("pool.ntp.org") | Get-Random
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random

$asdkFileList = @("AzureStackDevelopmentKit.exe","AzureStackDevelopmentKit-1.bin","AzureStackDevelopmentKit-2.bin","AzureStackDevelopmentKit-3.bin","AzureStackDevelopmentKit-4.bin","AzureStackDevelopmentKit-5.bin","AzureStackDevelopmentKit-6.bin")
$asdkURIRoot = "https://azurestack.azureedge.net/asdk"
$asdkDownloadPath = "D:"
$asdkExtractFolder = "Azure Stack Development Kit"
$asdkDownloaderFile = "AzureStackDownloader.exe"
$asdkDownloaderFullPath = Join-Path -Path $asdkDownloadPath -ChildPath $asdkDownloaderFile
$vhdxName = 'CloudBuilder.vhdx'
$vhdxFullPath = Join-Path -Path $asdkDownloadPath -ChildPath (Join-Path -Path $asdkExtractFolder -ChildPath $vhdxName)
$foldersToCopy = 'CloudDeployment', 'fwupdate', 'tools'
$destPath = 'C:\'
$InstallAzSPOCParams = @{
    AdminPassword = $adminpass
    InfraAzureDirectoryTenantAdminCredential = $aadcred 
    InfraAzureDirectoryTenantName = $aadTenant
    NATIPv4Subnet = "192.168.137.0/28"
    NATIPv4Address = "192.168.137.11"
    NATIPv4DefaultGateway = "192.168.137.1"
    TimeServer = $timeServer
    DNSForwarder = "8.8.8.8"
}

#endregion

#Test if ASDK required folder already in the OS drive
if ((Test-Path -Path ($foldersToCopy | ForEach-Object {Join-Path -Path $destPath -ChildPath $_})) -contains $false)
{
    #Test if ASDK CloudBuilder.vhdx file is present if not download ASDK files
    if (-not (Test-Path -Path $vhdxFullPath))
    {
        $AsdkFiles = @()

        foreach ($AsdkFile in $ASDKFileList)
        {
            $AsdkFiles += Join-Path -Path $asdkDownloadPath -ChildPath $AsdkFile
        }

        $testPathResult = (Test-Path $AsdkFiles)
        if ($testPathResult -contains $false)
        {
            $version = findLatestASDK -asdkURIRoot $asdkURIRoot -asdkFileList $asdkFileList
            Print-Output -message "Start downloading ASDK$version"
            $asdkFileList | ForEach-Object {Start-BitsTransfer -Source $($asdkURIRoot + $version + '/' + $_) -Destination $(Join-Path -Path $asdkDownloadPath -ChildPath $_)}
        }

        $i = 0

        while ($testPathResult -contains $false)
        {
            if ($i%45 -eq 0) 
            {
                Print-Output -Message "Waiting for Azure Stack Development kit files on `'$asdkDownloadPath`'"
            }
    
            Start-Sleep -Seconds 1
            $testPathResult = (Test-Path $AsdkFiles)
            $i++ 
        }
        
        Print-Output -message "Extracting Azure Stack Development kit files"
    
        $f = Join-Path -Path $asdkDownloadPath -ChildPath "AzureStackDevelopmentKit.exe"
        $o = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
        
        Start-Process -FilePath $f -ArgumentList "/dir=`"$o`"", "/silent" -Wait
    }
    #if ASDK CloudBuilder.vhdx file present, mount and copy files from
    if (Test-Path -Path $vhdxFullPath)
    {
        Print-Output -Message "About to Start Copying ASDK files to C:\"
        $driveLetter = Mount-VHD -Path $vhdxFullPath -Passthru | Get-Disk | Get-Partition | ? size -gt 500MB | Select-Object -ExpandProperty driveletter
        foreach ($folder in $foldersToCopy)
        {
            Print-Output -message "Copying folder $folder to $destPath"
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination $destPath -Recurse -Force
            Print-Output -message "$folder done..."
        }
        Dismount-VHD -Path $vhdxFullPath       
    }

}


Print-Output -Message "Tweaking some nupkg files to run ASDK on Azure VM"
$zipFile1 = 'C:\CloudDeployment\NuGetStore\Microsoft.AzureStack.Solution.Deploy.CloudDeployment.*.nupkg'
if (Test-Path $zipFile1)
{
    #FindReplace-ZipFileContent -ZipFileFullPath $zipFile1 -FilenameFullPath 'content/Roles/PhysicalMachines/Tests/BareMetal.Tests.ps1' -ItemToFind '-not \$isVirtualizedDeployment' -ReplaceWith '$isVirtualizedDeployment'
    FindReplace-ZipFileContent -ZipFileFullPath $zipFile1 -FilenameFullPath 'content/Roles/PhysicalMachines/Tests/BareMetal.Tests.ps1' -ItemToFind '\$isvirtualizedDeployment = \(\$Parameters.OEMModel -eq ''Hyper-V''\)' -ReplaceWith '$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode'
}
else
{
    Write-Error "$zipfile1 cannot be found"
}

#Download Azure Stack DEvelopment Kit Companion Service script
Invoke-WebRequest -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -OutFile "C:\AzureStackonAzureVM\ASDKCompanionService.ps1"
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "c:\AzureStackonAzureVM\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

#Download Azure Stack Register script
Invoke-WebRequest -Uri "$gitbranch/scripts/Register-AzureStackLAB.ps1" -OutFile "C:\AzureStackonAzureVM\Register-AzureStackLAB.ps1"

Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams