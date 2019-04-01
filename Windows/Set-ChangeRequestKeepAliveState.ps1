function Set-RemoteNodeHealthCheckState{
    <# 
    .SYNOPSIS 
        Adjust a healthcheck file on a remote server, so that the node is removed from your load balancing rotation gracefully
    .PARAMETER ComputerName
        The name or an array of names of the remote computer(s) where you wish to adjust the file
    .PARAMETER State
        Set either 'online' to set the healthcheck file back to its original state, or 'offline' to move it to the $UnhealthyFileName specified
    .PARAMETER FolderName
		The name of the application directory, e.g. 'website.com\cms'
    .PARAMETER Credential
        PSCredentials for connecting to the remote computer
    .PARAMETER HealthyFileName
        The name of the file that is used as the health check endpoint
    .PARAMETER UnhealthyFileName
        Optional, the name that the health check file will be moved to
	.PARAMETER RootPath
		The base path to the parent directory of the application.  Typically the wwwroot directory.  "\\$Computer\$RootPath\$FolderName" should get you to the application directory
    .EXAMPLE
        Set test.com offline on servers 01-03
        Set-RemoteNodeHealthCheckState -ComputerName @('dc-web01','dc-web02','dc-web03') -State Offline -FolderName 'test.com\app' -HealthyFileName 'healthcheck.aspx' -UnhealthyFileName '_healthcheck.aspx' -Credential $Credentials
    .NOTES 
        @author Zach Pierce
        @modified 3/4/17
    #>  
	
    [CmdletBinding()]param(
        [Parameter(Mandatory=$True,Position=0)]
        [string[]]$ComputerName,
        [Parameter(Mandatory=$True,Position=1)][ValidateSet("Online","Offline")]
        [string]$State,
        [Parameter(Mandatory=$True,Position=2)]
        [string]$FolderName,
        [Parameter(Mandatory=$True,Position=3)]
        [System.Management.Automation.PSCredential]$Credential,
        [string]$HealthyFileName = "keepalive.aspx",
        [string]$UnhealthyFileName = "keepoffline.aspx",
        [string]$RootPath = "F$\inetpub\wwwroot"
    )

    begin{
        $ErrorActionPreference = "Stop"
        $Status = @() #Out variable
    }

    process{

        foreach($Computer in $ComputerName){
            try{ 
                New-PSDrive -Name KeepAlive -PSProvider FileSystem -Root "\\$Computer\$RootPath\$FolderName" -Description "Keepalive Dir" -Credential $Credential -ErrorAction Stop | Out-Null #mount remote folder

                if($State -eq "Offline"){
                    if(Test-Path KeepAlive:\$HealthyFileName -ErrorAction SilentlyContinue){ #try root
                        Move-Item -Path KeepAlive:\$HealthyFileName -Destination KeepAlive:\$UnhealthyFileName -Force
                    }elseif(Test-Path KeepAlive:\web\$HealthyFileName -ErrorAction SilentlyContinue){ #try standard \web\ dir
                        Move-Item -Path KeepAlive:\web\$HealthyFileName -Destination KeepAlive:\web\$UnhealthyFileName -Force
                    }elseif(Test-Path KeepAlive:\Website\$HealthyFileName -ErrorAction SilentlyContinue){ #sitecore
                        Move-Item -Path KeepAlive:\Website\$HealthyFileName -Destination KeepAlive:\Website\$UnhealthyFileName -Force
                    }else{
                        throw "$HealthyFileName not found at \\$Computer\$RootPath\$FolderName\$HealthyFileName"
                    }
                    $Status += [pscustomobject]@{
                        Computer = $Computer
                        Status = $State
                    }
                    Remove-PSDrive -Name KeepAlive

                }elseif($State -eq "Online"){
                    if(Test-Path KeepAlive:\$UnhealthyFileName -ErrorAction SilentlyContinue){ #try root
                        Move-Item -Path KeepAlive:\$UnhealthyFileName -Destination KeepAlive:\$HealthyFileName -Force
                    }elseif(Test-Path KeepAlive:\web\$UnhealthyFileName -ErrorAction SilentlyContinue){ #try standard \web\ dir
                        Move-Item -Path KeepAlive:\web\$UnhealthyFileName -Destination KeepAlive:\web\$HealthyFileName -Force
                    }elseif(Test-Path KeepAlive:\Website\$UnhealthyFileName -ErrorAction SilentlyContinue){ #sitecore
                        Move-Item -Path KeepAlive:\Website\$UnhealthyFileName -Destination KeepAlive:\Website\$HealthyFileName -Force
                    }else{
                        throw $Error[0]
                    }
                    $Status += [pscustomobject]@{
                        Computer = $Computer
                        Status = $State
                    }
                    Remove-PSDrive -Name KeepAlive

                }else{
					Remove-PSDrive -Name KeepAlive
                    throw "Invalid -State parameter specified somehow"
                }
            }catch { 
				Remove-PSDrive -Name KeepAlive
                throw $ERROR[0] 
            }
        }#end foreach computer
    }#end process

    end{
        Return $Status
    }
}