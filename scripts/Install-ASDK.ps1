param (
    [bool]
    $Interactive = $true,
    [Security.SecureString]
    $LocalAadminPass,
    [string]
    $AadAdminUser,
    [Security.SecureString]
    $AadPassword,
    [string]
    $LocalAdminUsername = "Administrator"
)

#region Fuctions
function Write-Log ([string]$Message, [string]$LogFilePath, [switch]$Overwrite)
{
    $t = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Verbose "$Message - $t" -Verbose
    if ($Overwrite)
    {
        Set-Content -Path $LogFilePath -Value "$Message - $t"
    }
    else
    {
        Add-Content -Path $LogFilePath -Value "$Message - $t"
    }
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
$defaultLocalPath = "C:\AzureStackonAzureVM"
$gitbranchcode = (Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ",").branch.Trim()
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitbranchcode"
$AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
$options = New-ScheduledJobOption -RequireNetwork
$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$env:ComputerName)
$localCredValidated = $false
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

if ($Interactive -eq $true)
{
    Read-Host -Prompt "`n`nWe are about to start Azure Stack Development Kit installation`nCheck and make sure the following information are correct, setup will use`n`nLocalAdmin User: $LocalAdminUsername`nAzure AD Global Administrator user: $AadAdminUser`nAzure AD Tenant: $aadTenant`n`nPress any to continue or ctrl+c to cancel and startover"    
}

$localAdminCred = New-Object System.Management.Automation.PSCredential ("Administrator", $localAdminPass)
$aadcred = New-Object System.Management.Automation.PSCredential ($AadAdminUser, $AadPassword)

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"
$timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
Write-Log @writeLogParams -Message "Time server is now $timeServer"
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
    AdminPassword = $localAdminPass
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
            Write-Log @writeLogParams -Message "Download process for ASDK$version started"
            $asdkFileList | ForEach-Object {Start-BitsTransfer -Source $($asdkURIRoot + $version + '/' + $_) -Destination $(Join-Path -Path $asdkDownloadPath -ChildPath $_)}
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
    
        $f = Join-Path -Path $asdkDownloadPath -ChildPath "AzureStackDevelopmentKit.exe"
        $o = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
        
        Start-Process -FilePath $f -ArgumentList "/dir=`"$o`"", "/silent" -Wait
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


Write-Log @writeLogParams -Message "Tweaking some nupkg files to run ASDK on Azure VM"
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
Invoke-WebRequest -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -OutFile "$defaultLocalPath\ASDKCompanionService.ps1"
if (Get-ScheduledJob -name "ASDK Installer Companion Service" -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name "ASDK Installer Companion Service" | Unregister-ScheduledJob -Force
}
$st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -FilePath "$defaultLocalPath\ASDKCompanionService.ps1" -Name "ASDK Installer Companion Service" -Credential $localAdminCred
$st.StartJob()

#Download Azure Stack Register script
Invoke-WebRequest -Uri "$gitbranch/scripts/Register-AzureStackLAB.ps1" -OutFile "$defaultLocalPath\Register-AzureStackLAB.ps1"

Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams