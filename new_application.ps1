# new application
Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-Location "$($SiteCode.Name):\"

$publisher = Read-Host -Prompt "Software publisher (not mandatory)"
$soft_name = read-host -Prompt "Software name"
$soft_version = Read-Host -Prompt "Software version"
$localized_desc = Read-Host -Prompt "SC localized description"
$install_command = "$soft_name`_install.cmd"
$uninstall_command = "$soft_name`_uninstall.cmd"


function app_folder {
    param (
        $soft_name, $soft_version, $publisher
    )
    cd c:\
    if (!$publisher -eq $null) {
        md "\\cm01\sources$\Application Catalog\Software\$publisher\$soft_name\$soft_version"
        new-item "\\cm01\sources$\application catalog\software\$publisher\$soft_name\$soft_version\$install_command"
        new-item "\\cm01\sources$\application catalog\software\$publisher\$soft_name\$soft_version\$uninstall_command"
    icacls "\\cm01\sources$\Application Catalog\Software\$publisher" /grant peeter.kraas:f /t
    } else {
        md "\\cm01\sources$\Application Catalog\Software\$soft_name\$soft_version"
        new-item "\\cm01\sources$\application catalog\software\$soft_name\$soft_version\$install_command"
        new-item "\\cm01\sources$\application catalog\software\$soft_name\$soft_version\$uninstall_command"
    icacls "\\cm01\sources$\Application Catalog\Software\$soft_name" /grant peeter.kraas:f /t
    }
    
    cd "$($SiteCode.Name):\"
    new-item ".\application\application catalog\software\$publisher"
    new-item ".\application\application catalog\software\$publisher\$soft_name"
    new-item ".\application\application catalog\software\$publisher\$soft_name\$soft_version"
}

app_folder -soft_name $soft_name -soft_version $soft_version -publisher $publisher

