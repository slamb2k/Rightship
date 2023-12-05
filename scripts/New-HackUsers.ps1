<#
    .SYNOPSIS
    Add-HackUsers.ps1

    .DESCRIPTION
    Create Azure Active Directory users/groups from a CSV file.

    .LINK
    github.com/slamb2k/rightship

    .NOTES
    Written by: SIMON LAMB

    .PARAMETER CSVFile
    The CSV file in the supported format that contains the user/group details.
    See the sample file HackUsers.csv for an example.
#>

param(
    [string]$CSVFile = ".\HackUsers.csv"
)

# Connect to Microsoft Graph with user read/write permissions
Connect-MgGraph -Scopes User.ReadWrite.All, Group.ReadWrite.All, Domain.Read.All

# Get the domain name for the tenant
$AADDomain = (Get-MgDomain | Where-Object {$_.isDefault}).Id

# Import data from CSV file
$AADUsers = Import-Csv -Path $CSVFile
$AADGroups = $AADUsers | Group-Object -Property Team

# Construct the group name and display names
$samAccountName = "hack-team$($Group.Name)"
$displayName = "Team $($Group.Name)"

# Create the group
foreach ($Group in $AADGroups) {
    $GroupParams = @{
        DisplayName = $displayName
        MailEnabled = $false
        MailNickName = $samAccountName
        SecurityEnabled = $true
        Description = $displayName
    }

    try {
        # Create the group
        $NewGroup = New-MgGroup @GroupParams -ErrorAction Stop
        Write-Host ("Successfully created the Team {0} group." -f $Group.Name) -ForegroundColor Yellow
    }
    catch {
        Write-Host ("Failed to create the Team {0} group. Error: {1}" -f $Group.Name, $_.Exception.Message) -ForegroundColor Red
    }

    $CreatedUsers = @()

    # Loop through each row containing user details in the CSV file
    foreach ($User in $Group.Group) {
        # Create password profile
        $PasswordProfile = @{
            Password                             = $User.Password
            ForceChangePasswordNextSignIn        = $false
            ForceChangePasswordNextSignInWithMfa = $false
        }

        # Set the properties for the new user
        $UserParams = @{
            DisplayName       = $User.Username
            MailNickName      = $User.Username
            UserPrincipalName = "$($User.Username)@$AADDomain"
            PasswordProfile   = $PasswordProfile
            AccountEnabled    = $true
        }

        try {
            # Create the user and add to the created users array
            $NewUser = New-MgUser @UserParams -ErrorAction Stop
            $CreatedUsers += $NewUser.Id
            Write-Host ("Successfully created the account for {0}" -f $NewUser.DisplayName) -ForegroundColor Green
        }
        catch {
            Write-Host ("Failed to create the account for {0}. Error: {1}" -f $User.Username, $_.Exception.Message) -ForegroundColor Red
        }
    }

    # If no users were created, skip adding them to the group
    if ($CreatedUsers.Count -eq 0) {
        Write-Host ("No users created for the {0} group." -f $NewGroup.DisplayName) -ForegroundColor Yellow
        continue
    }

    # Add the users to the group params so we add them all at once
    $MemberParams = @{
        "members@odata.bind" = @( $CreatedUsers | ForEach-Object { "https://graph.microsoft.com/v1.0/directoryObjects/$($_)" } )
    }
    
    try {
        # Update the group with the members
        Update-MgGroup -GroupId $NewGroup.Id -BodyParameter $MemberParams
        Write-Host ("Successfully added the user accounts to the {0} group." -f $NewGroup.DisplayName) -ForegroundColor White
    }
    catch {
        Write-Host ("Failed to add the user accounts to the {0} group. Error: {1}" -f $NewGroup.DisplayName, $_.Exception.Message) -ForegroundColor Red
    }
    
    # Deploy the resources for the team
    & "$PSScriptRoot\deploy\Deploy.ps1" -TeamNumber $Group.Name -TeamAADGroup $NewGroup.Id
}