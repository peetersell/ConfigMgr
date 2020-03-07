$ErrorActionPreference = "Stop"
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function check_new_virtual_machines {
    
CD 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
Import-Module .\ConfigurationManager.psd1
if (get-psdrive cm01 -ErrorAction SilentlyContinue) {
} else {
    New-PSDrive -Name cm01 -PSProvider "AdminUI.PS.Provider\CMSite" -Root "cm01.domain.local" -Description "SCCM Site"
}

function handle_error($cmdlet, $returned_error) {      
    $errormsg = "$cmdlet `n Returned an error:  `n `n $returned_error"
    [System.Windows.Forms.MessageBox]::Show($errormsg)
    #zabbix failed
    $errormsg | out-file c:\automaatika\error.txt
    $escapeparser = "--%"
    & "C:\Program Files\Zabbix\zabbix_sender.exe" $escapeparser -z monitooring.plcaeholder.sise -s watchdog.plcaeholder.sise -k "trapperkey[FAULT_LOG]" -o "$PSCommandPath failed."
    break
}

cd cm01: 

$wql = @"
select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System where SMS_R_System.IsVirtualMachine = "1"
"@

try {
     $fresh_virtual_machines = Invoke-CMWmiQuery -Query $wql
     $new_virt_machines = $fresh_virtual_machines | Where-Object {!((get-content C:\automaatika\virtukad.txt) -contains $PSItem.name)}
     $machines_primary_users = $new_virt_machines | Select-Object name, @{N='primary user';E={ForEach-Object {get-cmuserdeviceaffinity -devicename $psitem.name | Where-Object {$_.types -like "*1*"} | select -ExpandProperty uniqueusername}}}
}
catch {
    handle_error $error.InvocationInfo.line[0] $error.exception.message[0]
}

if (!$machines_primary_users) {
    Write-Output "no new virtual machines"
} else {
    $machines_primary_users.name | add-content C:\automaatika\virtukad.txt
    try {
      Send-MailMessage -To "security.reports@plcaeholder.ee", "peeter.kraas@plcaeholder.ee" -From "configmgr@plcaeholder.ee"  -Subject "Detected new virtual machine" -Body "Detected new virtual machine `n $($machines_primary_users | out-string) " `
       -SmtpServer "stmp.plcaeholder.sise" -Port 25
        #zabbix ok
       $escapeparser = "--%"
    & "C:\Program Files\Zabbix\zabbix_sender.exe" $escapeparser -z monitooring.plcaeholder.sise -s watchdog.plcaeholder.sise -k "trapperkey[virtual_workstation]" -o 1
    }
    catch {
        handle_error $error.InvocationInfo.line[0] $error.exception.message[0]
    }
}
}

$ping_response = 0 
    while ($ping_response -eq 0) {
    # cm01 ping check
    if ((Test-Connection cm01 -quiet) -ne $True) {
    Write-Output "cm01 not pinging"
    Start-Sleep -Seconds 60
    } else {
    check_new_virtual_machines
    $ping_response = 1
    }
}

