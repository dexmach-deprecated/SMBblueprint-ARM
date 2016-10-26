Configuration SMB
{

[CmdletBinding()]

Param (
	[string] $NodeName = $env:COMPUTERNAME,
	[string] $domainName,
	[System.Management.Automation.PSCredential]$domainAdminCredentials,
	[string] $OMSWorkSpaceId,
	[string] $OMSWorkSpaceKey
)

Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory,xComputerManagement,cRemoteDesktopServices,xCredSSP,xNetworking,xPSDesiredStateConfiguration
$DependsOnAD = ""
$DomainCred = new-object pscredential "$domainName\$($domainAdminCredentials.UserName)",$domainAdminCredentials.Password
Node $NodeName {
	LocalConfigurationManager
		{
			ConfigurationMode = 'ApplyAndMonitor'
			RebootNodeIfNeeded = $true
			ActionAfterReboot = 'ContinueConfiguration'
			AllowModuleOverwrite = $true
		}
        Registry CredSSPEnableNTLMDelegation1
        {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName   = "AllowFreshCredentialsWhenNTLMOnly"
            ValueData   = "1"
            ValueType = 'Dword' 
        }
        Registry CredSSPEnableNTLMDelegation2
        {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            ValueName   = "ConcatenateDefaults_AllowFreshNTLMOnly"
            ValueData   = "1"
            ValueType = 'Dword' 
        }
         Registry CredSSPEnableNTLMDelegation3
        {
            Ensure      = "Present"  # You can also set Ensure to "Absent"
            Key         = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly"
            ValueName   = "1"
            ValueData   = "WSMAN/*"
            ValueType = 'String'
        }
         xCredSSP Server 
                { 
                    Ensure = "Present" 
                    Role = "Server"
                    DependsOn = '[Registry]CredSSPEnableNTLMDelegation1','[Registry]CredSSPEnableNTLMDelegation2','[Registry]CredSSPEnableNTLMDelegation3'
                } 
        xCredSSP Client 
        { 
            Ensure = "Present" 
            Role = "Client" 
            DelegateComputers = "*"
            DependsOn = '[Registry]CredSSPEnableNTLMDelegation1','[Registry]CredSSPEnableNTLMDelegation2','[Registry]CredSSPEnableNTLMDelegation3'
        }

		  Service OIService
        {
            Name = "HealthService"
            State = "Running"
            DependsOn = "[Package]OI"
        }

        xRemoteFile OIPackage {
            Uri = "http://download.microsoft.com/download/0/C/0/0C072D6E-F418-4AD4-BCB2-A362624F400A/MMASetup-AMD64.exe"
            DestinationPath = "C:\MMASetup-AMD64.exe"
        }

        Package OI {
            Ensure = "Present"
            Path  = "C:\MMASetup-AMD64.exe"
            Name = "Microsoft Monitoring Agent"
            ProductId = "8A7F2C51-4C7D-4BFD-9014-91D11F24AAE2"
            Arguments = '/C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_ID=' + $OMSWorkSpaceId + ' OPINSIGHTS_WORKSPACE_KEY=' + $OMSWorkSpaceKey + ' AcceptEndUserLicenseAgreement=1"'
            DependsOn = "[xRemoteFile]OIPackage"
        }
    



		

	if($AllNodes.Where{($_.Role -notcontains "DC-Primary") -and $($_.NodeName -eq $NodeName)})
	{
		
			
		xComputer DomainJoin {
			Name = $NodeName
			DomainName = $DomainName
			Credential = $DomainCred
		}
		$DependsOnAD = "[xComputer]DomainJoin"

	} else {
		$DependsOnAD = "[xWaitForADDomain]WaitForDomain"

	}

	if($AllNodes.Where{($_.Role -contains "DC-Primary") -and $($_.NodeName -eq $NodeName)}){
		WindowsFeature DNS_RSAT
		{ 
			Ensure = "Present" 
			Name = "RSAT-DNS-Server"
		}

		WindowsFeature ADDS_Install 
		{ 
			Ensure = 'Present' 
			Name = 'AD-Domain-Services' 
		} 

		WindowsFeature RSAT_AD_AdminCenter 
		{
			Ensure = 'Present'
			Name   = 'RSAT-AD-AdminCenter'
		}

		WindowsFeature RSAT_ADDS 
		{
			Ensure = 'Present'
			Name   = 'RSAT-ADDS'
		}

		WindowsFeature RSAT_AD_PowerShell 
		{
			Ensure = 'Present'
			Name   = 'RSAT-AD-PowerShell'
		}

		WindowsFeature RSAT_AD_Tools 
		{
			Ensure = 'Present'
			Name   = 'RSAT-AD-Tools'
		}

		WindowsFeature RSAT_Role_Tools 
		{
			Ensure = 'Present'
			Name   = 'RSAT-Role-Tools'
		}      

		WindowsFeature RSAT_GPMC 
		{
			Ensure = 'Present'
			Name   = 'GPMC'
		} 
		xADDomain CreateForest 
		{ 
			DomainName = $domainName            
			DomainAdministratorCredential = $DomainCred
			SafemodeAdministratorPassword = $DomainCred
			DatabasePath = "C:\Windows\NTDS"
			LogPath = "C:\Windows\NTDS"
			SysvolPath = "C:\Windows\Sysvol"
			DependsOn = '[WindowsFeature]ADDS_Install',"[xCredSSP]Client","[xCredSSP]Server"
			RetryCount = "6"
			RetryIntervalSec = "10"
		}
		xWaitForADDomain WaitForDomain {
			DomainName = $domainName
			RetryCount = 10
			RetryIntervalSec = 60
		}

		
	}

		if($AllNodes.Where{($_.Role -contains "RDS-All") -and ($_.NodeName -eq $NodeName)})
    {
		

        WindowsFeature Remote-Desktop-Services
        {
            Ensure = "Present"
            Name = "Remote-Desktop-Services"
			DependsOn = $DependsOnAD
        }

        WindowsFeature RDS-RD-Server
        {
            Ensure = "Present"
            Name = "RDS-RD-Server"
			DependsOn = $DependsOnAD
        }

         WindowsFeature RDS-Gateway
        {
            Ensure = "Present"
            Name = "RDS-Gateway"
			DependsOn = $DependsOnAD
        }

        WindowsFeature Desktop-Experience
        {
            Ensure = "Present"
            Name = "Desktop-Experience"
			DependsOn = $DependsOnAD
        }

        WindowsFeature RSAT-RDS-Tools
        {
            Ensure = "Present"
            Name = "RSAT-RDS-Tools"
            IncludeAllSubFeature = $true
			DependsOn = $DependsOnAD
        }

       
		WindowsFeature RDS-Connection-Broker
		{
			Ensure = "Present"
			Name = "RDS-Connection-Broker"
			DependsOn = $DependsOnAD
		}
        

       
		WindowsFeature RDS-Web-Access
		{
			Ensure = "Present"
			Name = "RDS-Web-Access"
			DependsOn = $DependsOnAD
		}
        

        WindowsFeature RDS-Licensing
        {
            Ensure = "Present"
            Name = "RDS-Licensing"
			DependsOn = $DependsOnAD
        }

  
		cRDSessionDeployment Deployment {

            ConnectionBroker     = $Node.NodeName

            WebAccess            = $Node.NodeName

            SessionHost          = $Node.NodeName

            Credential           = $DomainCred

            DependsOn = "[WindowsFeature]Remote-Desktop-Services", "[WindowsFeature]RDS-RD-Server",$DependsOnAD

        }

        cRDSGateway Gateway {
            ConnectionBroker =  $Node.NodeName
            Credential = $DomainCred
            Gateway =  $Node.NodeName
            GatewayFQDN = "$($DomainName.Replace('.local','')).westeurope.cloudapp.azure.com"
            DependsOn = "[cRDSessionDeployment]Deployment","[WindowsFeature]RDS-Gateway",$DependsOnAD
        }

       
    }

	if($AllNodes.Where{($_.Role -contains "RDS-Session") -and ($_.NodeName -eq $NodeName)})
    {
		     

        WindowsFeature Remote-Desktop-Services
        {
            Ensure = "Present"
            Name = "Remote-Desktop-Services"
			DependsOn = $DependsOnAD
        }

        WindowsFeature RDS-RD-Server
        {
            Ensure = "Present"
            Name = "RDS-RD-Server"
			DependsOn = $DependsOnAD
        }

        WindowsFeature Desktop-Experience
        {
            Ensure = "Present"
            Name = "Desktop-Experience"
			DependsOn = $DependsOnAD
        }

        WindowsFeature RSAT-RDS-Tools
        {
            Ensure = "Present"
            Name = "RSAT-RDS-Tools"
            IncludeAllSubFeature = $true
			DependsOn = $DependsOnAD
        }
        
		WaitForAll RDS {
				ResourceName = "[cRDSessionDeployment]Deployment"
				NodeName = $Node.ConnectionBroker
				RetryIntervalSec = 60
				RetryCount = 10
			}

   
		cRDSessionHost Deployment {

			Ensure = "Present"

			Credential = $DomainCred

            ConnectionBroker     = $Node.ConnectionBroker

            SessionHost          = $Node.NodeName

            DependsOn = "[WindowsFeature]Remote-Desktop-Services", "[WindowsFeature]RDS-RD-Server",$DependsOnAD

        }

	}
	}
}







   