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

    [switch]
    $SkipWorkaround,

    [string]
    $version,

    [pscredential]
    $InfraAzureDirectoryTenantAdminCredential
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

$logFileFullPath = "$defaultLocalPath\Install-ASDK.log"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}


#endregion

$asdkDownloadPath = "d:\"
$asdkExtractFolder = "Azure Stack Development Kit"
$d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
$vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"
$foldersToCopy = @('CloudDeployment', 'fwupdate', 'tools')

if (Test-Path "C:\CloudDeployment\Configuration\Version\Version.xml")
{
    Write-Log @writeLogParams -Message "Version information from script input was $version"
    $fullVersion = ([xml](Get-Content C:\CloudDeployment\Configuration\Version\version.xml)).version
    $version = ($fullVersion -split "\.")[1]
    Write-Log @writeLogParams -Message "Gathering local version information at C:\CloudDeployment\Configuration\Version\version.xml"
    Write-Log @writeLogParams -Message "fullVersion is now $fullVersion"
    Write-Log @writeLogParams -Message "Version is now $version"
}
else
{
#Download and extract ASDK files
    if ($DownloadASDK) 
    {
        #Download ASDK files (BINs and EXE)
        Write-Log @writeLogParams -Message "Finding available ASDK versions"

        if (!(Test-Path -Path $vhdxFullPath))
        {
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
    
            Write-Log @writeLogParams -Message "Extracting Azure Stack Development kit files;"
            Write-Log @writeLogParams -Message "to $d"
            
            $f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
            ExtractASDK -File $f -Destination $d
        }

        Write-Log @writeLogParams -Message "About to Start Copying ASDK files to C:\"
        Write-Log @writeLogParams -Message "Mounting cloudbuilder.vhdx"
    
        try {
            $driveLetter = Mount-DiskImage -ImagePath $vhdxFullPath -StorageType VHDX -Passthru | Get-DiskImage | Get-Disk | Get-Partition | Where-Object size -gt 500MB | Select-Object -ExpandProperty driveletter
            Write-Log @writeLogParams -Message "The drive is now mounted as $driveLetter`:"
        }
        catch {
            Write-Log @writeLogParams -Message "an error occured while mounting cloudbuilder.vhdx file"
            Write-Log @writeLogParams -Message $error[0].Exception
            throw "an error occured while mounting cloudbuilder.vhdx file"
        }

        foreach ($folder in $foldersToCopy)
        {
            Write-Log @writeLogParams -Message "Copying folder $folder to C:\"
            Copy-Item -Path (Join-Path -Path $($driveLetter + ':') -ChildPath $folder) -Destination C:\ -Recurse -Force
            Write-Log @writeLogParams -Message "$folder done..."
        }
        Write-Log @writeLogParams -Message "Dismounting cloudbuilder.vhdx"
        Dismount-DiskImage -ImagePath $vhdxFullPath
        
        if (Test-Path "C:\CloudDeployment\Configuration\Version\Version.xml")
        {
            Write-Log @writeLogParams -Message "Version information from script input $version"
            $fullVersion = ([xml](Get-Content C:\CloudDeployment\Configuration\Version\version.xml)).version
            $version = ($fullVersion -split "\.")[1]
            Write-Log @writeLogParams -Message "Gathering local version information at C:\CloudDeployment\Configuration\Version\version.xml"
            Write-Log @writeLogParams -Message "fullVersion is now $fullVersion"
            Write-Log @writeLogParams -Message "Version is now $version"
        }
    }        
}

if ($SkipWorkaround -eq $false)
{    
    Write-Log @writeLogParams -Message "Running BootstrapAzureStackDeployment"
    Set-Location C:\CloudDeployment\Setup
    .\BootstrapAzureStackDeployment.ps1

    Write-Log @writeLogParams -Message "Tweaking some files to run ASDK on Azure VM"

    Write-Log @writeLogParams -Message "Applying first workaround to tackle bare metal detection"
    workaround1

    Write-Log @writeLogParams -Message "Applying second workaround since this version is 1802 or higher"
    workaround2
}
$pocParameters = Get-Help C:\CloudDeployment\Setup\InstallAzureStackPOC.ps1 -Parameter Nat* -ErrorAction SilentlyContinue

#if ($version -lt 1812)
if ($pocParameters.Count -gt 0)
{
    $ASDKCompanionService = {
        $script:defaultLocalPath = "C:\AzureStackOnAzureVM"
        [int]$defaultPollIntervalInSeconds = 60
        $script:swName = "NATSw"
        $script:publicAdapterName = "Deployment"
        $script:privateAdapterName = "vEthernet `($swName`)"
        $script:BGPNATVMNetworkAdapterName = "NAT"
        $script:BgpNatVm = "AzS-BGPNAT01"
        $script:logFileFullPath = "$defaultLocalPath\CompanionServiceProgress.log"
        $script:enableNatCheckFile = "C:\CompleteBootDSCStatus\AZs-ACS01.*.xml"
        $script:writeLogParams = @{
        LogFilePath = $logFileFullPath
        }
        $script:NATIp = "192.168.137.1/28"
        $script:IP = $natip.split("/")
        $script:Octet = $IP[0].split(".")
        $script:Octet[3] = 0
        $script:NATNetwork = ($Octet -join ".") + "/" + $ip[1]

        [int]$defaultPollIntervalInSeconds = 60
        $script:ICS = $true
        $script:serviceVersion = "1.1"
        $taskName1 = "ASDK Installer Companion Service"
        if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
        {
            Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
        }
        else
        {
            throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
        }
        Write-Log @writeLogParams -Message "Starting the service `($serviceVersion`)"

        $loopCount = 0
        while ($true)
        {
            if (-not ([System.Environment]::GetEnvironmentVariable('VMSwitchCreated', [System.EnvironmentVariableTarget]::Machine) -eq $true))
            {
                #Wait for Network Adapter presence if so will create new Internal Virtual Switch  
                $null = Get-NetAdapter -Name $publicAdapterName -ErrorAction SilentlyContinue  
                if ($?)
                {
                    $null = Get-VMSwitch -Name $swName -ErrorAction SilentlyContinue
                    if (-not ($?))
                    {
                        $o = New-VMSwitch -Name $swName -SwitchType Internal -Verbose
                        if ($?)
                        {
                            Write-Log @writeLogParams -Message $o
                            Write-Log @writeLogParams -Message "`'$swName`' switch and `'$privateAdapterName`' Adapter created successfully"
                            Start-Sleep -Seconds 10
                            $o = Remove-NetIPAddress -InterfaceAlias "$privateAdapterName" -Confirm:$false
                            $ip = $NATIp.split("/")[0]
                            $prefixLength = $NATIp.split("/")[1]
                            $o = New-NetIPAddress -InterfaceAlias "$privateAdapterName" -IPAddress $ip -PrefixLength $prefixLength -AddressFamily IPv4
                            if ($?)
                            {
                                Write-Log @writeLogParams -Message "IP address `($ip`) and PrefixLength `($prefixLength`) successfully set to adapter `'$privateAdapterName`'"
                                Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(VMSwitchCreated`)"
                                [System.Environment]::SetEnvironmentVariable('VMSwitchCreated', $true, [System.EnvironmentVariableTarget]::Machine)
                            }
                            Write-Log @writeLogParams -Message $o
                        }
                    }
        
                }
                else
                {
                    if ($loopCount -eq 0)
                    {
                        Write-Log @writeLogParams -Message "Waiting for `'$publicAdapterName`' adapter's presence"
                    }
                }
            }
        
            if (-not ([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true))
            {
                Write-Log @writeLogParams -Message  "Checking $BgpNatVm VM's presence and state"
                $BgpNatVmObj = Get-VM -Name $BgpNatVm | ? state -eq running
                if ($BgpNatVmObj)
                {
                    $null = Get-NetAdapter -Name $privateAdapterName -ErrorAction SilentlyContinue  
                    if ($?)
                    {
                        Write-Log @writeLogParams -Message "Waiting for NIC configurations to complete for $defaultPollIntervalInSeconds seconds"
                        Start-Sleep -Seconds $defaultPollIntervalInSeconds
                        $BgpNatVmObj | Get-VMNetworkAdapter -Name $BGPNATVMNetworkAdapterName | Connect-VMNetworkAdapter -SwitchName $swName
                        Write-Log @writeLogParams -Message "$BgpNatVm's $BGPNATVMNetworkAdapterName network adapter plugged to $swName"
                        Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(BGPNATVMVMNetAdapterFixed`)"
                        [System.Environment]::SetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', $true, [System.EnvironmentVariableTarget]::Machine)
                    }
                }
            }
        
            if (-not ([System.Environment]::GetEnvironmentVariable('NATEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
            {
                Write-Log @writeLogParams -Message "Waiting for $enableNatCheckFile to confirm AZs-ACS01 deployment state"
                $file = Resolve-Path -Path $enableNatCheckFile
                if ($file)
                {
                    [xml]$r = Get-Content -Path $file
                    if ($r.DeploymentDSC.status -like "?*")
                    {
                        if ($ICS -eq $true)
                        {
                            Get-NetNat | Remove-NetNat -Confirm:$false
                            $o = Enable-ICS -PublicAdapterName $publicAdapterName -PrivateAdapterName $privateAdapterName
                            Write-Log @writeLogParams -Message "All Previous NATs removed and ICS Enabled instead"
                            Write-Log @writeLogParams -Message $o
                            Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(NATEnabled`)"
                            [System.Environment]::SetEnvironmentVariable('NATEnabled', $true, [System.EnvironmentVariableTarget]::Machine)
                        }
                        else
                        {
                            Get-NetNat | Remove-NetNat -Confirm:$false
                            $o = New-NetNat -Name "Nat for BGPNAT Network" -InternalIPInterfaceAddressPrefix $NATNetwork
                            Write-Log @writeLogParams -Message "All Previous NATs removed and following NAT created"
                            Write-Log @writeLogParams -Message $o
                            Write-Log @writeLogParams -Message "This step completed. Saving to Environment Variable `(NATEnabled`)"
                            [System.Environment]::SetEnvironmentVariable('NATEnabled', $true, [System.EnvironmentVariableTarget]::Machine)
                        }
                    }
                }
            }
        
            if (
                ([System.Environment]::GetEnvironmentVariable('VMSwitchCreated', [System.EnvironmentVariableTarget]::Machine) -eq $true) -and 
                ([System.Environment]::GetEnvironmentVariable('BGPNATVMVMNetAdapterFixed', [System.EnvironmentVariableTarget]::Machine) -eq $true) -and 
                ([System.Environment]::GetEnvironmentVariable('NATEnabled', [System.EnvironmentVariableTarget]::Machine) -eq $true))
            {
                if ($ICS -eq $true)
                {
                    $o = Enable-ICS -PublicAdapterName $publicAdapterName -PrivateAdapterName $privateAdapterName
                    Write-Log @writeLogParams -Message "ICS Enabled"
                    Write-Log @writeLogParams -Message $o
                    Write-Log @writeLogParams -Message "All fixes applied, as a workaround service will start on next boot to re-enable ICS"
                    break
                }
                else
                {
                    Write-Log @writeLogParams -Message "All fixes applied, Unregistering the service"
                    Unregister-ScheduledJob -Name $taskName1
                    break
                }
                
            }
            Start-Sleep -Seconds $defaultPollIntervalInSeconds
            $loopCount++
        }
    }
    Write-Log @writeLogParams -Message "Registering ASDK Companion service"
    $taskName1 = "ASDK Installer Companion Service"
    $AtStartup = New-JobTrigger -AtStartup -RandomDelay 00:00:30
    $options = New-ScheduledJobOption -RequireNetwork
    if (Get-ScheduledJob -name $taskName1 -ErrorAction SilentlyContinue)
    {
        Get-ScheduledJob -name $taskName1 | Unregister-ScheduledJob -Force
    }
    $st = Register-ScheduledJob -Trigger $AtStartup -ScheduledJobOption $options -ScriptBlock $ASDKCompanionService -Name $taskName1 -Credential $localAdminCred
    $st.StartJob()
}

$taskstoCompleteUponSuccess = {
    $script:defaultLocalPath = "C:\AzureStackOnAzureVM"
    [int]$defaultPollIntervalInSeconds = 60
    $script:logFileFullPath = "$defaultLocalPath\DesktopShortcuts.log"
    $script:writeLogParams = @{
    LogFilePath = $logFileFullPath
    }
    while ($true)
    {
        [xml]$summary = Get-Content -Path C:\CloudDeployment\Logs\summary.*.log.xml -ErrorAction SilentlyContinue
        if ($summary.action.Status -eq "success")
        {
            $taskName2 = "Tasks to complete upon success"
            try
            {
                if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
                {
                    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
                }
                else
                {
                    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
                }
                Get-ChildItem -Path "C:\Users\Public\Desktop" -Filter "*.lnk" | Remove-Item -Force
                createDesktopShortcuts
                Unregister-ScheduledJob -Name $taskName2 -Force
                break
            }
            catch 
            {
                Write-Log @writeLogParams -Message "Failed to create desktop shortcuts"
                Write-Host "Failed to create desktop shortcuts"
            }
        }
        Start-Sleep -Seconds $defaultPollIntervalInSeconds
        $i++
        write-host $i
    }
}

$taskName2 = "Tasks to complete upon success"
$trigger = New-JobTrigger -AtLogOn
$option = New-ScheduledJobOption
if (Get-ScheduledJob -name $taskName2 -ErrorAction SilentlyContinue)
{
    Get-ScheduledJob -name $taskName2 | Unregister-ScheduledJob -Force
}
Register-ScheduledJob -ScriptBlock $taskstoCompleteUponSuccess -Name $taskName2 -Trigger $trigger -ScheduledJobOption $option

$timeServiceProvider = @("pool.ntp.org") | Get-Random
Write-Log @writeLogParams -Message "Picking random timeserver from $timeServiceProvider"

if ($pocParameters.Count -gt 0) {
    Write-Log @writeLogParams -Message "timeserver is IP address"
    $timeServer = (Test-NetConnection -ComputerName $timeServiceProvider).ResolvedAddresses.ipaddresstostring | Get-Random
}
else {
    Write-Log @writeLogParams -Message "timeserver is FQDN"
    $timeServer = $timeServiceProvider
}

Write-Log @writeLogParams -Message "timeserver: $timeServer"

if ($DeploymentType -eq "AAD")
{
    $global:InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        InfraAzureDirectoryTenantName = $aadTenant
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
    }
    #if ($version -lt 1812)
    if ($pocParameters.Count -gt 0)
    {
        $global:InstallAzSPOCParams.Add("NATIPv4Subnet","192.168.137.0/28")
        $global:InstallAzSPOCParams.Add("NATIPv4Address","192.168.137.11")
        $global:InstallAzSPOCParams.Add("NATIPv4DefaultGateway","192.168.137.1")
    }
    if ($InfraAzureDirectoryTenantAdminCredential)
    {
        $global:InstallAzSPOCParams.Add("InfraAzureDirectoryTenantAdminCredential", $InfraAzureDirectoryTenantAdminCredential)
    }
}

if ($DeploymentType -eq "ADFS")
{
    $global:InstallAzSPOCParams = @{
        AdminPassword = $localAdminPass
        TimeServer = $timeServer
        DNSForwarder = "8.8.8.8"
        UseADFS = $true
    }
    #if ($version -lt 1812)
    if ($pocParameters.Count -gt 0)
    {
        $global:InstallAzSPOCParams.Add("NATIPv4Subnet","192.168.137.0/28")
        $global:InstallAzSPOCParams.Add("NATIPv4Address","192.168.137.11")
        $global:InstallAzSPOCParams.Add("NATIPv4DefaultGateway","192.168.137.1")
    }
}

#Azure Stack PoC installer setup
Set-Location C:\CloudDeployment\Setup
.\InstallAzureStackPOC.ps1 @InstallAzSPOCParams