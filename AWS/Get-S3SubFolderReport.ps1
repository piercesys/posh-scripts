$BucketName = "awsroc.roccommerce.net"
$Report = @()
$PythonDir = "C:\Python32\scripts"

cd $PythonDir

$S3SubDirs = Get-S3Directories -BucketName $BucketName #main folders
$S3FilesSubDirs = Get-S3Directories -BucketName $BucketName -KeyPrefix files/ #files subdirs

$S3SubDirs | ?{$_ -notlike 'files/'} | ForEach-Object {
    
    echo "Checking s3://$BucketName/$_"

    $s3cmd = cmd /c "aws s3 ls --summarize --recursive s3://$BucketName/$_"

    $ObjectCount = ($s3cmd | Select-String -Pattern "Total Objects: *").ToString()
    $Size = ($s3cmd | Select-String -Pattern "Total Size: *").ToString()

    $pos1 = $Size.IndexOf(":")
    [int64]$SizeString = $Size.Substring($pos1+2)

    $pos2 = $ObjectCount.IndexOf(":")
    [int64]$ObjectString = $ObjectCount.Substring($pos2+2)

    $FolderObject = New-Object PSObject -Property @{
        Name = $_
        Size = $SizeString
        Count = $ObjectString
    }

    $Report += $FolderObject

}

$S3FilesSubDirs | ForEach-Object {

    echo "Checking s3://$BucketName/$_"

    $s3cmd = cmd /c "aws s3 ls --summarize --recursive s3://$BucketName/$_"

    $ObjectCount = ($s3cmd | Select-String -Pattern "Total Objects: *").ToString()
    $Size = ($s3cmd | Select-String -Pattern "Total Size: *").ToString()

    $pos1 = $Size.IndexOf(":")
    [int64]$SizeString = $Size.Substring($pos1+2)

    $pos2 = $ObjectCount.IndexOf(":")
    [int64]$ObjectString = $ObjectCount.Substring($pos2+2)

    $FolderObject = New-Object PSObject -Property @{
        Name = $_
        Size = $SizeString
        Count = $ObjectString
    }

    $Report += $FolderObject

}

$Report | sort size | Export-Csv -NoTypeInformation -Path C:\temp\roc-assets_$(Get-Date -Format yyyyMMddhhmm).csv

return $Report | sort size