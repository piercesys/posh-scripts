function Get-InstalledDotNetVersions{
    <# 
    .SYNOPSIS 
        Find which versions of .NET are installed on a server.  This function will return all versions of .NET installed on the remote server.
        If no server is specified, will return the values of the local machine.
    .PARAMETER ServerName
        The name for the server on which you wish to check the .NET versions ALIAS: Server
        E.G. zptest-design.com
    .EXAMPLE
        Check which versions are installed on cl-total-4wb04
        Get-InstalledDotNetVersions -ServerName cl-total-4wb04
    .NOTES 
        @author Zach Pierce
        @modified 10/19/17
    #>  
        [CmdletBinding()]param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$True,position=0)]
        [Alias("MachineName")]
        [Alias("Server")]
        [string]$ServerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    begin{

            try{

                if($Credential){

                    $session = New-PSSession -ComputerName $ServerName -Credential $Credential -ErrorAction stop #try to open session on remote web serverwith credentials if specified

                }else{

                    $session = New-PSSession -ComputerName $ServerName -ErrorAction stop #try with no credentials if not specified

                }

            }catch{

                if($Credential -eq $Null){

                    $ServerDomain = Get-ServerDomainSegment -ServerName $ServerName
                    $Credential = Get-Credential -Message "Unable to open remote session.  Please enter credentials for $ServerDomain"

                    try{ 
                        $session = New-PSSession -ComputerName $ServerName -Credential $Credential -ErrorAction stop #try again with newly presented credentials
                    }
                    catch{ 
                        throw "Unable to open remote session, please try again later"
                        exit
                    }

                }else{
                    throw "Unable to open remote session, please try again later" #fail if it didn't work with credentials
                    exit
                }

            }
    }

    process{

        $block = {

            Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
            Get-ItemProperty -name Version,Release -EA 0 |
            Where { $_.PSChildName -match '^(?!S)\p{L}'} |
            Select PSChildName, Version, Release, @{
              name="Product"
              expression={
                  switch -regex ($_.Release) {
                    "378389" { [Version]"4.5" }
                    "378675|378758" { [Version]"4.5.1" }
                    "379893" { [Version]"4.5.2" }
                    "393295|393297" { [Version]"4.6" }
                    "394254|394271" { [Version]"4.6.1" }
                    "394802|394806" { [Version]"4.6.2" }
                    "460798|460805" { [Version]"4.7" }
                    "461308|461310" { [Version]"4.7.1" }
                    "461808|461814" { [Version]"4.7.2" }
                    {$_ -gt 461310} { [Version]"Undocumented 4.7.2 or higher, please update script" }
                    default {[Version]"Undocumented 4.7.2 or higher, please update script"}
                  }
                } #end regex
            } #end select
        } #end block

    $NetVersionTable = Invoke-Command -Session $Session -scriptblock $Block 

    $NetVersionTable = $NetVersionTable | Select PSChildName,Version,Release,Product | ?{$_.PSChildName -eq 'Full'}

    } #end process

    end{
        
        Remove-PSSession $session

        if ($NetVersionTable.Product){
            return "$($NetVersionTable.Product)"
        }else{
            switch ($NetVersionTable.Version){
                4.0.30319 { return "4.0"}
                {$_ -in 4.0.30319.0..4.0.30319.17000} {return "4.0"}
                {$_ -in 4.0.30319.17001..4.0.3019.18400} {return "4.5"}
                {$_ -in 4.0.30319.18401..4.0.30319.34000} {return "4.5.1"}
                {$_ -gt 4.0.30319.34000}{return 4.5.2}
                default {return "unable to find version! $($NetVersionTable.Version)"}
            }#end switch
        }#end i/e
    }#end end

}#end function