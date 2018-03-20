param (
    [bool]
    $Interactive = $true,
    [Security.SecureString]
    $LocalAdminPass,
    [string]
    $AadAdminUser,
    [Security.SecureString]
    $AadPassword,
    [string]
    $LocalAdminUsername = "Administrator",
    $Version
)

#region Fuctions
""

#endregion

#region Variables
$defaultLocalPath = "C:\AzureStackOnAzureVM"
$gitbranchconfig = Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ","
$gitbranchcode = $gitbranchconfig.branch.Trim()
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitbranchcode"

if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
{
    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
}
else
{
    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
}

$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork
$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$env:ComputerName)
$localCredValidated = $false


$asdkfileList = @("AzureStackDevelopmentKit.exe")
1..10 | ForEach-Object {$asdkfileList += "AzureStackDevelopmentKit-$_" + ".bin"}

$asdkURIRoot = "https://azurestack.azureedge.net/asdk"
$asdkDownloadPath = "D:"
$asdkExtractFolder = "Azure Stack Development Kit"
$asdkDownloaderFile = "AzureStackDownloader.exe"
$asdkDownloaderFullPath = Join-Path -Path $asdkDownloadPath -ChildPath $asdkDownloaderFile
$vhdxName = 'CloudBuilder.vhdx'
$vhdxFullPath = Join-Path -Path $asdkDownloadPath -ChildPath (Join-Path -Path $asdkExtractFolder -ChildPath $vhdxName)
$foldersToCopy = 'CloudDeployment', 'fwupdate', 'tools'
$destPath = 'C:\'

$versionArray = findLatestASDK -asdkURIRoot $asdkURIRoot -asdkfileList $asdkfileList

if ($interactive -eq $true)
{
    do {
    $localAdminPass = Read-Host -Prompt "Enter password for the user `'Administrator`'" -AsSecureString
    $localAdminPass1 = Read-Host -Prompt "Re-Enter password for the user `'Administrator`'" -AsSecureString
    $adminPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($localAdminPass))
    $adminpass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($localAdminPass1))
        if ($adminPass_text -cne $adminpass1_text)
        {
            Write-Verbose "Password does not match, re-enter password" -Verbose
        }
        else
        {
            if ($DS.ValidateCredentials($LocalAdminUsername, $adminPass_text) -eq $true)
            {
                $localCredValidated =  $true
                Write-Verbose "Password validated for user: $LocalAdminUsername" -Verbose
            }
            else
            {
                Write-Verbose "Password cannot be validated for user: $LocalAdminUsername" -Verbose
            }
        }

    } while ($localCredValidated -eq $false)

    do {
    $AadAdminUser = Read-Host -Prompt "`nMake sure the user has Global Administrator Permission on Azure Active Directory`nThe username format must be as follows:`n`n<Tenant Admin>@<Tenant name>.onmicrosoft.com`n`nEnter Azure AD user"

    } until ($AadAdminUser -match "(^[A-Z0-9._-]{1,64})@([A-Z0-9]{1,27}\.)onmicrosoft\.com$")

    do {
    $AadPassword = Read-Host -Prompt "Enter password for $AadAdminUser" -AsSecureString
    $AadPassword1 = Read-Host -Prompt "Re-Enter password for $AadAdminUser" -AsSecureString
    $aadPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AadPassword))
    $aadPass1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AadPassword1))
        if ($aadPass_text -cne $aadpass1_text)
        {
            Write-Output "Password does not match, re-enter password"
        }

    } until ($aadPass_text -ceq $aadpass1_text)
}

$aadAdmin  = $AadAdminUser.Split("@")[0]
$aadTenant = $AadAdminUser.Split("@")[1]

$localAdminCred = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $localAdminPass)
$aadcred = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

Write-Log @writeLogParams -Message "Available ASDK versions found"
Write-Log @writeLogParams -Message $versionArray

