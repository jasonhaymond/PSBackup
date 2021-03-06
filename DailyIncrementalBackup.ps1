﻿#requires -version 5.1

#backup files from CSV change logs

<#
option to get last version of each file as an alternative to using Group-Object

foreach ($name in (Import-CSV D:\Backup\Scripts-log.csv -OutVariable in | Select-Object Name -Unique).name) {
 $in | where {$_.name -EQ $name} | sort-object -Property ID | Select-Object -last 1
}
#>

#this is my internal archiving code. You can use whatever you want.
Import-Module C:\scripts\PSRAR\Dev-PSRar.psm1 -force

$paths = Get-ChildItem -Path D:\Backup\*.csv | Select-Object -ExpandProperty Fullname

foreach ($path in $paths) {

    $name = (Split-Path -Path $Path -Leaf).split("-")[0]
    $files = Import-Csv -path $path | Where-Object { ($_.name -notmatch "~|\.tmp") -AND ($_.size -gt 0) -AND ($_.IsFolder -eq 'False') -AND (Test-Path $_.path) } |
        Select-Object -Property path, size, directory, isfolder, ID | Group-Object -Property Path

    foreach ($file in $files) {
        $parentFolder = $file.group[0].directory
        $relPath = Join-Path -Path "D:\backtemp\$Name" -childpath $parentFolder.Substring(3)
        if (-Not (Test-Path -path $relpath)) {
            Write-Host "Creating $relpath" -ForegroundColor cyan
            $new = New-Item -path $relpath -ItemType directory -force
            # Start-Sleep -Milliseconds 100

            #copy hidden attributes
            $attrib = (Get-Item $parentfolder -force).Attributes
            if ($attrib -match "hidden") {
                Write-Host "Copying attributes from $parentfolder to $($new.FullName)" -ForegroundColor yellow
                Write-Host $attrib -ForegroundColor yellow
                (Get-Item $new.FullName -force).Attributes = $attrib
            }
        }
        Write-Host "Copying $($file.name) to $relpath" -ForegroundColor green
        $f = Copy-Item -Path $file.Name -Destination $relpath -Force -PassThru
        #copy attributes
        $f.Attributes = (Get-Item $file.name -force).Attributes
    } #foreach file

    #create a RAR archive or substitute your archiving code
    $archive = Join-Path D:\BackTemp -ChildPath "$(Get-Date -Format yyyyMMdd)_$name-INCREMENTAL.rar"
    Add-RARContent -Object $relPath -Archive $archive -CompressionLevel 5 -Comment "Incremental backup $(Get-Date)"
    #move the file to my NAS
    Move-Item -Path $archive -Destination \\ds416\backup -Force

    Remove-Item $relPath -Force -Recurse
    Remove-Item $path

} #foreach path