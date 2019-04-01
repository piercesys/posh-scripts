function New-RemoteFileShare {
    <# 
    .SYNOPSIS 
        Create a fileshare on a remote server with the given name, folder and optionally permissions.  No permissions defined defaults to just server admins
    .PARAMETER ShareName
        The desired name for the share you are setting up.
    .PARAMETER ComputerName
        The name of the server you wish to create the file share on.
    .PARAMETER FolderPath
        Local path to the directory on the remote server.
    .PARAMETER ShareName
        The name of the share that you wish to create.  Required parameter.
    .PARAMETER Credentials
        Credentials to connect to the remote server. Acct requires admin privileges.
    .Parameter UserName
        User or group name to assign permissions to. Optional.  Will grant only server admins full permissions if not specified. Server admin permissions are granted automatically.
    .Parameter Permissions
        Permission level for the -username user; viable permission levels are FULL/CHANGE/READ
        Optional Parameter.  If not specified with username, only read permissions will be granted.
    .EXAMPLE
        Create a share called zptest-ftp on dc-web01 C:\inetpub\wwwroot\zptest.com\ftp - grant modify permissions to zptest_ft user
        New-RemoteFileShare -ComputerName dc-web01 -FolderPath C:\inetpub\wwwroot\zptest.com\ftp -UserName zptest_ft -Permissions CHANGE -credentials $Credentials
    .NOTES 
        @author Zach Pierce
        @modified 12/30/16
    #>  
        [CmdletBinding()]param(
        [Parameter(Mandatory=$true)]
        [string]$ShareName,
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [string]$UserName,
        [string][ValidateSet("FULL","CHANGE","READ")]$Permissions
    )

    begin{
            
        <######  Handling this through validateSet in the parameters now
           if($Permissions){  #if permissions parameter was defined, we want to test it's valid before wasting everyone's time.

                switch($Permissions){
                    FULL{}
                    CHANGE{}
                    READ{}
                    default{ throw "Invalid permission level specified, terminating script"; exit }
                }

           }elseif($UserName){ #if no permissions specified, but there was a user listed, grant it read
                $Permissions = "READ"
           } #>

           if($UserName -and !$Permissions){ #if no permissions specified, but there was a user listed, grant it read
                $Permissions = "READ"
           }

           try{

                $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction stop  #try to open session on remote web server

            }catch{

                throw "Unable to open remote session, no changes have been made."
                exit

            }
    }

    Process{

        $block = {
            
            $ShareName = $args[0]
            $FolderPath = $args[1]
            $UserName = $args[2]
            $Permissions = $args[3]

            if ( !(Test-Path $FolderPath) ) { #Create folder if it doesn't work
                   New-Item $FolderPath -type Directory 
                   Echo "Created $FolderPath"
                }

            if (Get-WmiObject Win32_Share -filter "name='$ShareName'" ){ #check there's not already a share with this name on the server.

                    throw "Share $ShareName exists on server, please try another name. Terminating script."
                    Remove-PSSession $session
                    Exit       
                             
            }

            if($UserName){ #adjust permissions if a user was specified

                try { #tends to crap out if the user doesn't exist yet, hence the try.

                    net share $ShareName="$FolderPath" "/GRANT:domain admins,FULL" "/GRANT:$UserName,$Permissions" /UNLIMITED

                }catch{

                    throw "Unable to create share. Terminating script"
                    Remove-PSSession $session
                    Exit

                }

                $acl = get-acl "$FolderPath" #set NTFS permissions

                switch($Permissions){ #switch share permission titles to ACL equivalents
                    FULL { $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$UserName", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow") }
                    CHANGE { $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$UserName", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow") }
                    READ { $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$UserName", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow") }
                    }

                $Acl.SetAccessRule($Ar)
                Set-Acl -path "$FolderPath" -AclObject $Acl

                }

            else{ #if no username create share only for admins

                try{

                    net share $ShareName="$FolderPath" "/grant:domain admins,FULL" /UNLIMITED #domain admins already have NTFS, only need the share

                }catch{

                    throw "Unable to create share. Terminating script" #don't really see this being a problem, but why not
                    Remove-PSSession $session
                    Exit

                }

              }

            }

        Invoke-Command -Session $session -ScriptBlock $block -args $ShareName,$FolderPath,$UserName,$Permissions #run the remote command

    }

    End{

        Remove-PSSession $session

        Return "\\$ComputerName\$ShareName"

    }

}