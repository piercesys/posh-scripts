function Export-RemoteSslCertificate{

        [CmdletBinding()]param(
        [Parameter(Mandatory=$true)]
        [string]$CommonName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [string]$ComputerName,
        [string]$LocalPath = "C:\_Certs",
        [string]$Password = (New-Password)
    )

    begin{
        
        if(!(Test-Path $LocalPath)){
            New-Item $LocalPath -ItemType Directory -Force | Out-Null
        }
    }
    
    process{

        New-PSDrive -Name Certificate -PSProvider filesystem -Root \\$ComputerName\c$ -Credential $Credential | Out-null  #mount remote server F as network drive so we can use remote credentials

        $Block = {
            $CommonName = $args[0]
            $Password = $args[1]

            $Certificate = (gci Cert:\LocalMachine\my | ?{ ($_.Subject -like "*$CommonName*") -and ( $_.NotAfter -gt (Get-Date) ) } | Sort-Object -Property $_.NotBefore | Select-Object -First 1 ) #get newest issued cert matching given CN
            if(!$Certificate){
                throw "No certificate found for $CommonName"
            }else{
                certutil -p $Password -exportPFX My $($Certificate.Thumbprint) "F:\$CommonName.pfx" | out-null
            }
        }
        try{
            Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $Block -ArgumentList $CommonName,$Password
        }catch{
            Throw $ERROR[0]
        }

        Move-Item -Path "Certificate:\$CommonName.pfx" -Destination "$LocalPath\$CommonName.pfx" -Force
    }

    end{
        Remove-PSDrive -Name Certificate
        Return "$LocalPath\$CommonName.pfx - Password: $Password"
    }

}