if ($version -eq $null)
{
    do {
        Clear-Host
        $i = 1
        Write-Host ""
        foreach ($v in $versionArray)
        {
            Write-Host "$($i)`. ASDK version: $v"
            $i++
        }
        Write-Host ""
        Write-Host -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline  -Object "Unless it is instructed, select only latest tested ASDK Version "
        Write-Host -ForegroundColor Green -BackgroundColor DarkGray -Object $gitbranchconfig.lastversiontested
        Write-Host ""
        $s = (Read-Host -Prompt "Select ASDK version to install")
        if ($s -match "\d")
        {
            $s = $s - 1
        }
    }
    until ($versionArray[$s] -in $versionArray)
    $version = $versionArray[$s]
}

if ($Interactive -eq $true)
{
    Clear-Host
    if ($version -gt $gitbranchconfig.lastversiontested)
    {
        Write-Host -Object ""
        Write-Host -BackgroundColor white -ForegroundColor Red -Object "This version of ASDK `($version`) is not tested on Azure VM."
        Write-Host -BackgroundColor white -ForegroundColor Red -Object "Unless you are an expert, select only latest tested version `($($gitbranchconfig.lastversiontested)`)"
    }
    Write-Host -Object ""
    Write-Host -Object "You are about to start Azure Stack Development Kit installation"
    Write-Host -Object ""
    Write-Host -Object "Check and make sure the following information are correct, setup will use"
    Write-Host -Object ""
    Write-Host -Object "LocalAdmin User: $LocalAdminUsername"
    Write-Host -Object "Azure AD Global Administrator user: $AadAdminUser"
    Write-Host -Object "Azure AD Tenant: $aadTenant"
    Write-Host -Object "ASDK Version to Install: $version"
    Write-Host -Object ""

    while ($true)
    {
        $key = Read-Host -Prompt "Press `'C'` to continue or `'Ctrl + C`' to cancel and startover"
        if ($key -eq "c")
        {
            break
        }
    }
}

#endregion

#Test if ASDK required folder already in the OS drive
if ((Test-Path -Path ($foldersToCopy | ForEach-Object {Join-Path -Path $destPath -ChildPath $_})) -contains $false)
{
    #Test if ASDK CloudBuilder.vhdx file is present if not download ASDK files
    if (-not (Test-Path -Path $vhdxFullPath))
    {
        $downloadList = testASDKFilesPresence -asdkURIRoot $asdkURIRoot -version $version -asdkfileList $asdkfileList
        $AsdkFiles = @()
        foreach ($AsdkFile in Split-Path $downloadList -Leaf)
        {
            $AsdkFiles += Join-Path -Path $asdkDownloadPath -ChildPath $AsdkFile
        }

        $testPathResult = (Test-Path $AsdkFiles)
        if ($testPathResult -contains $false)
        {
            Write-Log @writeLogParams -Message "Download process for ASDK $version started"
            
            $downloadList | ForEach-Object {Start-BitsTransfer -Source $_ -DisplayName $_ -Destination $asdkDownloadPath}
        }
        else
        {
            Write-Log @writeLogParams -Message "Local ASDK setup files found. Local files will be used for ASDK setup"
        }

        $i = 0

        while ($testPathResult -contains $false)
        {
            if ($i%45 -eq 0) 
            {
                Write-Log @writeLogParams -Message "Waiting for Azure Stack Development kit files on `'$asdkDownloadPath`'"
            }
    
            Start-Sleep -Seconds 1
            $testPathResult = (Test-Path $AsdkFiles)
            $i++ 
        }
        
        Write-Log @writeLogParams -Message "Extracting Azure Stack Development kit files"
    
        $f = $AsdkFiles[0]
        $o = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
        Start-Process -FilePath $f -ArgumentList "/dir=`"$o`"", "/SILENT", "/NOCANCEL" -Wait
    }
    #if ASDK CloudBuilder.vhdx file present, mount and copy files from
    if (Test-Path -Path $vhdxFullPath)
    {
        Write-Log @writeLogParams -Message "About to Start Copying ASDK files to C:\"
        Write-Log @writeLogParams -Message "Mounting cloudbuilder.vhdx"
        try {
            $driveLetter = Mount-VHD -Path $vhdxFullPath -Passthru | Get-Disk | Get-Partition | Where-Object size -gt 500MB | Select-Object -ExpandProperty driveletter
            Write-Log @writeLogParams -Message "The drive is now mounted as $driveLetter`:"
        }
        catch {
            Write-Log @writeLogParams -Message "an error occured while mounting cloudbuilder.vhdx file"
            Write-Log @writeLogParams -Message $error[0].Exception
            throw "an error occured while mounting cloudbuilder.vhdxf file"
        }
        Write-Log @writeLogParams -Message "The drive is now mounted as $driveLetter`:"
        foreach ($folder in $foldersToCopy)
        {
            Write-Log @writeLogParams -Message "Copying folder $folder to $destPath"
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination $destPath -Recurse -Force
            Write-Log @writeLogParams -Message "$folder done..."
        }
        Dismount-VHD -Path $vhdxFullPath       
    }

}

