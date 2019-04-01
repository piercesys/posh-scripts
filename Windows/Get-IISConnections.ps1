function Get-IISConnections {
    <# 
    .SYNOPSIS 
        Get all the active IIS connections for a given site (or sites), or all the sites in IIS
    .DESCRIPTION 
        The Get-IISConnections function will list all active connections to a site, array of sites, or all sites on a remote server.
    .PARAMETER ComputerName
        The server on which you wish to check connections
    .PARAMETER Credential
        Credentials to log on to the remote server
    .PARAMETER SiteName
        Optional parameter: the specific site, or sites you wish to check the connection count for
    .EXAMPLE
        Check the active connections to weathertech.com on cl-weath-7wb02
        Get-IISConnections -ComputerName cl-weath-7wb02 -Credential $h7creds -SiteName weathertech.com
     .EXAMPLE
        Check the active connections to weathertech.com and api.weathertech.com on cl-weath-7wb02
        Get-IISConnections -ComputerName cl-weath-7wb02 -Credential $h7creds -SiteName @('weathertech.com','api.weathertech.com')
    .EXAMPLE
        Check the active connections on cl-weath-7wb02
        Get-IISConnections -ComputerName cl-weath-7wb02 -Credential $h7creds
    .NOTES 
        @author Zach Pierce
        @modified 2017-11-14
    #>  

    [CmdletBinding()]param(
    [Parameter(Position=0,Mandatory=$True)]
    [string]$ComputerName,
    [Parameter(Position=1,mandatory=$True)]
    [System.Management.Automation.CredentialAttribute()]$Credential,
    [Parameter(Position=2)]
    [string[]]$SiteName
    )

    begin{
        try{
            $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction stop  #Open session on remote computer
        }catch{

            throw "Unable to open remote session. Please check credentials and try again."
       }
    }#end begin

    process{
        
        $ScriptBlock = {

            Import-Module WebAdministration

            if ($args[0]){
                [string[]]$SiteName = $args[0]
            }

            $Connections = @()

            if($SiteName -ne $NULL){

                Foreach ($Site in $SiteName){
                    echo $Site
                    $Connections += New-Object PsObject -Property @{
                        SiteName = $Site
                        Connections = (Get-Counter -counter ('\web service(' + $Site + ')\Current Connections') -ComputerName localhost ).CounterSamples.CookedValue
                    }
                }
                return $Connections

            }else{

                Foreach ($Site in (Get-ChildItem IIS:\Sites | ?{$_.name -notlike '*redirects*'}) ){ #get values for all sites if none specified, ignoring redirect profiles to save time
                    $Connections += New-Object PsObject -Property @{
                        SiteName = $Site.name 
                        Connections = (Get-Counter ('\web service(' + $Site.Name + ')\Current Connections') -ComputerName localhost).CounterSamples.CookedValue
                    }
                }
    
                return $Connections

            }
        }#end script block

        $Connections = Invoke-Command -Session $Session -scriptblock $ScriptBlock -ArgumentList ($SiteName) | Select-Object connections, sitename #array arg requires comma in front
        Remove-PSSession $Session

    }#end process
    end{
        Return $Connections | Format-Table -AutoSize
    }

}
