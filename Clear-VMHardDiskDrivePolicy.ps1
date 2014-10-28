<#
    .SYNOPSIS
        Clears assigned Storage QoS policy from a virtual hard disk

    .DESCRIPTION
        Clears assigned Storage QoS policy from a virtual hard disk.  This should
        only be used with Windows Server Technical Preview

    .NOTES
        File Name : Clear-VMHardDiskDrivePolicy.ps1
        Authors   : Patrick Lang

    .EXAMPLE
        Get-VM -Name TestVm | Get-VMHardDiskDrive | .\Clear-VMHardDiskDrivePolicy.ps1
        
        Clears policies from all virtual disks attached to 'TestVm'

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

    function WaitForResult($Output)
    {
        if ($Output.ReturnValue -eq 4096)
        {
            while ($true)
            {
                $job = [wmi]$Output.Job
                if ($job -ne $null)
                {
                    if ($job.JobState -gt 4)
                    {
                        write-warning $job.ErrorDescription;
                        write-warning $job.__PATH;
                        throw "Job returned error $($job.ErrorCode)"
                    }
                }
                start-sleep 1
            }
        }

    }
    
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

    $ns = "root\virtualization\v2"
    $svc = gwmi -n $ns Msvm_VirtualSystemManagementService
}

process {
    switch($PSCmdlet.ParameterSetName)
    {
        "ByPipe" { 
            $sasds = $VMHardDiskDrives | foreach-object {
                GetStorageAllocationSettingData -VMHardDiskDrive $_ 
            }
        }
        "ByDisk" {
            $sasds = GetStorageAllocationSettingData -VMHardDiskDrive $VMHardDiskDrive
        }

    }

    foreach ($sasd in $sasds)
    {
        $sasd.StorageQoSPolicyID = "" # Empty GUID means no policy applied
        WaitForResult($svc.ModifyResourceSettings(@($sasd.GetText(2))));
    }
}

