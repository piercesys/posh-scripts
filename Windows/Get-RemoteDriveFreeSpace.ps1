Function Get-RemoteDriveFreeSpace{

    [CmdletBinding()]param(
        [Parameter(Mandatory=$true)][Alias("Server")][string]$ComputerName,
        [Parameter(Mandatory=$true)][Alias("Drive")][string]$DriveName,
        [System.Management.Automation.PSCredential]$Credential,
        [switch][alias("GB")]$Gigabyte,
        [switch][alias("MB")]$Megabyte,
        [switch][alias("KB")]$Kilobyte,
        [switch][alias("B")]$Byte
    )

    begin{

        $Domain = Get-ServerDomainSegment $ComputerName #find which domain the server is in, for cred prompt

        if( !$Credential){

            $Credential = Get-Credential -Message "Please enter $Domain admin credentials" #prompt for creds if not passed.  shouldn't be needed later.

        }

    }

    process{

        $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential

        $Block = {

            $DriveName = $args[0]

            $DiskSpace = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$DriveName`:'" | Select-Object Size,FreeSpace
            Return $DiskSpace.freespace

        }

        $DiskSpace = Invoke-Command -Session $Session -ScriptBlock $Block -args $DriveName

    }

    end{
        
        $TotalSizeInBytes = $DiskSpace

        Switch ($PSBoundParameters.Keys) {
        'Gigabyte'  { return [math]::Round(($TotalSizeInBytes / 1073741824),2) }
        'Megabyte'  { return [math]::Round(($TotalSizeInBytes / 1048576),2) }
        'Kilobyte'  { return [math]::Round(($TotalSizeInBytes / 1024),2) }
        'Byte'      { return $TotalSizeInBytes }

        }

        Remove-PSSession $Session

        return $TotalSizeInBytes

    }
}