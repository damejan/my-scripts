#!/usr/bin/env pwsh

function GetRandomIDsArray(){
    $array = @()
    $WebResponse = Invoke-WebRequest "https://wallhaven.cc/random"

    if([bool]($WebResponse.PSobject.Properties.name -match "AllElements")){ # powershell desktop(only windows)
        # get all IDs from figure tags and add them to array
        ForEach ($figureTag in $WebResponse.AllElements | Where-Object {$_.TagName -eq "figure"}) {
            $array += $figureTag.'data-wallpaper-id'
        }
    } else {# powershell core
        # get all href from a tags that have class="preview"
        ForEach ($link in $WebResponse.Links ) {
            if($link.class -eq "preview"){
                # cut id from the link
                $array += $link.href.Substring($link.href.Length - 6)
            }
        }
    }
    
    return $array
}

function GetWallpaperURL() {
    # get random id from array
    $RandomIDsArr = GetRandomIDsArray
    $RandomIndex = Get-Random -Minimum 0 -Maximum $RandomIDsArr.Count
    $id = $RandomIDsArr[$RandomIndex]

    $WallpaperURL = ""

    $WebResponse = Invoke-WebRequest "https://wallhaven.cc/w/$id"

    if($PSVersionTable.PSEdition -eq "Desktop" -Or $IsWindows){
        ForEach ($Img in $WebResponse.Images) {
            # if img has the id property
            if([bool]($Img.PSobject.Properties.name -match "id")){
                # and if id="wallpaper"
                if([bool]($Img.id -eq "wallpaper")){
                    $WallpaperURL = $Img.src
                }
            }
        }
    } else {
        # get all src properties
        $matchesArr = $WebResponse.Content | Select-String 'src\s*=\s*"(.+?)"' -AllMatches | ForEach-Object { $_.Matches.Value }
        #find a link to the wallpaper
        ForEach ($string in $matchesArr) {
            if($string -match "full"){
                $WallpaperURL = $string.Substring(5)
                $WallpaperURL = $WallpaperURL.Substring(0, $WallpaperURL.Length - 1)
            }
        }
    }

    return $WallpaperURL
}

function ChangeWallpaper(){
    if($PSVersionTable.PSEdition -eq "Desktop" -Or $IsWindows){
        $url = GetWallpaperURL
        $fileExtension = $url.Substring($url.Length - 3)
    
        # download wallpaper
        Invoke-WebRequest $url -OutFile "$env:HOMEDRIVE$env:HOMEPATH\wallpaper.$fileExtension"
    
        # remove old wallpaper
        Remove-ItemProperty -path "HKCU:\Control Panel\Desktop" -name WallPaper -Force | Out-Null
        
        # set new wallpaper
        Set-ItemProperty -path 'HKCU:\Control Panel\Desktop\' -name wallpaper -value "$env:HOMEDRIVE$env:HOMEPATH\wallpaper.$fileExtension" -Force | Out-Null
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value "2" -Force | Out-Null
        # Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperOriginX -Value "0" -Force | Out-Null
        # Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperOriginY -Value "0" -Force | Out-Null
        # Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value "0" -Force | Out-Null
        # Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value "2" -Force | Out-Null
        
        # needed to actually change the background consistently
        Start-Sleep -seconds 5
        # refresh settings
        RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters ,1 ,True
    
    } elseif($IsLinux){
        $url = GetWallpaperURL
        $fileExtension = $url.Substring($url.Length - 3)
    
        Invoke-WebRequest $url -OutFile "$env:HOME/wallpaper.$fileExtension"
    
        if($env:DESKTOP_SESSION -eq "mate"){
            gsettings set org.mate.background picture-filename "$env:HOME/wallpaper.$fileExtension"
        } elseif($env:DESKTOP_SESSION -eq "cinnamon"){
            gsettings set org.cinnamon.desktop.background picture-uri "file://$env:HOME/wallpaper.$fileExtension"
        } elseif($env:DESKTOP_SESSION -eq "ubuntu" -Or $env:DESKTOP_SESSION -eq "gnome"){
            gsettings set org.gnome.desktop.background picture-uri "file://$env:HOME/wallpaper.$fileExtension"
        } elseif($env:DESKTOP_SESSION -eq "xubuntu" -Or $env:DESKTOP_SESSION -eq "xfce"){
            xfconf-query --channel xfce4-desktop --property /backdrop/screen0/monitor0/image-path --set "$env:HOME/wallpaper.$fileExtension"

        } elseif($env:DESKTOP_SESSION -eq "plasma"){
            
            #not working
            Write-Output "plasma not working"
            Exit
            # Invoke-Expression "dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript 'string:
            # var Desktops = desktops();                                                                                                                       
            # for (i=0;i<Desktops.length;i++) {
            #         d = Desktops[i];
            #         d.wallpaperPlugin = ""org.kde.image"";
            #         d.currentConfigGroup = Array(""Wallpaper"",
            #                                     ""org.kde.image"",
            #                                     ""General"");
            #         d.writeConfig(""Image"", ""file:///home/damian14443/wallpaper.png"");
            # }'"
        } else {
            Write-Output "unknown desktop environment"
            Exit
        }
    } else {
        Write-Output "unknown operating system"
        Exit
    }
}

while($true) {
    ChangeWallpaper
    Start-Sleep -Seconds 15
}