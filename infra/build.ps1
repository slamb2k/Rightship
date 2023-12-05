<#
    .SYNOPSIS
    Build-HackUsers.ps1

    .DESCRIPTION
    Create Azure Active Directory users/groups from a CSV file.

    .LINK
    github.com/slamb2k/rightship

    .NOTES
    Written by: SIMON LAMB

    .PARAMETER TeamNumber
    The index of the team to deploy
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$TeamNumber,

    [Parameter(Mandatory=$true)]
    [string] $TeamAADGroup
)

Push-Location $PSScriptRoot

Write-Host "Running Bicep Main deployment file for Team $TeamNumber resources..."
$result=$(az deployment sub create --location "southeastasia" --template-file "main.bicep" --parameters teamNumber=$TeamNumber --only-show-errors) | ConvertFrom-Json
$resourceGroupName=$result.properties.outputs.resourceGroupName.value

if (!$bicepOutput) {
    throw "Deployment failed, check errors on Azure portal"
}

Set-Content -Path "output.json" -Value $bicepOutput # save output

Write-Host "Assigning resource group reader permissions to team"
az role assignment create --role "Reader" --assignee $TeamAADGroup --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/${resourceGroupName}${TeamNumber}"

Write-Host "Bicep deployment. Done"
Pop-Location