Write-Log @writeLogParams -Message "Running BootstrapAzureStackDeployment"
Set-Location C:\CloudDeployment\Setup
.\BootstrapAzureStackDeployment.ps1
Write-Log @writeLogParams -Message "Tweaking some files to run ASDK on Azure VM"

Write-Log @writeLogParams -Message "Applying first workaround to tackle bare metal detection"
$baremetalFilePath = "C:\CloudDeployment\Roles\PhysicalMachines\Tests\BareMetal.Tests.ps1"
$baremetalFile = Get-Content -Path $baremetalFilePath
$baremetalFile = $baremetalFile.Replace('$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'')','$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode') 
Set-Content -Value $baremetalFile -Path $baremetalFilePath -Force 

if ($version -ge 1802)
{
    Write-Log @writeLogParams -Message "Applying second workaround since this version is 1802 or higher"
    $HelpersFilePath = "C:\CloudDeployment\Common\Helpers.psm1" 
    $HelpersFile = Get-Content -Path $HelpersFilePath
    $HelpersFile = $HelpersFile.Replace('C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease','C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease -ExcludeVersion') 
    Set-Content -Value $HelpersFile -Path $HelpersFilePath -Force 
}

#Download Azure Stack Development Kit Companion Service script
DownloadWithRetry -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -DownloadLocation "$defaultLocalPath\ASDKCompanionService.ps1"
#Invoke-WebRequest -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -OutFile "$defaultLocalPath\ASDKCompanionService.ps1"
if (Get-ScheduledJob -name "ASDK Installer Companion Service" -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name "ASDK Installer Companion Service" | Unregister-ScheduledJob -Force
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "$defaultLocalPath\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

#Download Azure Stack Register script
DownloadWithRetry -Uri "$gitbranch/scripts/Register-AzureStackLAB.ps1" -DownloadLocation "$defaultLocalPath\Register-AzureStackLAB.ps1"
#Invoke-WebRequest -Uri "$gitbranch/scripts/Register-AzureStackLAB.ps1" -OutFile "$defaultLocalPath\Register-AzureStackLAB.ps1"

#Create all user desktop shotcuts for Azure Stack Admin and Tenant portal
$Shell = New-Object -ComObject ("WScript.Shell")
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Stack Admin Portal.url")
$Favorite.TargetPath = "https://adminportal.local.azurestack.external";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Stack Tenant Portal.url")
$Favorite.TargetPath = "https://portal.local.azurestack.external";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Azure Portal.url")
$Favorite.TargetPath = "https://portal.azure.com";
$Favorite.Save()
$Favorite = $Shell.CreateShortcut($env:ALLUSERSPROFILE + "\Desktop\Service Fabric Explorer.url")
$Favorite.TargetPath = "http://azs-xrp01:19007";
$Favorite.Save()

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
Write-Log @writeLogParams -Message "Time server is now $timeServer"

$InstallAzSPOCParams = @{
    AdminPassword = $localAdminPass
    InfraAzureDirectoryTenantAdminCredential = $aadcred 
    InfraAzureDirectoryTenantName = $aadTenant
    NATIPv4Subnet = "192.168.137.0/28"
    NATIPv4Address = "192.168.137.11"
    NATIPv4DefaultGateway = "192.168.137.1"
    TimeServer = $timeServer
    DNSForwarder = "8.8.8.8"
}

#Azure Stack PoC installer setup
Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams
