cls

# Define the label
$label = "backup-drive-001" #label of USB Stick used
# Define the Paths to Backup
$dir = @(
         @("Pictures", "C:\Users\$Env:Username\Pictures"),
         @("Documents", "C:\Users\$Env:Username\Documents")
       )
#---------------------------------------------------------------
Write-Host "Waiting for the Drive '$label'." -ForegroundColor Cyan
while($true) {
    $drive = (Get-PSDrive -PSProvider FileSystem | Where-Object Description -EQ $label).Name 
    if($drive -match '[A-Z]') {
         write-host "Success: The drive '$label' was found, with the drive letter '$drive'." -ForegroundColor Green
         continue
    } else {
         write-host "Searching..."
    }
sleep(1)
}
Write-Host "Starting Backup..." -ForegroundColor Cyan
foreach($i in $dir) {
    $path = $i[1]
    $name = $i[0]
    if(Test-Path $path) {
        xcopy $path $drive":\"$Env:COMPUTERNAME"\"$name"\" /c /e /h /y # ignore errors, copy subdirectorys, copy hidden files, suppress warnings
    } else {
        Write-Host "$path was not found!" -ForegroundColor Red
    }
}
Write-Host "Backup Successfull." -ForegroundColor Green
sleep(3)
exit
