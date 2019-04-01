function Migrate-TfsTeamProject{

[CmdletBinding()]param(
    [Parameter(Mandatory=$True)]
    [string]$TfsCollectionOld,
    [Parameter(Mandatory=$True)]
    [string]$TfsProjectOld,
    [Parameter(Mandatory=$True)]
    [string]$TfsBranchOld,
    [Parameter(Mandatory=$True)]
    [string]$TfsCollectionNew,
    [Parameter(Mandatory=$True)]
    [string]$TfsProjectNew,
    [Parameter(Mandatory=$True)]
    [string]$TfsUserName,
    [Parameter(Mandatory=$True,HelpMessage="Enter your API key for pr-tfs-4as01")][ValidateLength(52,52)] #Code (read), Project and team (read, write, and manage)
    [string]$TfsAuthTokenOld,
    [Parameter(Mandatory=$True,HelpMessage="Enter your API key for tfs.americaneagle.com")][ValidateLength(52,52)] #Code (read, write, and manage), Project and team (read, write, and manage)
    [string]$TfsAuthTokenNew,
    [string]$TfsServerUrlOld = "http://pr-tfs-4as01:8080/tfs",
    [string]$TfsServerUrlNew = "https://tfs.americaneagle.com",
    [string]$LocalFilePath = "C:\inetpub\wwwroot"
)

#start a timer so we can see how long these guys are running
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

#Convert credentials to base64 string so that we can use them in API headers
$ApiAuthInfoOld = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $TfsUserName,$TfsAuthTokenOld)))
$ApiAuthInfoNew = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $TfsUserName,$TfsAuthTokenNew)))

#ensure they have git and git-tfs installed
try{
    Start-Process git -NoNewWindow -ErrorAction stop
}catch{
    $stopwatch.Stop()
    throw @"
    git is not installed on the current machine, please ensure it has been installed and the environment variables properly assigned
    https://git-scm.com/download/win
"@
}
try{
    Start-Process git-tfs -NoNewWindow -ErrorAction stop
}catch{
    $stopwatch.Stop()
    throw @"
    git-tfs is not installed on the current machine, please ensure it has been installed and the environment variables properly assigned
    http://git-tfs.com/
"@
}

#Create the new team project
try{
    $NewProject = New-TfsTeamProject -TfsCollectionName $TfsCollectionNew -TfsProjectName $TfsProjectNew -TfsProjectType git -TfsUserName $TfsUserName -TfsAuthToken $TfsAuthTokenNew -ErrorAction Stop
    if($NewProject.status -eq 'succeeded'){
        $NewProjectUrl = $NewProject.url
    }else{
        $stopwatch.Stop()
        throw "Error creating new project, $NewProject"
    }
}catch{
    $stopwatch.Stop()
    throw "Unable to create new team project! $_"
}

<# Yea, on second thought we're not guessing this, they can provide it.
#get the old branches
try{
    #$Branches = Invoke-RestMethod -Uri "$TfsServerUrlOld/$TfsCollectionOld/$TfsProjectOld/_apis/tfvc/branches" -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfoOld)} #can return 0 if there are no branches
    $Branches = Invoke-RestMethod -Uri "$TfsServerUrlOld/$TfsCollectionOld/$TfsProjectOld/_apis/tfvc/items" -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfoOld)}
}catch{
    $stopwatch.Stop()
    throw "Unable to connect query old TFS server. Was this TFVC?  $_"
}

$MainBranch = $Branches.value[4].path #item 0 will always be trunk
#>

$MainBranch = "`$/$TfsProjectOld/$TfsBranchOld"

write-host "Main branch is $MainBranch"
$LocalMapPath = "$LocalFilePath\$TfsProjectNew"

#confirm local path is clear for cloning
$message  = "Directory Exists!"
$question = @"
$LocalMapPath already exists
Do you want to delete the current directory?
(Selecting 'no' will just append to the name, not terminate the script)
"@
$i=0

while ( (Get-ChildItem $LocalMapPath -ErrorAction SilentlyContinue).Count -gt 0 ){
    $i++
    
    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

    if ($decision -eq 0){
        Remove-Item "$LocalMapPath" -Recurse -Force -Verbose
    }else{
        Write-Host "Mapping to $LocalMapPath$i"
        $LocalMapPath = "$LocalMapPath$i"
    }
}

#clone project down to local

try{
    #git-tfs clone "$TfsServerUrlOld/$TfsCollectionOld" $MainBranch $LocalMapPath --branches=all #branches=all expects there to be branches.  This can be an issue if everything is just maintained in trunk
    git-tfs clone "$TfsServerUrlOld/$TfsCollectionOld" $MainBranch $LocalMapPath --branches=auto #branches=auto will work with a trunk folder or single branch
}
catch{
    throw $_
}

cd $LocalMapPath

git tfs verify
git gc --auto

#fix authors names
#C:\"Program Files (x86)"\"Microsoft Visual Studio"\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\"Team Explorer"\tf.exe history $/$TfsProject -recursive > AUTHORS_TMP  #waaaaay too long, also unneeded.

#strip out git headers from comments
#git filter-branch -f --msg-filter 'sed "s/^git-tfs-id:.*$//g"' '--' --all
git filter-branch -f --msg-filter 'sed "s/git-tfs-id:.*$//g"' -- --all
#git filter-branch -f --msg-filter "sed 's/^git-tfs-id:.*;C\([0-9]*\)$/Changeset:\1/g'" -- --all

#Copy-Item -Path "C:\inetpub\.gitignore" "$LocalMapPath\.gitignore"
if(!(Test-Path "$LocalMapPath\.gitignore")){
    #invoke-webrequest -uri "https://gitlab.idevdesign.net/zachary.pierce/gitignore/raw/master/.gitignore" -outfile "$LocalMapPath\.gitignore"
}
#add and push
try{
git config --local core.excludesfile false  #for all those tasty third party dlls
git remote add origin $NewProjectUrl
git push --all origin
git add .gitignore
git commit -m "added .gitignore"
git push -u origin master

}catch{
    $stopwatch.Stop()
    throw @"
    unable to commit changes, please add manually:
    cd $LocalMapPath
    git remote add origin $NewProjectUrl
    git push --all origin
"@
}

cd $LocalFilePath

$stopwatch.Stop()

$OldProjectMigratedName = "$($TfsProjectOld)_MIGRATEDTO_tfs.americaneagle.com-$TfsCollectionNew"
#max length is 64 char
if ($OldProjectMigratedName.Length -gt 64){
    $OldProjectMigratedName = $OldProjectMigratedName[0..64] -join ""
}

try{
    echo "renaming old project to $OldProjectMigratedName"
    #$OldProject = Rename-TfsTeamProject -TfsCollectionName $TfsCollectionOld -TfsProjectNameOld $TfsProjectOld -TfsProjectNameNew $OldProjectMigratedName -TfsUserName $TfsUserName -TfsAuthToken $TfsAuthTokenOld
}catch{
    throw "Unable to rename old team project, please rename $TfsServerUrlOld/$TfsCollectionOld/$TfsProjectOld manually to $($TfsProjectOld)_migrated"
}

return @{
    status="success"
    newUrl="$NewProjectUrl"
    oldUrl="$($OldProject.Url)"
    time="$($stopwatch.Elapsed)"
}

}#end function