function New-RemoteIISWebsite {
    <# 
    .SYNOPSIS 
        Create an IIS website and application pool for the site specified, along with bindings.
    .PARAMETER SiteName
        The name for the site profile/application pool to use.  This should match the folder name for the site
        E.G. zptest-design.com
    .PARAMETER Credential
        The Username and Password stored as a credential for authenticating to remote servers
        If not entered, user will be prompted for password once function begins.
    .PARAMETER MapCKEditor
        If this is for an idev site, this parameter should be marked as 'true' so that the virtual directory gets mapped for the site
        This is an optional parameter.  Default will be 'true' as a missing folder just won't get mapped.
    .Parameter IPAddress
        IP address for the site's bindings
    .Parameter URL
        The URL that should be used for the site's bindings.
    .Parameter ServerName
        The name of the web server that you wish to make the changes on.
    .Parameter RootPath
        Optional parameter for the root of the wwwroot folder must end with \.  If not specified, will default to F:\inetpub\wwwroot\
        Actual site should live at $RootPath$SiteName\web
    .EXAMPLE
        Create a new idev website for zptest-design.com on cl-total-4wb04
        New-RemoteIISWebsite -SiteName zptest-design.com -MapCKEditor 1 -IpAddress 12.133.120.88 -URL zptest-design.idevdesign.net -ServerName cl-total-4wb04 -Credential 
    .NOTES 
        @author Zach Pierce
        @modified 12/13/16
    #>  

        [CmdletBinding()]param(
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        [System.Management.Automation.PSCredential]$Credential,
        [bool]$MapCKEditor,
        [bool]$EnablePreload,
        [Parameter(Mandatory=$true)]
        [ipaddress]$IpAddress,
        [Parameter(Mandatory=$true)]
        [string]$URL,
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        [string]$RootPath
    )

    begin{

           
           if(!$Credential){

                $Credential = get-credential -Message "Please enter your SA credentials to continue" #prompt for creds if not supplied initially

           }

           if( ($ServerName -notlike '*vwb*') -and ($ServerName -notlike '*wb*') ) {  #validate server name as web server
                
                throw "Invalid server name, please ensure you are running this on a web server"
                exit
           }

           if($RootPath -eq ""){

                $RootPath = "F:\inetpub\wwwroot\$SiteName"  #set default root path if left empty

           }

           if($MapCKEditor -eq $null){

                $MapCKEditor = $true  #default mapckeditor to true if not specified

           }

           try{

                $session = New-PSSession -ComputerName $ServerName -Credential $Credential  #try to open session on remote web server

            }catch{

                throw "Unable to open remote session, no changes have been made."
                exit

            }

    }
    
    process{

            $block = {  #set script block to be run on remote server

                $SiteName = $args[0]
                $MapCKEditor = $args[1]
                $IpAddress = $args[2]
                $Url = $args[3]
                $RootPath = $args[4]
                $EnablePreload = $args[5]

                import-module 'webAdministration' 

                $AppPool = New-WebAppPool -Name $SiteName
                $Website = New-Website -Name $SiteName -Port 80 -IPAddress $IpAddress -HostHeader $Url -PhysicalPath $RootPath -ApplicationPool $SiteName
                New-WebBinding -Name $SiteName -protocol https -Port 443 -IPAddress $IpAddress -HostHeader $Url -SslFlags 1
                if($MapCKEditor){ New-WebVirtualDirectory -Site $SiteName -Name CKEditor -PhysicalPath $RootPath\ckeditor }
                Start-Website -Name $SiteName

                if ($EnablePreload){
                    $AppPool | Set-ItemProperty -name "startMode" -Value "AlwaysRunning"
                    $Website | Set-ItemProperty -name "applicationDefaults.preloadEnabled" -Value True
                }

            }

        Invoke-Command -Session $Session -scriptblock $Block -args $SiteName,$MapCKEditor,$IpAddress,$Url,$RootPath,$EnablePreload #pass the parameters down the line to the remote session

        }

    end{

        Remove-PSSession $session #close session

        Return "Started site $SiteName on $ServerName"
    }
}