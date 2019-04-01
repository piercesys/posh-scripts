function Rename-TfsTeamProject{

    <# 
    .SYNOPSIS 
        Create a new project in an on-prem TFS server via tfs REST API
    .PARAMETER TfsCollectionName
        The collection your project is located in
    .PARAMETER TfsProjectNameOld
        The name of the new project you are renaming.
    .PARAMETER TfsProjectNameNew
        The new name you want your team project to be called
    .PARAMETER TfsUserName
        The user name of the account used to validate the request.  This should be in the form of firstname.lastname
    .PARAMETER TfsAuthToken
        The PAT for the username provided.  It should have at least Project and team (read, write and manage) scope authorized.
        For more info, see here https://docs.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/pats?view=vsts
    .PARAMETER $TfsServerUrl
        OPTIONAL. You can update the server url here if desired.  It will default to http://pr-tfs-4as01:8080/tfs
        You must include the full URL and protocol if changing, e.g. http://tfs:8080/tfs
    .EXAMPLE
        Rename the project zptest.com in the ecommerce collection to www.zptest.com
        New-TfsTeamProject -TfsCollectionName ecommerce -TfsProjectNameOld zptest.com -TfsProjectNameNew www.zptest.com -TfsUserName zachary.pierce -TfsAuthToken $authToken
    .NOTES 
        @author Zach Pierce
        @modified 12/28/18
    #>  

[CmdletBinding()]param(
    [Parameter(Mandatory=$True)]
    [string]$TfsCollectionName,
    [Parameter(Mandatory=$True)]
    [string]$TfsProjectNameOld,
    [Parameter(Mandatory=$True)]
    [string]$TfsProjectNameNew,
    [Parameter(Mandatory=$True)]
    [string]$TfsUserName,
    [Parameter(Mandatory=$True)]
    [string]$TfsAuthToken,
    [string]$TfsServerUrl = "http://pr-tfs-4as01:8080/tfs",
    [int]$ProjectResultCount = 1000
)

#convert creds into base64 so we can pass via API
$ApiAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $TfsUserName,"$TfsAuthToken")))

$ProjectListResponse = Invoke-RestMethod -Uri "$TfsServerUrl/$TfsCollectionName/_apis/projects?&`$top=$ProjectResultCount" -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfo)}
$ProjectId = ($ProjectListResponse.value | ?{$_.name -eq "$TfsProjectNameOld"}).id

if($ProjectId -eq $NULL){
    throw "Unable to find project $TfsProjectNameOld.  Please verify it is in the collection $TfsCollectionName, or try increasing ProjectResultCount if there are more than 1000 projects in this collection"
}

#create the json body for the patch request
$postParams = @{name="$TfsProjectNameNew"} | ConvertTo-Json


#rename the project
try{
    $Response = Invoke-RestMethod -Uri "$TfsServerUrl/$TfsCollectionName/_apis/projects/$($ProjectId)?api-version=3.2" -Method Patch -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfo)} -Body $postParams
}catch{
    throw $_
}

write-host "Renaming project $TfsServerUrl/$TfsCollectionName/$TfsProjectNameOld to $TfsProjectNameNew"

new-object psobject -Property @{status='succeeded';url="$TfsServerUrl/$TfsCollectionName/$TfsProjectNameNew"}

}#end function

#Rename-TfsTeamProject -TfsCollectionName ecommerce -TfsProjectNameOld "Tom M Octo Design_migrated" -TfsProjectNameNew "Tom M Octo Design" -TfsUserName zachary.pierce -TfsAuthToken "ypfuqwp5ed44poesgat7y5hjwnwmvcyiooheeni5bow3yeiun3oa"