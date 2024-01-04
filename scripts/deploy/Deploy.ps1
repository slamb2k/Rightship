<#
    .SYNOPSIS
    Deploy.ps1

    .DESCRIPTION
    Provision the necessary resources for a RightShip Hackathon team

    .LINK
    github.com/slamb2k/rightship

    .NOTES
    Written by: SIMON LAMB

    .PARAMETER TeamNumber
    The index of the team to deploy

    .PARAMETER TeamAADGroup (optional)
    The name of an AAD group to assign as a Reader to the resource group
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$TeamNumber,

    [Parameter]
    [string] $TeamAADGroup
)

# Stop on any error
$ErrorActionPreference = "Stop"

# Set the current directory to the script directory
$templateFile = "$($PSScriptRoot)/main.bicep"

Write-Host "Running Bicep Main deployment file for Team $TeamNumber resources..."
$bicepOutput=$(az deployment sub create --location "southeastasia" --template-file $templateFile --parameters teamNumber=$TeamNumber --only-show-errors) | ConvertFrom-Json

if (!$bicepOutput) {
    throw "Deployment failed, check errors on Azure portal"
}

# Record the output to a file for debug purposes
Set-Content -Path "output.json" -Value $bicepOutput

# Get the unique resource group name generated
$resourceGroupName=$bicepOutput.properties.outputs.resourceGroupName.value

Write-Host "Bicep deployment. Done"

if (!TeamAADGroup) {
    Write-Host "No team AAD group specified, skipping assignment of resource group reader permissions"
}

Write-Host "Assigning resource group reader permissions to team"
az role assignment create --role "Reader" --assignee $TeamAADGroup --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/${resourceGroupName}${TeamNumber}"

Write-Host "Permissions assignment. Done"