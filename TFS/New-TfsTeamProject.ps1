function New-TfsTeamProject{

    <# 
    .SYNOPSIS 
        Create a new project in an on-prem TFS server via tfs REST API
    .PARAMETER TfsCollectionName
        The collection you wish for your project to be located in
    .PARAMETER TfsProjectName
        The name of the new project you are creating.  This should be the production URL of the site you are creating this for
    .PARAMETER TfsProjectType
        Choose between either Git or TFVC for source control.  Git will set an Agile process template, while TFVC will use a Scrum template
    .PARAMETER TfsUserName
        The user name of the account used to validate the request.  This should be in the form of firstname.lastname
    .PARAMETER TfsAuthToken
        The PAT for the username provided.  It should have at least Project and team (read and write) scope authorized.
        For more info, see here https://docs.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/pats?view=vsts
    .PARAMETER $TfsServerUrl
        OPTIONAL. You can update the server url here if desired.  It will default to https://tfs.americaneagle.com
        You must include the full URL and protocol if changing, e.g. http://tfs:8080/tfs
    .EXAMPLE
        Create a project zptest.com in the ecommerce collection using git as a source control provider
        New-TfsTeamProject -TfsCollectionName ecommerce -TfsProjectName zptest.com -TfsProjectType git -TfsUserName zachary.pierce -TfsAuthToken $authToken
    .NOTES 
        @author Zach Pierce
        @modified 12/28/18
    #>  

[CmdletBinding()]param(
    [Parameter(Mandatory=$True)]
    [string]$TfsCollectionName,
    [Parameter(Mandatory=$True)]
    [string]$TfsProjectName,
    [Parameter(Mandatory=$True)][ValidateSet("git","tfvc")]
    [string]$TfsProjectType,
    [Parameter(Mandatory=$True)]
    [string]$TfsUserName,
    [Parameter(Mandatory=$True)]
    [string]$TfsAuthToken,
    [string]$TfsServerUrl = "https://tfs.americaneagle.com"
)

#convert creds into base64 so we can pass via API
$ApiAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $TfsUserName,$TfsAuthToken)))

#set template based on vc method
switch($TfsProjectType){
    git{ $templateTypeId="ADCC42AB-9882-485E-A3ED-7678F01F66BC" } #agile
    tfvc{ $templateTypeId="6B724908-EF14-45CF-84F8-768B5384DA45" } #scrum
    default{ $templateTypeId="ADCC42AB-9882-485E-A3ED-7678F01F66BC" } #agile
}

#create the json body for the post request
$postParams = @{
    name="$TfsProjectName"
    description="Project for $TfsProjectName"
    capabilities=@{
        versioncontrol=@{
            sourceControlType="Git"
        }
        processTemplate=@{
            templateTypeId="$templateTypeId"
        }
    }
} | ConvertTo-Json


#create the project
try{
    $Response = Invoke-RestMethod -Uri "$TfsServerUrl/$TfsCollectionName/_apis/projects?api-version=4.1" -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfo)} -Body $postParams
}catch{
    throw $_
}

write-host "Creating project $TfsServerUrl/$TfsCollectionName/_git/$TfsProjectName"

#wait until project has been created
while( $Response.Status -ne "succeeded" ){

    switch($Response.Status){
        cancelled { throw "Project creation abandoned by user" }
        failed { throw "Failed to create new project!" }
        inProgress { Start-Sleep -Seconds 5}
        notSet { Start-Sleep -Seconds 5}
        queued{ Start-Sleep -Seconds 5}
        succeeded{}
        default { throw "An unknown error occurred, status: $($Response.Status)" }
    }

    $Response = Invoke-RestMethod -Uri $Response.url -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $ApiAuthInfo)}
}

new-object psobject -Property @{status='succeeded';url="$TfsServerUrl/$TfsCollectionName/_git/$TfsProjectName"}

}#end function