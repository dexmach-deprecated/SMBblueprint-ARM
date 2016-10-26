@{
	AllNodes = @(
		@{
			NodeName="*"
			RetryCount = 20
			RetryIntervalSec = 30
			PSDscAllowPlainTextPassword=$true
			PSDscAllowDomainUser = $true
		},
		@{ 
			NodeName = "SRA-01"
			Role = "DC-Primary","RDS-All"
		}
		@{ 
			NodeName = "SRA-02"
			Role = ""
		}
	)
}