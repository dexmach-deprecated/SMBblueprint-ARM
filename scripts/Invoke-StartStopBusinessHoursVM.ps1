<#PSScriptInfo
.VERSION 1.0
.GUID 1272101b-0ed0-4695-bb35-a24e6ce3fc47
.AUTHOR Stijn Callebaut
.COMPANYNAME Inovativ
.COPYRIGHT 
.TAGS 
Computer Mgmt
.LICENSEURI 
.PROJECTURI 
.ICONURI 
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
v1.0
Initial release
----------------
#>

<# 
.DESCRIPTION 
This Runbook locates all ARM based Virtual Machines with a given tagName (example: BusinessHours) and
a given tagValue (example: True).
All virtual machines with corresponding tag KeyValue pairs are started or stopped depending on the action
specified as parameter.
#>
#requires -Module AzureRm.Profile
#requires -Module AzureRm.Resources
#requires -Module AzureRm.Compute

[cmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Start', 'Stop')]
    [string]$Action
)

Write-Verbose -Message 'Retrieving Azure Automation assets'
$azureConnection = Get-AutomationConnection -Name 'AzureConnection'
$subscriptionId = Get-AutomationVariable -Name 'AzureSubscriptionId'
# should be in the form "key:value" ; example "BusinessHours:true"
$tagKeyValuePair = (Get-AutomationVariable -Name 'StartStopTagKeyValuePair') -split ':'

Write-Verbose 'Authenticating against Azure'
Clear-Variable -Name params -ErrorAction Ignore
$params = @{
    TenantId = $azureConnection.TenantId
    ApplicationId = $azureConnection.ApplicationId
    CertificateThumbprint = $azureConnection.CertificateThumbprint
}

Try {
    [void](Add-AzureRmAccount -ServicePrincipal @params)
    [void](Set-AzureRmContext -SubscriptionId $subscriptionId)
}
Catch {
    Throw 'Unable to authenticate against Azure' 
}

Write-Verbose -Message "Finding all resources with the given tag $tagKeyValuePair[0] and value $tagKeyValuePair[1]"
Clear-Variable -Name params -ErrorAction Ignore
$params = @{
    ResourceType = 'Microsoft.Compute/virtualMachines'
    TagName = $tagKeyValuePair[0]
    TagValue = $tagKeyValuePair[1]
}
$resourceList = Find-AzureRmResource @params

if($resourceList){
    Foreach($resource in $resourceList) {
        Clear-Variable -Name params -ErrorAction Ignore
        $params = @{
            Name = $resource.ResourceName
            ResourceGroupName = $resource.ResourceGroupName
        }
        if($action -eq 'Stop'){
            Write-Verbose -Message "Stopping VM $resource.ResourceName"
            $params.Add('Force', $true)
            Stop-AzureRmVM @params
        }
        else {
            Write-Verbose -Message "Starting VM $resource.ResourceName"
            Start-AzureRmVM @params
        }
    }
}
else {
    Write-output "No resources found!"
}
