function Get-SqlVersionNew{

    <# 
    .SYNOPSIS 
        Find which version of MSSQL is installed on a remote server via registry search
    .PARAMETER ComputerName
        The name of the remote computer where you wish to find the sql version
    .PARAMETER Credential
        Credentials to access the remote server
    .EXAMPLE
        Get-SqlVersion CL-TEST-SQ01 -Credential domain\admin.user
    .NOTES 
        @author Zach Pierce
        @modified 03/08/17
    #> 
    
    [CmdletBinding()]param(
        [Parameter(Position = 0,Mandatory=$True)]
        [string]$ComputerName,
        [Parameter(Position = 1,Mandatory=$True)]
        [System.Management.Automation.PSCredential]$Credential
    )

    process{

        try{

            #try f drive first
            New-PSDrive -Name RemoteServer -PSProvider FileSystem -Root "\\$ComputerName\F$\Program Files\Microsoft SQL Server" -Credential $Credential -ErrorAction Stop | Out-Null #mount drive

        }catch{
            try{

                #check c if no F
                New-PSDrive -Name RemoteServer -PSProvider FileSystem -Root "\\$ComputerName\C$\Program Files\Microsoft SQL Server" -Credential $Credential -ErrorAction Stop | Out-Null

            }catch{
                throw $_
            }
        }

        $SqlDir = gci RemoteServer:\ | Where-Object{ $_.Name -like "MSSQL*"}

        if($SqlDir){
            $BinPath = "RemoteServer:\$($SqlDir.Name)\MSSQL\Binn\sqlservr.exe"
        }else{
            throw "no SQL install found on $ComputerName"
        }

        $SqlVersion = (Get-Item $BinPath).VersionInfo.ProductVersion

    }

    end{

        Remove-PSDrive RemoteServer

        switch -Wildcard ($( $SqlVersion.Substring(0,4) )){
            8*{$Version = 2000}
            9*{$Version = 2005}
            10.5{$Version = 2008}
            10*{$Version = 2008.5}
            11*{$Version = 2012}
            12*{$Version = 2014}
            13*{$Version = 2016}
            default{Throw "Unknown version, please update script"}
        }

        $Result = @{
            ServerName = $ComputerName
            Version = $SqlVersion
            Year = $Version
        }

        Return $Result

    }

}