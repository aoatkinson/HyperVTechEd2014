<#
    .SYNOPSIS
        Retrieves assigned Storage QoS PolicyID for a virtual hard disk

    .DESCRIPTION
        This returns a list of virtual hard disk drive configurations, and the 
        assigned PolicyID. This script should only be used with Windows Server 
        Technical Preview.

    .NOTES
        File Name : Get-VMHardDiskDrivePolicy.ps1
        Authors   : Patrick Lang

    .EXAMPLE
        Get-VM -Name TestVm | Get-VMHardDiskDrive | .\Get-VMHardDiskDrivePolicy.ps1
        
        Retrieves all virtual hard disks and the policy ID assigned to each.

#>

param(
    [Parameter(Mandatory=$true, 
               ParameterSetName="ByDisk")]
    [Microsoft.HyperV.PowerShell.HardDiskDrive]$VMHardDiskDrive,
    [Parameter(ValueFromPipeline=$true,
               Mandatory=$true, 
               ValueFromPipelineByPropertyName = $true, 
               ParameterSetName="ByPipe")]
    [Microsoft.HyperV.PowerShell.HardDiskDrive[]]$VMHardDiskDrives
)

begin {

    function GetStorageAllocationSettingData
    {
        param(
        [Microsoft.HyperV.PowerShell.HardDiskDrive]$VMHardDiskDrive
        )
    
        $ns = "root\virtualization\v2"
        $svc = gwmi -n $ns Msvm_VirtualSystemManagementService
        $instanceToQuery = $VMHardDiskDrive.Id -replace "\\", "\\" # Escape backslash for WQL query
        $resource = gwmi -n $ns -Query "SELECT * FROM Msvm_ResourceAllocationSettingData WHERE InstanceId = '$($instanceToQuery)'"
        if ($resource -eq $null)
        {
            throw "Virtual Hard Disk not found"
        }
        $resource.GetRelated("Msvm_StorageAllocationSettingData")
    }

}

process {

    switch($PSCmdlet.ParameterSetName)
    {
        "ByPipe" { 
            $VMHardDiskDrives | foreach-object {
                $sasd = GetStorageAllocationSettingData -VMHardDiskDrive $_
                New-Object PSObject -Property @{ 
                    VMHardDiskDrive = $_;
                    PolicyId = $sasd.StorageQoSPolicyID
                }
            }
        }
        "ByDisk" {
            $sasd = GetStorageAllocationSettingData -VMHardDiskDrive $VMHardDiskDrive
            New-Object PSObject -Property @{ 
                VMHardDiskDrive = $_;
                PolicyId = $sasd.StorageQoSPolicyID
            }
        }
    }

}