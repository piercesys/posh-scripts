function Import-RemotePfxCertificate{

    <# 
    .SYNOPSIS 
        Import an SSL certificate across multiple servers in a remote domain
    .PARAMETER CertificateFile
        The full path to the p12 certificate file on your local machine
    .PARAMETER CertificatePass
        The password for the p12 file
    .PARAMETER ComputerName
        The name or array of names of the remote computer(s) where you wish to install the certificate
    .PARAMETER Credential
        Credentials to access the remote server
    .EXAMPLE
        Get-SqlVersion CL-TEST-SQ01 -Credential domain\admin.user
    .NOTES 
        @author Zach Pierce
        @modified 03/08/17
    #> 

    begin{
        $CertificateFileName = (get-item $CertificateFile).Name
    }

    foreach ($Computer in $ComputerName){
        
        New-PSDrive -Name CertImport -PSProvider filesystem -Root \\$Computer\C$ -Credential $Credential  #mount remote server F as network drive so we can use remote credentials

        cp "$CertificateFile" CertImport:\$CertificateFileName  #copy over to remote F drive

        $Session = New-PSSession -ComputerName $Computer -Credential $Credential  #open session to install cert on remote server

        #block takes in certname and password and then installs cert and removes pfx from server
        $Block = {

            $CertificateFileName = $args[0]
            $CertificatePass = $args[1]
            Import-PfxCertificate –FilePath C:\$CertificateFileName cert:\localMachine\my -Password (ConvertTo-SecureString -String $CertificatePass -Force –AsPlainText) -Exportable
            Remove-Item C:\$CertificateFileName -Force

            }

        Invoke-Command -Session $Session -scriptblock $Block -args $CertificateFileName,$CertificatePass #invoke actual script block in remote session
        Remove-PSSession $Session #close session
        Remove-PSDrive -Name CertImport  #unmount drive
    }

}#end function