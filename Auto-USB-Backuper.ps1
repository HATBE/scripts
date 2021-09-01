cls

# Define the label
$label = "34BH88FRL9" #label of USB Stick used
# Define the Paths to Backup
$dir = @(@("Pictures", "C:\Users\$Env:Username\Pictures"),
         @("Documents", "C:\Users\$Env:Username\Documents")
       )
#---------------------------------------------------------------
Write-Host "Waiting for the Drive '$label'." -ForegroundColor Cyan
while($true) {
    $drive = (Get-PSDrive -PSProvider FileSystem | Where-Object Description -EQ $label).Name 
    if($drive -match '[A-Z]') {
        continue
    } else {
        write-host "Searching..."
    }
sleep(1)
}
write-host "Success: The drive '$label' was found, with the letter '$drive'." -ForegroundColor Green
Write-Host "Starting Backup..." -ForegroundColor Cyan
foreach($i in $dir) {
    $path = $i[1]
    $name = $i[0]
    if(Test-Path $path) {
        xcopy $path $drive":\"$Env:COMPUTERNAME"\"$name"\" /c /e /h /y # ignore errors, copy subdirectorys, ?, ?
    } else {
        Write-Host "$path was not found!" -ForegroundColor Red
    }
}
Write-Host "Backup Successfull." -ForegroundColor Green
sleep(3)
exit
