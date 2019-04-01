function Set-RemoteNtfsPermissions{
    <# 
    .SYNOPSIS 
        Adjust a healthcheck file on a remote server, so that the node is removed from your load balancing rotation gracefully
    .PARAMETER ComputerName
        The name or an array of names of the remote computer(s) where you wish to apply the permissions
    .PARAMETER FolderPath
		The local path to the parent directoy on the remote computer
	.PARAMETER AccountName
		The security account you wish to set the permissions for, e.g. 'iis apppool\appPoolName'
    .PARAMETER Credential
        PSCredentials for connecting to the remote computer
    .PARAMETER Directories
        A directory or array of directories on which you wish to grant the specified AccountName modify permissions
    .PARAMETER Files
        A file or array of files on which you wish to grant the specified AccountName modify permissions
    .EXAMPLE
        Grant appPoolId modify permissions on images and cms\temp directories, as well as permissions to modify robots.txt
        Set-RemoteNtfsPermissions -ComputerName dc-web01 -FolderPath 'C:\inetpub\wwwroot\test.com' -AccountName 'iis apppool\test.com' -Credential $Credentials -Directories @('images','cms\temp') -Files 'robots.txt'
    .NOTES 
        @author Zach Pierce
        @modified 6/7/16
    #>  
	
    [CmdletBinding()]param(
    [Parameter(Position = 0,Mandatory=$True)]
    [string]$ComputerName,
    [Parameter(Position = 1,Mandatory=$True)]
    [string]$FolderPath,
	[Parameter(Position = 2,Mandatory=$True)]
    [string]$AccountName,
	[Parameter(Position = 3,Mandatory=$True)]
    [System.Management.Automation.CredentialAttribute()]$Credential,
    [string[]]$Directories,
	[string[]]$Files
    )

    begin{

        try{
            $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop  #Open session on remote computer
        }catch{
            throw "Unable to open remote session, no changes have been made." #Give up
        }#end catch

    } #end begin

    process{

        $block = {

            $FolderPath = $args[0]
            $AccountName = $args[1]
            $FoldersToModify = $args[2]
            $FilesToModify = $args[3]

            cd $FolderPath

            foreach ($folder in $Directories){


                $acl = get-acl "$folder" -ErrorAction SilentlyContinue
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$AccountName", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
                $Acl.SetAccessRule($Ar)
                (get-item $folder).SetAccessControl($Acl)

            }#end foreach

            foreach ($file in $Files){

                $acl = get-acl "$file" -ErrorAction SilentlyContinue
                $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$AccountName", "Modify", "Allow")
                $Acl.SetAccessRule($Ar)
                (get-item $file).SetAccessControl($Acl)

            }#end foreach

        } #end block

        Invoke-Command -Session $Session -scriptblock $Block -args $FolderPath,$AccountName,$Directories,$Files

    }

    end{

        Remove-PSSession $Session
        return "Permissions Modified"

    }

}