CD 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
Import-Module .\ConfigurationManager.psd1
New-PSDrive -Name cm01 -PSProvider "AdminUI.PS.Provider\CMSite" -Root "cm01.local.sise" -Description "SCCM Site"

# users names source file, can be .csv or .txt. names can be in these formats: "domain\user.name", "user.name", "user name"
$source = "c:\temp\1909_bit.txt"
$users_raw = (Get-Content $source -encoding utf8).Replace(".", " ").Replace("domain`\", "")
$users_ad = ($users_raw | foreach-object {get-aduser -filter {displayname -like $psitem}}).samaccountname

cd cm01:

# get users primary machines
$pcs = ($users_ad | ForEach-Object {Get-CMUserDeviceAffinity -username ("domain\" + $psitem) | Where-Object {$_.types -like "1"}}).resourcename

# collection name
$collectionname = "Collection Computers Pilot"

#add machines to collection 
$i = 1
$pcs | ForEach-Object {
    Add-CMDeviceCollectionDirectMembershipRule -collectionname $collectionname -resourceid (get-cmdevice -name $psitem).resourceid
    Write-Progress -Activity "Adding to collection $collectionname" -status "$i of $($pcs.count)" -PercentComplete (($i / $pcs.count) * 100)
    $i++
}

