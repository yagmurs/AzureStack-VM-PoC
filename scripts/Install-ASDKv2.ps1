[CmdletBinding()]

param (
    [Security.SecureString]
    $LocalAdminPass,

    [string]
    $AADTenant,

    [string]
    $LocalAdminUsername = "Administrator",

    [Parameter(Mandatory=$true,
    HelpMessage="Specify deployment type `'AAD`' or `'ADFS`'")]
    [ValidateSet("AAD", "ADFS")]
    [string]
    $DeploymentType,

    [switch]
    $DownloadASDK,

    [string]
    $version
)

#region Variables
$VerbosePreference = "Continue"
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

Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$env:ComputerName)
$localCredValidated = $false

if (!($LocalAdminPass))
{
    do {
    $localAdminPass = Read-Host -Prompt "Enter password for the user `'Administrator`'" -AsSecureString
    $adminPass_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($localAdminPass))
        if ($DS.ValidateCredentials($LocalAdminUsername, $adminPass_text) -eq $true)
        {
            $localCredValidated =  $true
            Write-Verbose "Password validated for user: $LocalAdminUsername" 
        }
        else
        {
            Write-Error "Password cannot be validated for user: $LocalAdminUsername"
        }

    } while ($localCredValidated -eq $false)
}

$localAdminCred = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $localAdminPass)

if ($DeploymentType -eq "AAD")
{
    if (!($AADTenant))
    {
        $AADTenant = Read-Host -Prompt "Enter AAD Tenant Directory Name"
    }
}

$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork
$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}


#endregion

#Download Azure Stack Development Kit Companion Service script
$ASDKCompanionScriptName = "ASDKCompanionService.ps1"
if (!(Test-Path "$defaultLocalPath\$ASDKCompanionScriptName"))
{
    DownloadWithRetry -Uri "$gitbranch/scripts/$ASDKCompanionScriptName" -DownloadLocation "$defaultLocalPath\$ASDKCompanionScriptName"
}

#Download and extract ASDK files
if ($DownloadASDK) 
{
    #Download ASDK files (BINs and EXE)
    Write-Log @writeLogParams -Message "Finding available ASDK versions"

    $asdkDownloadPath = "d:\"
    $asdkExtractFolder = "Azure Stack Development Kit"
    if ($null -eq $version -or $Version -eq "")
    {
        $asdkFiles = ASDKDownloader -Interactive -Destination $asdkDownloadPath
    }
    else
    {
        $asdkFiles = ASDKDownloader -Version $Version -Destination $asdkDownloadPath
    }
    Write-Log @writeLogParams -Message "$asdkFiles"
      
    #Extracting Azure Stack Development kit files
    
    
    $f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
    $d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder

    Write-Log @writeLogParams -Message "Extracting Azure Stack Development kit files;"
    Write-Log @writeLogParams -Message "to $d"

    ExtractASDK -File $f -Destination $d

    $vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"
    $foldersToCopy = @('CloudDeployment', 'fwupdate', 'tools')

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

        foreach ($folder in $foldersToCopy)
        {
            Write-Log @writeLogParams -Message "Copying folder $folder to $destPath"
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination C:\ -Recurse -Force
            Write-Log @writeLogParams -Message "$folder done..."
        }
        Write-Log @writeLogParams -Message "Dismounting cloudbuilder.vhdx"
        Dismount-VHD -Path $vhdxFullPath       
    }
    
    Write-Log @writeLogParams -Message "Running BootstrapAzureStackDeployment"
    Set-Location C:\CloudDeployment\Setup
    .\BootstrapAzureStackDeployment.ps1

    Write-Log @writeLogParams -Message "Tweaking some files to run ASDK on Azure VM"

    Write-Log @writeLogParams -Message "Applying first workaround to tackle bare metal detection"
    workaround1

    Write-Log @writeLogParams -Message "Applying second workaround since this version is 1802 or higher"
    workaround2
}

if (Get-ScheduledJob -name "ASDK Installer Companion Service" -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name "ASDK Installer Companion Service" | Unregister-ScheduledJob -Force
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "$defaultLocalPath\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
Write-Log @writeLogParams -Message "Time server is now $timeServer"

if ($DeploymentType -eq "AAD")
{
    $InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        InfraAzureDirectoryTenantName = $aadTenant
        NATIPv4Subnet = "192.168.137.0/28"
        NATIPv4Address = "192.168.137.11"
        NATIPv4DefaultGateway = "192.168.137.1"
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
    }
}

if ($DeploymentType -eq "ADFS")
{
    $InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        NATIPv4Subnet = "192.168.137.0/28"
        NATIPv4Address = "192.168.137.11"
        NATIPv4DefaultGateway = "192.168.137.1"
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
        UseADFS = $true
    }
}

#Azure Stack PoC installer setup
Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams