#region function Definition
function Enable-ICS ($PublicAdapterName, $PrivateAdapterName)
{
    # Create a NetSharingManager object
    $m = New-Object -ComObject HNetCfg.HNetShare

    # Find connection
    $publicAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


    # Get sharing configuration
    $publicAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($publicAdapter)
    $privateAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($privateAdapter)
        
    Start-Sleep -Seconds 2

    # Disable sharing
    $publicAdapter.DisableSharing()
    $privateAdapter.DisableSharing()

    # Enable sharing (0 - public, 1 - private)

    # Enable sharing public on Network_1
    $publicAdapter.EnableSharing(0)

    # Enable sharing private on Network_2
    $privateAdapter.EnableSharing(1)

}
    
function Disable-ICS ($PublicAdapterName, $PrivateAdapterName)
{
    # Register the HNetCfg library (once)
    regsvr32 /s hnetcfg.dll

    # Create a NetSharingManager object
    $m = New-Object -ComObject HNetCfg.HNetShare

    # Find connection
    $publicAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $publicAdapterName }
    $privateAdapter = $m.EnumEveryConnection |? { $m.NetConnectionProps.Invoke($_).Name -eq $privateAdapterName }


    # Get sharing configuration
    $publicAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($publicAdapter)
    $privateAdapter = $m.INetSharingConfigurationForINetConnection.Invoke($privateAdapter)
        
    # Disable sharing
    $publicAdapter.DisableSharing()
    $privateAdapter.DisableSharing()
}

function Write-Log ([string]$Message, [string]$LogFilePath, [switch]$Overwrite)
{
    $t = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Verbose "$Message - $t"
    if ($Overwrite)
    {
        Set-Content -Path $LogFilePath -Value "$Message - $t"
    }
    else
    {
        Add-Content -Path $LogFilePath -Value "$Message - $t"
    }
}
#endregion

#region Variables
$VerbosePreference = "Continue"
$defaultLocalPath = "C:\AzureStackonAzureVM"
$swName = "NATSw"
$publicAdapterName = "Deployment"
$privateAdapterName = "vEthernet `($swName`)"
$BGPNATVMNetworkAdapterName = "NAT"
$BgpNatVm = "AzS-BGPNAT01"
$logFileFullPath = "$defaultLocalPath\CompanionServiceProgress.log"
$enableNatCheckFile = "C:\CompleteBootDSCStatus\AZs-ACS01.*.xml"
$writeLogParams = @{
    LogFilePath = $logFileFullPath
}
$NATIp = "192.168.137.1/28"

$IP = $natip.split("/")
$Octet = $IP[0].split(".")
$Octet[3] = 0
$NATNetwork = ($Octet -join ".") + "/" + $ip[1]

[int]$defaultPollIntervalInSeconds = 60
$ICS = $true
$serviceVersion = "1.0"

#endregion

# Register the HNetCfg library (once)
regsvr32 /s hnetcfg.dll

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
            Unregister-ScheduledJob -Name "ASDK Installer Companion Service"
            break
        }
    }
    Start-Sleep -Seconds $defaultPollIntervalInSeconds
    $loopCount++
}