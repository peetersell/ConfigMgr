# update Citrix workspace in software center 

$date = get-date -format "dd/MM/yyyy"
Add-Type -AssemblyName PresentationCore,PresentationFramework
$ErrorActionPreference = Stop

#import configmgr module
CD 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
Import-Module .\ConfigurationManager.psd1
New-PSDrive -Name cm01 -PSProvider "AdminUI.PS.Provider\CMSite" -Root "cm01.domain.local" -Description "SCCM Site"

# function for handling errors
function handle_error($cmdlet, $returned_error) {      
    $errormsg = "$cmdlet `n Returned an error:  `n `n $returned_error"
    [System.Windows.MessageBox]::Show($errormsg)
    break
}

#check for a new version
try {
    $webresponse = invoke-webrequest "https://www.citrix.com/downloads/workspace-app/windows/workspace-app-for-windows-latest.html" 
    $latest_available = (($webresponse.ParsedHtml.body.getElementsByTagName('p') | select innertext | where {$_.innertext -like "version: *"} | get-unique).innertext).split(' ')[1]
    $latest_available
}
catch {
    handle_error $error[0].InvocationInfo.line $error[0].exception.message 
}

# check the newest deployed version in configmr
cd cm01:
$latest_deployed = ((Get-CMApplication "AC - Citrix Workspace App*").softwareversion | Sort-Object)[0]
$latest_deployed
cd c:\

# create the so called main function to call out
function main {
$exe_url = "https:" + (($webresponse.links | where {$_.rel -like "*citrixworkspaceapp.exe*"}).rel | group).name

# copy old source to the new folder
copy-item -Path "\\cm01\sources$\Application Catalog\Software\Citrix Systems\Citrix Workspace App\$latest_deployed" -Destination "\\cm01\sources$\Application Catalog\Software\Citrix Systems\Citrix Workspace App\$latest_available" -Recurse
icacls "\\cm01\sources$\Application Catalog\Software\Citrix Systems\Citrix Workspace App\$latest_available" /grant user.name:f /t

# download the newest exe  
new-psdrive -name citrixsource -root "\\cm01\sources$\Application Catalog\Software\Citrix Systems\Citrix Workspace App\$latest_available" -PSProvider FileSystem
invoke-webrequest -uri $exe_url -OutFile "citrixsource:\citrixworkspaceapp.exe"

cd cm01:

$name = "AC - Citrix Workspace App $latest_deployed"

Function Get-SCCMApplication($name) {
    $smsApp = Get-CMApplication -Name $name
    $currSDMobj = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($smsapp.SDMPackageXML)
    return $currSDMobj
 }

Function Set-SCCMApplication($name, $app) {
    $smsApp = Get-CMApplication -Name $name
    $currSDMXmlNew = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::SerializeToString($app)
    $smsApp.SDMPackageXML = $currSDMXmlNew                                                                            
    Set-CMApplication -InputObject $smsApp 
 }

 
function Copy-SCCMApplication {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Source,
        [Parameter(Position=1)]
        [System.String]
        $Destination = "$Source - Copy"        
    )

    New-CMApplication -Name $Destination
    $oldSDM = Get-SCCMApplication -name $Source
    $newSDM = Get-SCCMApplication -name $Destination
    $newSDM.CopyFrom($oldSDM)
    $newSDM.DeploymentTypes.ChangeId()
    $newSDM.Title = $Destination
    Set-SCCMApplication -name $Destination -app $newSDM   
  }

# call out the copy function
try {
    Copy-SCCMApplication("AC - Citrix Workspace App $latest_deployed") 
} catch {
    handle_error $error[0].InvocationInfo.line $error[0].exception.message 
}

# rename the app from old to new in configmgr
Set-CMApplication -name "AC - Citrix Workspace App $latest_deployed - Copy" -NewName "AC - Citrix Workspace App $latest_available" -SoftwareVersion $latest_available

# create the new version folder in configmgr
new-item -name $latest_available -path ".\application\application catalog\software\citrix systems\citrix workspace app"

# move the app to that folder in configmgr
Get-CMApplication -name "AC - Citrix Workspace App $latest_available" | move-cmobject -folderpath ".\application\application catalog\software\citrix systems\citrix workspace app\$latest_available" -verbose 

# deployment detection script 
$detectionscript = "if ((Test-Path ""hklm:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CitrixOnlinePluginPackWeb"") -And (get-itemproperty ""HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CitrixOnlinePluginPackWeb"" -name ""DisplayVersion"" -erroraction silentlycontinue | select -ExpandProperty DisplayVersion) -eq ""$latest_available"") {
	write-output ""installed""
} else {

}"

# rename the deployment type to the new version, update detection script
Set-CMScriptDeploymentType -ApplicationName "AC - Citrix Workspace App $latest_available" -DeploymentTypeName "Citrix Workspace App" `
–ContentLocation "\\cm01\sources$\Application Catalog\Software\Citrix Systems\Citrix Workspace App\$latest_available" -ScriptLanguage PowerShell -scripttext $detectionscript -Verbose

# distribute the content
try {
    Start-CMContentDistribution -ApplicationName "AC - Citrix Workspace App $latest_available" -DistributionPointGroupName "All Content" -Verbose

    # deploy it for the test collection
    New-CMApplicationDeployment -CollectionName “TESTIKAS” -Name "AC - Citrix Workspace App $latest_available" -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll 
} catch {
    handle_error $error[0].InvocationInfo.line $error[0].exception.message 
}

cd c:\
}

# If there is a new version, call out the main function. If not, do nothing
if ([version]$latest_available -gt [version]$latest_deployed) {
    main
} else {
    Write-Output "There is no newer version available"
}


