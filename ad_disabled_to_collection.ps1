$disabled_pcs = (Get-ADComputer -filter * -SearchBase "OU=DISABLED COMPUTERS,OU=DELETE,DC=DOMAIN,DC=LOCAL").name

Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-Location "$($SiteCode.Name):\"

$disabled_pcs | ForEach-Object {Add-CMDeviceCollectionDirectMembershipRule -collectionid PS100108 -resourceid (get-cmdevice -name $psitem).resourceid}