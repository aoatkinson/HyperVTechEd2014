 
function Get-VMInformation {
    [CmdletBinding()]
    param (
        # The name of the computer or cluster that we will be getting information from
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [string]$ComputerName,
        
        # A switch to indicate if this is a cluster or not
        [parameter(Mandatory=$false)]
        [switch]$Cluster
        
    )

    Process {

        # Set the right namespace for whether we are looking at a cluster or a stand-alone server
        If ($cluster) {$Namespace = "root\HyperVCluster\v2"} 
                 else {$Namespace = "root\virtualization\v2"}

        # Query to return virtual machine objects
        $Query = "Select * From MSVM_ComputerSystem where Description='Microsoft Virtual Machine'"

        # Display the results in a nice table
        Get-CimInstance  -Query $Query -Namespace $Namespace -ComputerName $ComputerName | ft `
                         @{Label="VM Name"; Expression={$_.elementname}}, `
                         @{Label="VM ID"; Expression={$_.name}}, `
                         # Look at the associated MSVM_SummaryInformation to find out the real host
                         @{Label="Host"; Expression={(Get-CimAssociatedInstance -ResultClassName MSVM_SummaryInformation -InputObject $_ -Namespace $Namespace -ComputerName $ComputerName).HostComputerSystemName}}, `
                         # Look at the associated MSVM_VirtualSystemSettingData to find out the configuration path
                         @{Label="Configuration Path"; Expression={(Get-CimAssociatedInstance -ResultClassName Msvm_VirtualSystemSettingData -InputObject $_ -Namespace $Namespace -ComputerName $ComputerName).ConfigurationDataRoot}}

              }
        }