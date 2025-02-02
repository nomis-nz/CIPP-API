﻿param($tenant)
if ((Test-Path ".\Cache_Standards\$($Tenant).Standards.json")) {
    $AllowedAppIdsForTenant = (Get-Content ".\Cache_Standards\$($Tenant).Standards.json" -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).Standards.OauthConsent.AllowedApps -split ','
}
else {
    $AllowedAppIdsForTenant = (Get-Content ".\Cache_Standards\AllTenants.Standards.json" -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).Standards.OauthConsent.AllowedApps -split ','
}
try {
    $State = (New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy" -tenantid $tenant)
    if ($State.permissionGrantPolicyIdsAssignedToDefaultUserRole -notin @("ManagePermissionGrantsForSelf.cipp-1sent-policy")) {
        Write-Host "Going to set"
        
        $Existing = (New-GraphGetRequest -Uri "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/" -tenantid $tenant) | Where-Object -Property id -EQ "cipp-consent-policy"
        if (!$Existing) {
            New-GraphPostRequest -tenantid $tenant -Uri "https://graph.microsoft.com/beta/policies/permissionGrantPolicies" -Type POST -Body '{ "id":"cipp-consent-policy", "displayName":"Application Consent Policy", "description":"This policy controls the current application consent policies."}' -ContentType "application/json" 
            New-GraphPostRequest -tenantid $tenant -Uri "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/cipp-consent-policy/includes" -Type POST -Body '{"permissionClassification":"all","permissionType":"delegated","clientApplicationIds":["d414ee2d-73e5-4e5b-bb16-03ef55fea597"]}'  -ContentType "application/json"
        }
        try {
            foreach ($AllowedApp in $AllowedAppIdsForTenant) {
                Write-Host "$AllowedApp"
                New-GraphPostRequest -tenantid $tenant -Uri "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/cipp-consent-policy/includes" -Type POST -Body ('{"permissionType": "delegated","clientApplicationIds": ["' + $AllowedApp + '"]}')  -ContentType "application/json"
                New-GraphPostRequest -tenantid $tenant -Uri "https://graph.microsoft.com/beta/policies/permissionGrantPolicies/cipp-consent-policy/includes" -Type POST -Body ('{ "permissionType": "Application", "clientApplicationIds": ["' + $AllowedApp + '"] }') -ContentType "application/json"
            }
        }
        catch {
            "Could not add exclusions, probably already exist: $($_)"
        }
        New-GraphPostRequest -tenantid $tenant -Uri "https://graph.microsoft.com/beta/policies/authorizationPolicy/authorizationPolicy" -Type PATCH -Body '{"permissionGrantPolicyIdsAssignedToDefaultUserRole":["managePermissionGrantsForSelf.cipp-consent-policy"]}' -ContentType "application/json"
    }
    if ($AllowedAppIdsForTenant) {
    }

    Log-request -API "Standards" -tenant $tenant -message  "Application Consent Mode has been enabled." -sev Info
}
catch {
    Log-request -API "Standards" -tenant $tenant -message  "Failed to apply Application Consent Mode Error: $($_.exception.message)" -sev Error
}