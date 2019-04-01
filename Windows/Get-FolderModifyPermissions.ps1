function Get-FolderModifyPermissions {
    <# 
    .SYNOPSIS 
        This will return an array of the relative paths of any subfolders that have modify permissions for a given user
    .DESCRIPTION 
        The Get-FolderModifyPermissions function is useful for determining the permission levels set for any given directory's subdirectories.
        This can be useful for ensuring that permissions on a live web server match those of a development server, by finding 
    .PARAMETER ComputerName
        The name of the server where you wish to find the permissions.
    .PARAMETER FolderPath
        The full local path to the root folder you want permissions on.
    .PARAMETER Credential
        Credentials that can be used to open a remote session on the computerName specified.
    .PARAMETER AccountName
        The name of the account which you wish to find permissions for.  If nothing is specified, will default to 'iis apppool\'+ the name of the pwd
    .EXAMPLE
        Find all the folders that have modify permissions for the tattoofactory updates site:

        Get-FolderModifyPermissions -ComputerName cl-total-4wb04 -FolderPath F:\inetpub\wwwroot\tattoofactory-updates.com -Credential $SACreds
        
        tempIIS
        ckeditor\plugins\templates
        tasks\bin\Debug
        web\404
        web\App_Code
        web\App_WebReferences
        web\archivedassets
        web\assets
        web\cms
    .EXAMPLE
        Find folders with modify permissions for website.com, running under application ID website_iis:

        Get-FolderModifyPermissions -ComputerName cl-net-7wb01 -FolderPath F:\inetpub\wwwroot\website.com -AccountName website_iis -Credential $Hosting7Creds
    .NOTES 
        @author Zach Pierce
        @modified 3/17/17
    #>  

    [CmdletBinding()]param(
    [Parameter(Position = 0,Mandatory=$True)]
    [string]$ComputerName,
    [Parameter(Mandatory=$True)]
    [string]$FolderPath,
    [string]$AccountName,
    [System.Management.Automation.CredentialAttribute()]$Credential
    )

    begin{

        $Domain = Get-ServerDomainSegment -ServerName $ComputerName #find segment for server

        if(!$Credential){

            $Credential = get-credential -Message "Please enter your $Domain credentials to continue" #prompt for creds if not supplied initially

        }

        try{

            $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop  #Open session on remote computer

        }catch{

            throw "Unable to open remote session, no changes have been made. Please check $Domain VPN connection and credentials and try again." #Give up
            return

        }#end catch

    } #end begin

    process{

        $block = {

            $FolderPath = $args[0]
            $AccountName = $args[1]
            $FoldersWithPermissions = @()

            cd $FolderPath #change first so we can get the vars
            
            $PresentDirectory = (Get-Item -Path '.\' -Verbose).Name #name of only the current folder
            $RootDirectory = (Get-Item -Path ".\" -Verbose).FullName+"\"

            if($args[1]){

                #Echo "Hit if"

                $ModifyFolders = Get-ChildItem -Recurse | #all folders
                ?{ $_.PSIsContainer } | #only folders
                ?{(Get-Acl $_.FullName).Access | #get acl
                ?{ ($_.IdentityReference -eq "$AccountName")}} #where app pool has permissions

                foreach ($folder in $ModifyFolders){

                    if ( !((Get-Acl $folder.Parent.FullName).Access | ?{$_.IdentityReference -eq "$AccountName"}).AccessControlType -contains 'Allow' ){ #parent folder doesn't contain modify, indicates this is top level dir
                    
                        $RelativePath = $Folder.FullName -replace [regex]::escape($RootDirectory),("") #strip down to path relative to root
                        $FoldersWithPermissions += $RelativePath

                    }#end if

                }#end foreach

              <#  Files take waaay too long.  Need to check that the parent doesn't already have modify first or something.

                $ModifyFiles = Get-ChildItem -Recurse | #don't recurse
                ?{ !$_.PSIsContainer } | #files only
                ?{(Get-Acl $_.FullName).Access | #get acl
                ?{ ($_.IdentityReference -eq "$AccountName")}} #where app pool has permissions

                foreach ($File in $ModifyFiles){

                    if ( !((Get-Acl $File.Directory.FullName).Access | ?{$_.IdentityReference -eq "$AccountName"}).AccessControlType -contains 'Allow' ){ #parent folder doesn't contain modify, indicates this is top level dir
                    
                        $RelativePath = $file.FullName -replace [regex]::escape($RootDirectory),("") #strip down to path relative to root
                        $FoldersWithPermissions += $RelativePath #add to result

                        }#end if

                }#end foreach  #>

            }#end if account
            else{

                #echo $pwd

                $ModifyFolders = Get-ChildItem -Recurse | #all folders
                ?{ $_.PSIsContainer } | #only folders
                ?{(Get-Acl $_.FullName).Access | #get acl
                ?{ ($_.IdentityReference -eq "iis apppool\$PresentDirectory")}} #where app pool has permissions

                foreach ($folder in $ModifyFolders){

                    if ( !((Get-Acl $folder.Parent.FullName).Access | ?{$_.IdentityReference -eq "iis apppool\$PresentDirectory"}).AccessControlType -eq 'Allow' ){ #logic courses paid off
                        
                        #Echo $folder
                        $RelativePath = $Folder.FullName -replace [regex]::escape($RootDirectory),("") #strip down to path relative to root
                        $FoldersWithPermissions += $RelativePath

                    }#end if

                }#end foreach

                <#$ModifyFiles = Get-ChildItem -Recurse | #don't recurse
                ?{ !$_.PSIsContainer } | #files only
                ?{(Get-Acl $_.FullName).Access | #get acl
                ?{ ($_.IdentityReference -eq "$AccountName")}} #where app pool has permissions

                foreach ($File in $ModifyFiles){

                    if ( !((Get-Acl $File.Directory.FullName).Access | ?{$_.IdentityReference -eq "$AccountName"}).AccessControlType -contains 'Allow' ){ #parent folder doesn't contain modify, indicates this is top level dir
                    
                        $RelativePath = $file.FullName -replace [regex]::escape($RootDirectory),("") #strip down to path relative to root
                        $FoldersWithPermissions += $RelativePath #add to result

                        }#end if

                }#end foreach#>

            }#end else

        return $FoldersWithPermissions

        }#end block

        $FoldersWithPermissions = Invoke-Command -Session $Session -scriptblock $Block -args $FolderPath,$AccountName

    }

    end{

        Remove-PSSession $Session

        return $FoldersWithPermissions

    }
}


<#

                cd 'web' #going to find any individual files with permissions, e.g. robots.txt; single files will only live at root

                $ModifyFiles = Get-ChildItem | #don't recurse
                ?{ !$_.PSIsContainer } | #files only
                ?{(Get-Acl $_.FullName).Access | #get acl
                ?{ ($_.IdentityReference -eq "$AccountName")}} #where app pool has permissions

                foreach ($File in $ModifyFiles){
                    
                        $RelativePath = $file.FullName -replace [regex]::escape($RootDirectory),("") #strip down to path relative to root
                        $FoldersWithPermissions += $RelativePath #add to result

                }#end foreach

#>