[System.Reflection.Assembly]::LoadFrom((Join-Path (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName "Microsoft.ConfigurationManagement.ApplicationManagement.dll")) | Out-Null
[System.Reflection.Assembly]::LoadFrom((Join-Path (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName "Microsoft.ConfigurationManagement.ApplicationManagement.MsiInstaller.dll")) | Out-Null
 
# Variables
$SiteServer = "cm01.domain.sise"
$SiteCode = "PS1"
if (!$publisher -eq $null) {
    $ContentSourcePath = "\\cm01\sources$\Application Catalog\Software\$publisher\$soft_name\$soft_version"
} else {
    $ContentSourcePath = "\\cm01\sources$\Application Catalog\Software\$soft_name\$soft_version"
}
$ApplicationTitle = $soft_name
$ApplicationVersion = 1.0
$ApplicationSoftwareVersion = $soft_version
$ApplicationLanguage = (Get-Culture).Name
$ApplicationDescription = $localized_desc
$ApplicationPublisher = $publisher
$DeploymentInstallCommandLine = $install_command
$DeploymentUninstallCommandLine = $uninstall_command
 
# Get ScopeID
$GetIdentification = [WmiClass]"\\$($SiteServer)\root\SMS\Site_$($SiteCode):SMS_Identification"
$ScopeID = "ScopeId_" + $GetIdentification.GetSiteID().SiteID -replace "{","" -replace "}",""
 
# Create unique ID for application and deployment type
$ApplicationID = "APP_" + [GUID]::NewGuid().ToString()
$DeploymentTypeID = "DEP_" + [GUID]::NewGuid().ToString()
 
# Create application objects
$ObjectApplicationID = New-Object Microsoft.ConfigurationManagement.ApplicationManagement.ObjectId($ScopeID,$ApplicationID)
$ObjectDeploymentTypeID = New-Object Microsoft.ConfigurationManagement.ApplicationManagement.ObjectId($ScopeID,$DeploymentTypeID)
$ObjectApplication = New-Object Microsoft.ConfigurationManagement.ApplicationManagement.Application($ObjectApplicationID)
$ObjectDeploymentType = New-Object Microsoft.ConfigurationManagement.ApplicationManagement.DeploymentType($ObjectDeploymentTypeID,"MSI")
 
# Add content to the Application
<# $ApplicationContent = [Microsoft.ConfigurationManagement.ApplicationManagement.ContentImporter]::CreateContentFromFolder($ContentSourcePath)
$ApplicationContent.OnSlowNetwork = [Microsoft.ConfigurationManagement.ApplicationManagement.ContentHandlingMode]::DoNothing
$ApplicationContent.OnFastNetwork = [Microsoft.ConfigurationManagement.ApplicationManagement.ContentHandlingMode]::Download #>
 
# Application information
$ObjectDisplayInfo = New-Object Microsoft.ConfigurationManagement.ApplicationManagement.AppDisplayInfo
$ObjectDisplayInfo.Language = $ApplicationLanguage
$ObjectDisplayInfo.Title = $ApplicationTitle
$ObjectDisplayInfo.Description = $ApplicationDescription
$ObjectApplication.DisplayInfo.Add($ObjectDisplayInfo)
$ObjectApplication.DisplayInfo.DefaultLanguage = $ApplicationLanguage
$ObjectApplication.Title = $ApplicationTitle
$ObjectApplication.Version = $ApplicationVersion
$ObjectApplication.SoftwareVersion = $ApplicationSoftwareVersion
$ObjectApplication.Description = $ApplicationDescription
$ObjectApplication.Publisher = $ApplicationPublisher
 
# DeploymentType configuration
<# $ObjectDeploymentType.Title = $ApplicationTitle
$ObjectDeploymentType.Version = $ApplicationVersion
$ObjectDeploymentType.Enabled = $true
$ObjectDeploymentType.Description = $ApplicationDescription
$ObjectDeploymentType.Installer.Contents.Add($ApplicationContent)
$ObjectDeploymentType.Installer.InstallCommandLine = $DeploymentInstallCommandLine
$ObjectDeploymentType.Installer.UninstallCommandLine = $DeploymentUninstallCommandLine
$ObjectDeploymentType.Installer.ProductCode = "{" + [GUID]::NewGuid().ToString() + "}"
$ObjectDeploymentType.Installer.DetectionMethod = [Microsoft.ConfigurationManagement.ApplicationManagement.DetectionMethod]::ProductCode #>
 
# Add DeploymentType to Application
#$ObjectApplication.DeploymentTypes.Add($ObjectDeploymentType)
 
# Serialize the Application
$ApplicationXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::SerializeToString($ObjectApplication)
$ApplicationClass = [WmiClass]"\\$($SiteServer)\root\SMS\Site_$($SiteCode):SMS_Application"
$ObjectApplication = $ApplicationClass.CreateInstance()
$ObjectApplication.SDMPackageXML = $ApplicationXML
$Temp = $ObjectApplication.Put()
$ObjectApplication.Get()

Get-CMApplication -name $soft_name | move-cmobject -folderpath ".\application\application catalog\software\$publisher\$soft_name\$soft_version"


Add-CMScriptDeploymentType -ContentLocation $ContentSourcePath -DeploymentTypeName $soft_name -InstallCommand $install_command -ApplicationName $soft_name -ScriptText "blabla" `
-ScriptLanguage PowerShell -UserInteractionMode Hidden -UninstallCommand $uninstall_command -LogonRequirementType WhetherOrNotUserLoggedOn -InstallationBehaviorType InstallForSystem


#pritsime dp-dele laiali
#start-cmcontentdistribution -ApplicationName "AC - Docker Desktop" -Distributionpointgroupname ""

#deployme applicationi
#New-CMApplicationDeployment -CollectionName "TESTIKAS" -Name "AC - Docker Desktop" -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -AvailableDateTime (get-date) -TimeBaseOn LocalTime -Verbose
