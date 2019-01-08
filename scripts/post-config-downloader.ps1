<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Param(
    # Temporary Local Administrator's username specified in the ARM template
    [Parameter(Mandatory=$true)]
    [string]
    $Username = "__administrator",

    # Enables downloading ASDK on the shortcut on desktop
    [Parameter(ParameterSetName="AzureImage")]
    [switch]
    $EnableDownloadASDK,

    # Azure marketplace image will be used and ASDK will be downloaded
    [Parameter(ParameterSetName="AzureImage")]
    [switch]
    $AzureImage,

    # Latest ASDK will be downloaded and extracted automatically
    [Parameter(ParameterSetName="AzureImage")]
    [switch]
    $AutoDownloadASDK,

    # Original ASDK image will be used. Only valid for LOD deployment option
    [Parameter(ParameterSetName="ASDKImage")]
    [switch]
    $ASDKImage,

    # Github branch
    [Parameter(Mandatory=$true)]
    [ValidateSet("master", "development")]
    [string]
    $GithubBranch,

    # Local Administrator Password
    [Parameter(Mandatory=$true)]
    [string]
    $AdminPassword,

    # Azure Active Diretory Tenant name
    [Parameter()]
    [string]
    $InfraAzureDirectoryTenantName,

    # Parameter help description
    [Parameter()]
    [string]
    $DNSForwarder = "8.8.8.8",

    # Parameter help description
    [Parameter()]
    [string]
    $TimeServer = "pool.ntp.org",

    # Parameter help description
    [Parameter()]
    [string]
    $InfraAzureDirectoryTenantAdmin,

    # Parameter help description
    [Parameter()]
    [string]
    $InfraAzureDirectoryTenantAdminPassword
)

function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
{
    while($true)
    {
        try
        {
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
    
            }
            else
            {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}

$githubRepo = "AzureStack-VM-PoC"
$defaultLocalPath = "C:\AzureStackOnAzureVM"
New-Item -Path $defaultLocalPath -ItemType Directory -Force


# Enforce usage of TLSv1.2 to download the archive from GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
DownloadWithRetry -Uri "https://github.com/yagmurs/$githubRepo/archive/$GithubBranch.zip" -DownloadLocation "$defaultLocalPath\$GithubBranch.zip"

$repoRoot = "$defaultLocalPath\$githubRepo-$GithubBranch"
Expand-Archive -Path "$defaultLocalPath\$GithubBranch.zip" -DestinationPath $defaultLocalPath
Write-Verbose "repoRoot: $repoRoot"
Write-Verbose $MyInvocation.MyCommand.Definition
ii $repoRoot\scripts

$Pass = $($AdminPassword | ConvertTo-SecureString -AsPlainText -Force)

$InstallAzSPOCParams = @{
    AdminPassword = $Pass
    InfraAzureDirectoryTenantName = $InfraAzureDirectoryTenantName
    TimeServer = $TimeServer
    DNSForwarder = $DNSForwarder
}

if ($InfraAzureDirectoryTenantName -and $InfraAzureDirectoryTenantAdmin -and $InfraAzureDirectoryTenantAdminPassword)
{
    $cred = $($InfraAzureDirectoryTenantAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
    $InfraAzureDirectoryTenantAdminCredential = New-Object System.Management.Automation.PSCredential ($InfraAzureDirectoryTenantAdmin, $cred)
    $InstallAzSPOCParams.add("InfraAzureDirectoryTenantAdminCredential", $InfraAzureDirectoryTenantAdminCredential)
}
$InstallAzSPOCParams  | Export-Clixml -Path "$defaultLocalPath\InstallAzSPOCParams.xml"
