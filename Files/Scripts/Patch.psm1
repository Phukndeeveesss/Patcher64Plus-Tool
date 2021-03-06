function MainFunction([String]$Command, [String]$PatchedFileName) {
    
    # Header
    $Header = @($null) * 5
    #$Header = SetHeader -Header $Header -ROMTitle $GameType.rom_title  -ROMGameID $GameType.rom_gameID  -VCTitle $GameType.vc_title  -VCGameID $GameType.vc_gameID  -Region $GameType.rom_region
    if (!(StrLike -str $Command -val "Patch Header")) {
        $Header = SetHeader -Header $Header -ROMTitle $GamePatch.rom_title -ROMGameID $GamePatch.rom_gameID -VCTitle $GamePatch.vc_title -VCGameID $GamePatch.vc_gameID -Region $GamePatch.rom_region
    }

    # Hash
    if (IsSet $GamePatch.Hash)   { $global:CheckHashSum = $GamePatch.Hash }
    else                         { $global:CheckHashSum = $GameType.Hash }

    # Output
    if (!(IsSet $PatchedFileName)) { $PatchedFileName = "_patched" }
    
    # Expand Memory, Remap D-Pad
    if ($IsWiiVC) {
        if ($GameType.patches_vc -ge 3) {
            if ($VC.ExpandMemory.Visible -and (StrLike -str $Command -val "Force Expand Memory") )    { $VC.ExpandMemory.Checked = $True }
            elseif ($VC.ExpandMemory.Visible -and (StrLike -str $Command -val "No Expand Memory") )   { $VC.ExpandMemory.Checked = $False }
    
            if ($VC.RemapDPad.Visible -and (StrLike -str $Command -val "Force Remap D-Pad") )         { $VC.RemapDPad.Checked = $True }
            elseif ($VC.RemapDPad.Visible -and (StrLike -str $Command -val "No Remap D-Pad") )        { $VC.RemapDPad.Checked = $False }
        }
    }

    if ( !(StrLike -str $Command -val "Inject") -and !(StrLike -str $Command -val "Patch Header") -and !(StrLike -str $Command -val "Apply Patch") -and !(StrLike -str $Command -val "Patch VC") -and !(StrLike -str $Command -val "Extract") ) {
        # Redux
        if ( (IsChecked $Patches.Redux) -and (IsSet $GamePatch.redux.file)) {
            $VC.RemapDPad.Checked = $True
            if ($GameType.patches_vc -eq 4) { $VC.ExpandMemory.Checked = $True }
            $Header = SetHeader -Header $Header -ROMTitle $GamePatch.redux.rom_title -ROMGameID $GamePatch.redux.rom_gameID -VCTitle $GamePatch.redux.vc_title -VCGameID $GamePatch.redux.vc_gameID -Region $GamePatch.rom_region
            if (IsSet -Elem $GamePatch.redux.output) { $PatchedFileName = $GamePatch.redux.output }
            if (StrLike -str $Command -val "Inject") { $PatchedFileName += "_injected" }
        }

        # Language Patch
        $LanguagePatch = $null
        if ( (IsSet -Elem $GamePatch.languages -MinLength 1) -and $Settings.Debug.LiteGUI -eq $False) {
            for ($i=0; $i -lt $GamePatch.languages.Length; $i++) {
                if ($Redux.Language[$i].checked) { $Item = $i }
            }
            $Header = SetHeader -Header $Header -ROMTitle $GamePatch.languages[$Item].rom_title -ROMGameID $GamePatch.languages[$Item].rom_gameID -VCTitle $GamePatch.languages[$Item].vc_title -VCGameID $GamePatch.languages[$Item].vc_gameID -Region $GamePatch.rom_region
            if (IsSet $GamePatch.languages[$Item].output) { $PatchedFileName = $GamePatch.languages[$Item].output }
            $LanguagePatch = $GamePatch.languages[$Item].file
        }
    }

    #  Title / GameID
    if ($CustomHeader.EnableHeader.Checked) {
        if ($CustomHeader.Title.TextLength -gt 0)    { $Header[0 + [int]$IsWiiVC * 2] = [String]$CustomHeader.Title.Text }
        if ($CustomHeader.GameID.TextLength -eq 4)   { $Header[1 + [int]$IsWiiVC * 2] = [String]$CustomHeader.GameID.Text }

        if ( (IsSet $GamePatch.languages) -and (IsSet $Item) -and $IsWiiVC) {
            if (IsSet $GamePatch.languages[$Item].rom_gameID) {
                $Header[1] = [String]$Header[1].substring(0, 3)
                $Header[1] += [String]$GamePatch.languages[$Item].rom_gameID.substring(3, 1)
            }
        }
    }

    # Region
    if ($CustomHeader.EnableRegion.Checked -and $GameConsole.rom_gameID -eq 2) { $Header[4] = [Byte]$CustomHeader.Region.SelectedIndex }
    
    # Decompress
    $Decompress = $False
    if ($GameType.decompress -gt 0) {
        if     ((GetPatchFile) -like "*\Decompressed\*")       { $Decompress = $True }
        elseif ($LanguagePatch -like "*\Decompressed\*")       { $Decompress = $True }
        elseif (IsChecked $Patches.Downgrade)                  { $Decompress = $True }
        elseif ($GameType.decompress -eq 1 -and !(StrLike -str $Command -val "Inject") -and !(StrLike -str $Command -val "Patch Header") -and !(StrLike -str $Command -val "Apply Patch") -and !(StrLike -str $Command -val "Patch VC") -and !(StrLike -str $Command -val "Extract") ) {
            if ( (IsChecked $Patches.Options) -or (IsChecked $Patches.Redux) )   { $Decompress = $True }
        }
        
    }

    # Set ROM
    if ( (IsSet -Elem $InjectFile -MinLength 4) -and $IsWiiVC) { $global:ROMFile = SetROMParameters -Path $InjectPath -PatchedFileName $PatchedFileName }
    if (!$IsWiiVC) {
        $global:ROMFile = SetROMParameters -Path $GamePath -PatchedFileName $PatchedFileName
        SetGetROM
    }

    # Downgrade
    if (!$IsWiiVC -and $ROMHashSum -eq $CheckHashSum)                                                                                        { $Patches.Downgrade.Checked = $False }
    elseif ($Patches.Downgrade.Visible -and (StrLike -str $Command -val "Force Downgrade") -and $Settings.Debug.IgnoreChecksum -eq $False)   { $Patches.Downgrade.Checked = $True }
    elseif ($Patches.Downgrade.Visible -and (StrLike -str $Command -val "No Downgrade") )                                                    { $Patches.Downgrade.Checked = $False }

    # GO!
    MainFunctionPatch -Command $Command -Header $Header -PatchedFileName $PatchedFileName -Decompress $Decompress
    EnableGUI $True
    if (!($GeneralSettings.NoCleanup.Checked)) { Cleanup }

}



#==============================================================================================================================================================================================
function SetHeader([Array]$Header, [String]$ROMTitle, [String]$ROMGameID, [String]$VCTitle, [String]$VCGameID, [Byte]$Region) {
    
    if (IsSet $ROMTitle)                                       { $Header[0] = $ROMTitle }
    if (IsSet $ROMGameID)                                      { $Header[1] = $ROMGameID }
    if ($IsWiiVC -and (IsSet $VCTitle) )                       { $Header[2] = $VCTitle }
    if ($IsWiiVC -and (IsSet $VCGameID) )                      { $Header[3] = $VCGameID }
    if ($GameConsole.rom_gameID -eq 2 -and (IsSet $Region) )   { $Header[4] = $Region }
    return $Header

}



#==============================================================================================================================================================================================
function MainFunctionPatch([String]$Command, [Array]$Header, [String]$PatchedFileName, [Boolean]$Decompress) {
    
    if ($Settings.Debug.Console -eq $True) { if ( (WriteDebug -Command $Command -Header $Header -PatchedFileName $PatchedFileName -Decompress $Decompress) -eq $True) { return } }

    # Step 01: Disable the main dialog, allow patching and delete files if they still exist.
    EnableGUI $False
    CreatePath $Paths.Temp

    # Only continue with these steps in VC WAD mode. Otherwise ignore these steps.
    if ($IsWiiVC) {
        # Step 02: Extract the contents of the WAD file.
        if (!(ExtractWADFile $PatchedFileName)) { return }

        # Step 03: Check the GameID to be vanilla.
        if (!(CheckGameID)) { return }

        # Step 04: Extract "00000005.app" file to get the ROM.
        ExtractU8AppFile $Command

        # Step 05: Do some initial patching stuff for the ROM for VC WAD files.
        if (!(PatchVCROM $Command)) { return }

        # Step 06: Replace the Virtual Console emulator within the WAD file.
        PatchVCEmulator $Command
    }

    # Step 07: Convert and compare the hashsum of the ROM
    ConvertROM $Command
    if (!(CompareHashSums $Command)) { return }

    # Step 08: Downgrade and decompress the ROM if required
    if (StrLike -str $Command -val "Inject" -Not) {
        if (!(DecompressROM $Decompress)) { return }
        DowngradeROM $Decompress
    }

    if ( !(StrLike -str $Command -val "Inject") -and !(StrLike -str $Command -val "Patch Header") -and !(StrLike -str $Command -val "Apply Patch") -and !(StrLike -str $Command -val "Patch VC") -and !(StrLike -str $Command -val "Extract") ) {
        # Step 09: Extract MQ dungeon data for OoT
        ExtractMQData $Decompress
        
        # Step 10: Apply additional options before Redux
        PrePatchingAdditionalOptions

        # Step 11: Apply the Redux patch
        PatchRedux $Decompress

        # Step 12: Apply additional options
        PatchingAdditionalOptions

        # Step 13: Patch and extend the ROM file with the patch through Floating IPS
        if (!(PatchDecompressedROM)) { return }

        # Step 14: Compress the decompressed ROM if required
        CompressROM $Decompress

        # Step 15: Patch and extend the ROM file with the patch through Floating IPS
        if (!(PatchCompressedROM)) { return }
    }
    elseif (StrLike -str $Command -val "Apply Patch") {
        # Step 16: Compress if needed and apply provided BPS Patch
        CompressROM  $Decompress
        if (!(ApplyPatchROM $Decompress)) { return }
    }

    # Step 17: Update the .Z64 ROM CRC
    UpdateROMCRC

    # Step 18: Hack the Game Title and GameID of a N64 ROM, remove the US region protection as well if applicable and neccesary
    HackROMGameTitle -Title $Header[0] -GameID $Header[1] -Region $Header[4]

    # Step 19: Debug
    CreateDebugPatches

    # Only continue with these steps in VC WAD mode. Otherwise ignore these steps.
    if ($IsWiiVC) {
        # Step 20: Extend a ROM if it is neccesary for the Virtual Console. Mostly applies to decompressed ROMC files
        ExtendROM

        # Step 21: Compress the ROMC again if possible.
        CompressROMC

        # Step 22: Hack the Channel Title.
        HackOpeningBNRTitle $Header[2]

        # Step 23: Repack the "00000005.app" with the updated ROM file 
        RepackU8AppFile
        
        # Step 24: Repack the WAD file with the updated APP file.
        RepackWADFile $Header[3]
    }

    # Step 25: Final message.
    if ($IsWiiVC)   { UpdateStatusLabel ('Finished patching the ' + $GameType.mode + ' VC WAD file.') }
    else            { UpdateStatusLabel ('Finished patching the ' + $GameType.mode + ' ROM file.') }    

}



#==============================================================================================================================================================================================
function WriteDebug([String]$Command, [String[]]$Header, [String]$PatchedFileName, [Boolean]$Decompress) {
    
    if ($Settings.Debug.Stop -eq $False) { return $False }

    WriteToConsole
    WriteToConsole "--- Start Patch Info ---"
    WriteToConsole ("Header: " + $Header)
    WriteToConsole ("Patch File: " + (GetPatchFile))
    WriteToConsole ("Redux Patch: " + $GamePatch.redux.file)
    WriteToConsole ("Additional Options: " +  (IsChecked $Patches.Options))
    WriteToConsole ("Redux: " +  (IsChecked $Patches.Redux))
    WriteToConsole ("Language Patch: " + $LanguagePatch)
    WriteToConsole ("Patched File Name: " + $PatchedFileName)
    WriteToConsole ("Command: " + $Command)
    WriteToConsole ("Downgrade: " + $Patches.Downgrade.Checked)
    WriteToConsole ("Finalize Downgrade: " + ($Patches.Downgrade.Checked -and (!$Patches.Redux.Checked -or !$Patches.Redux.Visible)))
    WriteToConsole ("Decompress: " + $Decompress)
    WriteToConsole ("ROM Hash: " + $ROMHashSum)
    WriteToConsole ("Game Type Hash: " + $GameType.Hash)
    WriteToConsole ("Patch Hash: " + $GamePatch.Hash)
    WriteToConsole ("Wii VC: " + $IsWiiVC)
    WriteToConsole ("Console: " + $GameConsole.Mode)
    WriteToConsole ("Game File Path: " + $GamePath)
    WriteToConsole ("Injection File Path: " + $InjectPath)
    WriteToConsole ("Patch File Path: " + $PatchPath)
    WriteToConsole "--- End Patch Info ---"
    WriteToConsole

    return $True

}



#==============================================================================================================================================================================================
function Cleanup() {
    
    WriteToConsole "Cleaning up files..."

    $global:ByteArrayGame = $global:ROMFile = $global:WADFile = $global:CheckHashSum = $global:ROMHashSum = $null

    RemovePath $WADFile.Folder
    RemovePath $Paths.cygdrive
    RemovePath $Paths.Temp
    RemoveFile $Files.flipscfg
    RemoveFile $Files.stackdump

    [System.GC]::Collect() | Out-Null

}



#==============================================================================================================================================================================================
function GetPatchFile() {
    
    if ($GamePatch.patch -is [System.Array]) {
        foreach ($Patch in $GamePatch.patch) {
            if ($Patch.hash -eq $ROMHashSum) { return $Patch.file }
        }
        return $GamePatch.patch[0].file
    }
    return $GamePatch.patch

}



#==============================================================================================================================================================================================
function PrePatchingAdditionalOptions() {

    if ( !(IsSet -Elem $GamePatch.redux.file) -or !(IsChecked $Patches.Redux) ) { return }

    if ( !$Decompress -and !(TestFile $GetROM.decomp) ) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.decomp -Force }
    $FunctionTitle = SetFunctionTitle -Function $GameType.mode

    # BPS - Pre-Redux Options
    if ( (Get-Command ("PrePatchRedux" + $FunctionTitle) -errorAction SilentlyContinue) -and (IsChecked $Patches.Redux) -and (IsSet $GamePatch.redux.file) ) {
        UpdateStatusLabel ("Pre-Patching " + $GameType.mode + " Additional Redux Patches...")
        &("PrePatchRedux" + $FunctionTitle)
    }

}



#==============================================================================================================================================================================================
function PatchingAdditionalOptions() {
    
    if ( ($GamePatch.options -eq 0) -or !(IsChecked $Patches.Options) ) { return }

    if ( !$Decompress -and !(TestFile $GetROM.decomp) ) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.decomp -Force }
    $FunctionTitle = SetFunctionTitle -Function $GameType.mode
        
    # Language patch
    if (IsSet -Elem $LanguagePatch) { # Language
        UpdateStatusLabel ("Patching " + $GameType.mode + " Language...")
        ApplyPatch -File $GetROM.decomp -Patch $LanguagePatch
    }

    # BPS - Additional Options
    if (Get-Command ("PatchOptions" + $FunctionTitle) -errorAction SilentlyContinue) {
        UpdateStatusLabel ("Patching " + $GameType.mode + " Additional Options Patches...")
        &("PatchOptions" + $FunctionTitle)
    }

    # BPS - Redux Options
    if ( (Get-Command ("PatchRedux" + $FunctionTitle) -errorAction SilentlyContinue) -and (IsChecked $Patches.Redux) -and (IsSet $GamePatch.redux.file) ) {
        UpdateStatusLabel ("Patching " + $GameType.mode + " Additional Redux Patches...")
        &("PatchRedux" + $FunctionTitle)
    }

    if ( (Get-Command ("ByteOptions" + $FunctionTitle) -errorAction SilentlyContinue) -or (Get-Command ("ByteRedux" + $FunctionTitle) -errorAction SilentlyContinue) -or (Get-Command ("ByteLanguage" + $FunctionTitle) -errorAction SilentlyContinue) ) { $global:ByteArrayGame = [IO.File]::ReadAllBytes($GetROM.decomp) }

    # Additional Options
    if (Get-Command ("ByteOptions" + $FunctionTitle) -errorAction SilentlyContinue) {
        UpdateStatusLabel ("Patching " + $GameType.mode + " Additional Options...")
        &("ByteOptions" + $FunctionTitle)
    }

    # Redux Options
    if ( (Get-Command ("ByteRedux" + $FunctionTitle) -errorAction SilentlyContinue) -and (IsChecked $Patches.Redux) -and (IsSet $GamePatch.redux.file) ) {
        UpdateStatusLabel ("Patching " + $GameType.mode + " Additional Redux Options...")
        &("ByteRedux" + $FunctionTitle)
    }

    # Language Options
    if (Get-Command ("ByteLanguage" + $FunctionTitle) -errorAction SilentlyContinue) {
        UpdateStatusLabel ("Patching " + $GameType.mode + " Additional Language Options...")
        &("ByteLanguage" + $FunctionTitle)
    }

    if ( (Get-Command ("ByteOptions" + $FunctionTitle) -errorAction SilentlyContinue) -or (Get-Command ("ByteRedux" + $FunctionTitle) -errorAction SilentlyContinue) -or (Get-Command ("ByteLanguage" + $FunctionTitle) -errorAction SilentlyContinue) ) {
        [io.file]::WriteAllBytes($GetROM.decomp, $ByteArrayGame)
        $ByteArrayGame = $null
    }

    if (!$Decompress) { Move-Item -LiteralPath $GetROM.decomp -Destination $GetROM.patched -Force }

}



#==============================================================================================================================================================================================
function UpdateROMCRC() {
    
    if ($Settings.Debug.NoCRCChange -eq $True -or $GameConsole.mode -ne "N64") { return }
    if (!(TestFile $GetROM.patched)) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.patched }
    & $Files.tool.rn64crc $GetROM.patched -update | Out-Null
    WriteToConsole ("Updated CRC hash for ROM: " + $GetROM.patched)

    if ($Settings.Debug.KeepConverted -eq $True -and (TestFile $GetROM.keepConvert) )      { & $Files.tool.rn64crc $GetROM.keepConvert -update | Out-Null;   WriteToConsole ("Updated CRC hash for ROM: " + $GetROM.keepConvert) }
    if ($Settings.Debug.KeepDowngraded -eq $True -and (TestFile $GetROM.keepDowngrade) )   { & $Files.tool.rn64crc $GetROM.keepDowngrade -update | Out-Null; WriteToConsole ("Updated CRC hash for ROM: " + $GetROM.keepDowngrade) }
    if ($Settings.Debug.KeepDecompressed -eq $True -and (TestFile $GetROM.keepDecomp) )    { & $Files.tool.rn64crc $GetROM.keepDecomp -update | Out-Null;    WriteToConsole ("Updated CRC hash for ROM: " + $GetROM.keepDecomp) }


}



#==============================================================================================================================================================================================
function CreateDebugPatches() {
    
    if ($Settings.Debug.CreateBPS -ne $True) { return }
    if ( (TestFile $GetROM.cleanDecomp) -and (TestFile $GetROM.decomp) ) {
        & $Files.tool.flips --create --bps $GetROM.cleanDecomp $GetROM.decomp $Files.decompBPS | Out-Null 
        WriteToConsole ("Created BPS Patch: " + $Files.decompBPS)
    }
    & $Files.tool.flips --create --bps $GetROM.clean $GetROM.patched $Files.compBPS | Out-Null
    WriteToConsole ("Created BPS Patch: " + $Files.compBPS)

}



#==============================================================================================================================================================================================
function SetWADParameters([String]$Path, [String]$FolderName, [String]$PatchedFileName) {
    
    # Create a hash table
    $WADFile = @{}

    # Get the WAD as an item object
    $WADItem = Get-Item -LiteralPath $Path
    
    # Store some stuff about the WAD to reference
    $WADFile.Name         = $WADItem.BaseName
    $WADFile.Folder       = $Paths.Temp + "\" + $FolderName
    $WADFile.FolderName   = $FolderName

    $WADFile.AppFile00    = $WADFile.Folder + "\00000000.app"
    $WADFile.AppPath00    = $WADFile.Folder + "\00000000"
    $WADFile.AppFile01    = $WADFile.Folder + "\00000001.app"
    $WADFile.AppPath01    = $WADFile.Folder + "\00000001"
    $WADFile.AppFile05    = $WADFile.Folder + "\00000005.app"
    $WADFile.AppPath05    = $WADFile.Folder + "\00000005"

    $WADFile.cert         = $WADFile.Folder + "\" + $FolderName + ".cert"
    $WADFile.tik          = $WADFile.Folder + "\" + $FolderName + ".tik"
    $WADFile.tmd          = $WADFile.Folder + "\" + $FolderName + ".tmd"
    $WADFile.trailer      = $WADFile.Folder + "\" + $FolderName + ".trailer"
    
    $WADFile.Extension = GetROMExtension

    $WADFile.Patched      = $WADItem.DirectoryName + "\" + $WADFile.Name + $PatchedFileName + ".wad"
    $WADFile.Extracted    = $WADItem.DirectoryName + "\" + $WADFile.Name + "_extracted"     + $WADFile.Extension
    $WADFile.Convert      = $WADItem.DirectoryName + "\" + $WADFile.Name + "_converted"     + $WADFile.Extension
    $WADFile.Downgrade    = $WADItem.DirectoryName + "\" + $WADFile.Name + "_downgraded"    + $WADFile.Extension
    $WADFile.Decomp       = $WADItem.DirectoryName + "\" + $WADFile.Name + "_decompressed"  + $WADFile.Extension

    $WADFile.Offset = $WadFile.Length = "0"

    # Set it to a global value
    return $WADFile

}



#==============================================================================================================================================================================================
function SetROMParameters([String]$Path, [String]$PatchedFileName) {
    
    # Create a hash table
    $ROMFile = @{}

    # Get the ROM as an item object
    $ROMItem = Get-Item -LiteralPath $Path
    
    # Store some stuff about the ROM to reference
    $ROMFile.Name    = $ROMItem.BaseName
    $ROMFile.Path    = $ROMItem.DirectoryName
    
    $ROMFile.Extension = GetROMExtension

    $ROMFile.ROM     = $Path
    $ROMFile.Patched   = $ROMFile.Path + "\" + $ROMFile.Name + $PatchedFileName + $ROMFile.Extension
    $ROMFile.Convert   = $ROMFile.Path + "\" + $ROMFile.Name + "_converted"     + $ROMFile.Extension
    $ROMFile.Downgrade = $ROMFile.Path + "\" + $ROMFile.Name + "_downgraded"    + $ROMFile.Extension
    $ROMFile.Decomp    = $ROMFile.Path + "\" + $ROMFile.Name + "_decompressed"  + $ROMFile.Extension
    

    # Set it to a global value
    return $ROMFile

}



#==============================================================================================================================================================================================
function GetROMExtension() {
    
    if ($GameConsole.mode -eq "N64")        { return ".z64" }
    elseif ($GameConsole.mode -eq "SNES")   { return ".sfc" }
    elseif ($GameConsole.mode -eq "NES")    { return ".nes" }

}



#==============================================================================================================================================================================================
function ExtractWADFile([String]$PatchedFileName) {
    
    # Set the status label
    UpdateStatusLabel "Extracting WAD file..."

    # Check if an extracted folder existed previously
    foreach($Folder in Get-ChildItem -LiteralPath $Paths.Temp -Force) {
        if ($Folder.PSIsContainer) { RemovePath $Folder }
    }
    
    [io.file]::WriteAllBytes($Files.ckey, @(235, 228, 42, 34, 94, 133, 147, 228, 72, 217, 197, 69, 115, 129, 170, 247)) | Out-Null
    
    # We need to be in the same path as some files so just jump there
    Push-Location $Paths.Temp

    # Run the program to extract the wad file
    $ErrorActionPreference = 'SilentlyContinue'
    try   { & $Files.tool.wadunpacker $GamePath | Out-Null }
    catch { }
    $ErrorActionPreference = 'Continue'

    # Doesn't matter, but return to where we were
    Pop-Location

    # Find the extracted folder by looping through all files in the folder.
    $FolderExists = $False
    foreach ($Folder in Get-ChildItem -LiteralPath $Paths.Temp -Force) {
        # There will only be one folder, the one we want.
        if ($Folder.PSIsContainer) {
            $FolderExists = $True
            # Remember the path to this folder
            $global:WADFile = SetWADParameters -Path $GamePath -FolderName $Folder.Name -PatchedFileName $PatchedFileName
        }
    }

    if (!$FolderExists) {
        UpdateStatusLabel "Failed! Could not extract Wii VC WAD. Try using a different filename."
        return $False
    }
    return $True

}



#==============================================================================================================================================================================================
function ExtractU8AppFile([String]$Command) {
    
    # ROM is within the "0000005.app" file
    if ($GameConsole.appfile -eq "00000005.app") {
        UpdateStatusLabel 'Extracting "00000005.app" file...'                           # Set the status label
        & $Files.tool.wszst 'X' $WADFile.AppFile05 '-d' $WADFile.AppPath05 | Out-Null   # Unpack the file using wszst

        # Remove all .T64 files when selected
        if ($VC.RemoveT64.Checked) {
            Get-ChildItem $WADFile.AppPath05 -Include *.T64 -Recurse | Remove-Item
        }

        # Reference ROM in unpacked AppFile
        Get-ChildItem $WADFile.AppPath05 | Foreach-Object {
            if ($_ -match "rom") {
                $WADFile.ROM = $_.FullName
                SetGetROM
            }
        }
    }
    
    # ROM is within "00000001.app" VC emulator file, but extract it only
    elseif ($GameConsole.appfile -eq "00000001.app") {
        UpdateStatusLabel 'Extracting ROM from "00000001.app" file...'                  # Set the status label
        SetGetROM
        RemoveFile $GetROM.nes
        $WADFile.Offset = SearchBytes -File $WADFile.AppFile01 -Values @("4E", "45", "53", "1A") -Start "100000"
        
        if ($WADFile.Offset -ne -1) {
            $arr = [IO.File]::ReadAllBytes($WADFile.AppFile01)
            $WADFile.Length = Get24Bit (16 + ($arr[(GetDecimal $WADFile.Offset) + 4] * 16384) + ($arr[(GetDecimal $WADFile.Offset) + 5] * 8192))
            ExportBytes -File $WADFile.AppFile01 -Offset $WADFile.Offset -Length $WADFile.Length -Output $WADFile.ROM
        }
    }

}



#==============================================================================================================================================================================================
function PatchVCEmulator([String]$Command) {
    
    if (StrLike -Str $Command -Val "Extract") { return }

    # Set the status label.
    UpdateStatusLabel ("Patching " + $GameType.mode + " VC Emulator...")

    # Applying LZSS decompression
    if ($GameType.lzss -gt 0) {
        if ( (StrLike -Str $Command -Val "Patch Boot DOL") -or $VC.ExpandMemory.Checked -or $VC.RemapDPad.Checked -or $VC.RemapCDown.Checked -or $VC.RemapZ.Checked) {
            & $Files.tool.lzss -d $WADFile.AppFile01 | Out-Null
            WriteToConsole ("Decompressed LZSS File: " + $WADFile.AppFile01)
        }
    }

    # Patching Boot DOL
    if (StrLike -Str $Command -Val "Patch Boot DOL") {
        $Patch = "\AppFile01\" + [System.IO.Path]::GetFileNameWithoutExtension((GetPatchFile))
        $Patch = CheckPatchExtension -File ($GameFiles.base + $Patch)
        ApplyPatch -File $WADFile.AppFile01 -Patch $Patch -FullPath
    }

    # Games
    if ($GameType.mode -eq "Ocarina of Time") {
        if ($VC.ExpandMemory.Checked) {
            ChangeBytes -File $WadFile.AppFile01 -Offset "2EB0"  -Values @("60", "00", "00", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset "5BF44" -Values @("3C", "80", "72", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset "5BFD7" -Values @("00")
        }

        if ($VC.RemapDPad.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "16BA20" -End "17C6F0" -Values ("00", "20", "00", "00", "00", "20", "00", "00", "00", "20", "00", "00", "00", "20", "00", "00")
            # Vanilla D-Pad: 0x16BAF0, 0x16BAF4, 0x16BAF8, 0x16BAFC
            if (!$VC.LeaveDPadUp.Checked) { ChangeBytes -File $WadFile.AppFile01 -Offset $Offset -Values @("08", "00") }
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "04") ) ) -Values @("04", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "08") ) ) -Values @("02", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "0C") ) ) -Values @("01", "00")
        }

        if ($VC.RemapCDown.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "16BA20" -End "17C6F0" -Values ("00", "08", "00", "00", "00", "04", "00", "00", "00", "02", "00", "00", "00", "01", "00", "00", "80", "00", "00", "00", "40", "00", "00", "00", "20", "00", "00", "00", "20", "00", "00", "00")
            # Vanilla C-Down: 0x16BB04
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "04") ) ) -Values @("00", "20")
        }

        if ($VC.RemapZ.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "16BA20" -End "17C6F0" -Values ("20", "00", "00", "00", "00", "10", "00", "00", "00", "04", "00", "00", "10", "00", "00", "00")
            # Vanilla Z: 0x16BAD8
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "08") ) ) -Values @("00", "20")
        }
    }
    elseif ($GameType.mode -eq "Majora's Mask") {
        if ($VC.ExpandMemory.Checked) {
            ChangeBytes -File $WadFile.AppFile01 -Offset "10B58" -Values @("3C", "80", "00", "C0")
            ChangeBytes -File $WadFile.AppFile01 -Offset "4BD20" -Values @("67", "E4", "70", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset "4BC80" -Values @("3C", "A0", "01", "00")
        }

        if ($VC.RemapDPad.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "148430" -End "15DA0F" -Values ("00", "00", "00", "00", "00", "20", "00", "00", "00", "20", "00", "00", "00", "20", "00", "00")
            # Vanilla D-Pad: 0x148514, 0x148518, 0x14851C, 0x148520
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "04") ) ) -Values @("08", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "08") ) ) -Values @("04", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "0C") ) ) -Values @("02", "00")
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "10") ) ) -Values @("01", "00")
        }

        if ($VC.RemapCDown.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "148430" -End "15DA0F" -Values ("00", "20", "00", "00", "00", "08", "00", "00", "00", "04", "00", "00", "00", "02", "00", "00")
            # Vanilla C-Down: 0x148528
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "08") ) ) -Values @("00", "20") }

        if ($VC.RemapZ.Checked) {
            $Offset = SearchBytes -File $WadFile.AppFile01 -Start "148430" -End "15DA0F" -Values ("20", "00", "00", "00", "00", "10", "00", "00", "00", "04", "00", "00", "10", "00", "00", "00")
            # Vanilla Z: 0x1484F8
            ChangeBytes -File $WadFile.AppFile01 -Offset ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "08") ) ) -Values @("00", "20")
        }

    }
    elseif ($GameType.mode -eq "Super Mario 64") {
        if (IsChecked $VC.RemapL) {
            #$Offset = SearchBytes -File $WadFile.AppFile01 -Start "168000" -End "180000" -Values ("20", "00", "00", "00", "00", "10", "00", "00", "20", "00", "00", "00", "10", "00", "00", "00")
            #ChangeBytes -File $WadFile.AppFile01 -Offset $Offset -Values @("00", "20")
            ChangeBytes -File $WadFile.AppFile01 -Offset "168628" -Values @("00", "20") # L -> 0x168628, D-Pad -> 0x168648, 0x16864C, 0x168650, 0x168654
        } 

        if ( (IsChecked $VC.RemoveFilter) -and (StrLike -str $Command -val "Multiplayer") )   { ChangeBytes -File $WadFile.AppFile01 -Offset "53124" -Values @("60", "00", "00", "00") }
        elseif (IsChecked $VC.RemoveFilter)                                                   { ChangeBytes -File $WadFile.AppFile01 -Offset "46210" -Values @("4E", "80", "00", "20") }
    }

    # Applying LZSS compression
    if ($GameType.lzss -gt 0) {
        if ( (StrLike -Str $Command -Val "Patch Boot DOL") -or $VC.ExpandMemory.Checked -or $VC.RemapDPad.Checked -or $VC.RemapCDown.Checked -or $VC.RemapZ.Checked) {
            & $Files.tool.lzss -evn $WADFile.AppFile01 | Out-Null
            WriteToConsole ("Compressed LZSS File: " + $WADFile.AppFile01)
        }
    }

}



#==============================================================================================================================================================================================
function PatchVCROM([String]$Command) {

    if (StrLike -str $Command -val "Patch VC") { return $True }

    # Set the status label.
    UpdateStatusLabel ("Initial patching of " + $GameType.mode + " ROM...")
    
    # Extract ROM if required
    if (StrLike -str $Command -val "Extract") {
        if (TestFile $GetROM.run) {
            Move-Item -LiteralPath $GetROM.run -Destination $WADFile.Extracted -Force
            UpdateStatusLabel ("Successfully extracted " + $GameType.mode + " ROM.")
        }
        else { UpdateStatusLabel ("Could not extract " + $GameType.mode + " ROM. Is it a VC compressed ROM?") }

        return $False
    }

    # Replace ROM if needed
    if (StrLike -str $Command -val "Inject") {
        if (TestFile $GetROM.run) {
            if (TestFile $InjectPath) { Copy-Item -LiteralPath $InjectPath -Destination $GetROM.run -Force }
            else {
                UpdateStatusLabel ("Could not inject " + $GameType.mode + " ROM. Did you move or rename the ROM file?")
                return $False
            }
        }
        else {
            UpdateStatusLabel ("Could not inject " + $GameType.mode + " ROM. Is it a VC compressed ROM?")
            return $False
        }
    }

    # Decompress romc if needed
    if ($GameType.romc -ge 1 -and !(StrLike -str $Command -val "Inject") ) {  
        if (TestFile $GetROM.run) {
            RemoveFile $GetROM.romc
            if ($GameType.romc -eq 1)       { & $Files.tool.romchu $GetROM.run $GetROM.romc | Out-Null }
            elseif ($GameType.romc -eq 2)   { & $Files.tool.romc d $GetROM.run $GetROM.romc | Out-Null }
            Move-Item -LiteralPath $GetROM.romc -Destination $GetROM.run -Force
            $global:ROMHashSum = (Get-FileHash -Algorithm MD5 $GetROM.run).Hash
        }
        else {
            UpdateStatusLabel ("Could not decompress " + $GameType.mode + " ROM. Is it a VC compressed ROM?")
            return $False
        }
    }

    # Get the file as a byte array so the size can be analyzed.
    $ByteArray = [IO.File]::ReadAllBytes($GetROM.run)
    
    # Create an empty byte array that matches the size of the ROM byte array.
    $NewByteArray = New-Object Byte[] $ByteArray.Length
    
    # Fill the entire array with junk data. The patched ROM is slightly smaller than 8MB but we need an 8MB ROM.
    for ($i=0; $i-lt $ByteArray.Length; $i++) { $NewByteArray[$i] = 255 }

    $ByteArray = $null

    return $True

}



#==============================================================================================================================================================================================
function DowngradeROM([Boolean]$Decompress) {
    
    if (IsChecked $Patches.Downgrade -Not) { return }

    # Downgrade a ROM if it is required first
    UpdateStatusLabel "Downgrading ROM..."

    if ($ROMHashSum -eq $GameType.Hash) {
        WriteToConsole "ROM is already downgraded"
        return
    }

    if ($Decompress) { $GetROM.run = $GetROM.decomp }
    
    foreach ($Item in $GameType.downgrade) {
        if ($ROMHashSum -eq $Item.hash) {
            if (!(ApplyPatch -File $GetROM.run -Patch ("\Downgrade\" + $Item.file))) {
                WriteToConsole "Could not apply downgrade patch"
                return
            }
            if ($Settings.Debug.KeepDowngraded -eq $True) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.keepDowngrade -Force }
            $global:ROMHashSum = $GameType.hash
            return
        }
    }

    WriteToConsole "Unknown revision for downgrading"
    
}



#==============================================================================================================================================================================================
function ConvertROM([String]$Command) {
    
    if ($Settings.Debug.NoConversion -eq $True) { return }
    if ( (StrLike -str $Command -val "Inject") -or (StrLike -str $Command -val "Patch Header") -or (StrLike -str $Command -val "Patch VC") ) { return }

    # Converse ROM if needed
    $Name = [System.IO.Path]::GetFileNameWithoutExtension($GetROM.run)
    $Ext =  [System.IO.Path]::GetExtension($GetROM.run)
    if ($Ext -eq ".v64" -or $Ext -eq ".n64") {
        UpdateStatusLabel "Converting ROM to Big Endian..."

        if ($Ext -eq ".v64" -or $Ext -eq ".n64") {
            $array = [IO.File]::ReadAllBytes($GetROM.run)
            if (Compare-Object -ReferenceObject $array[0..8] -DifferenceObject @(128, 55, 18, 64, 0, 0, 0, 15, 128) -IncludeEqual) {
                WriteToConsole "ROM is already Big Endian?"
                return
            }

        }

        if ($Ext -eq ".v64") {
            for ($i=0; $i -lt $array.length; $i+=2) {
                $temp = @($array[$i], $array[$i + 1])
                $array[$i]     = $temp[1]
                $array[$i + 1] = $temp[0]
            }
        }
        elseif ($Ext -eq ".n64") {
            for ($i=0; $i -lt $array.length; $i+=4) {
                $temp = @($array[$i], $array[$i + 1], $array[$i + 2], $array[$i + 3])
                $array[$i]     = $temp[3]
                $array[$i + 1] = $temp[2]
                $array[$i + 2] = $temp[1]
                $array[$i + 3] = $temp[0]
            }
        }

        if ($Ext -eq ".v64" -or $Ext -eq ".n64") {
            [IO.File]::WriteAllBytes($Paths.Temp + "\converted", $array)
            $array = $temp = $null
        }

        $GetROM.run =  $Paths.Temp + "\converted"
        $global:ROMHashSum = (Get-FileHash -Algorithm MD5 $GetROM.run).Hash
        if ($Settings.Debug.KeepConverted -eq $True) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.keepConvert -Force }
        GetPatchFile
    }

}



#==============================================================================================================================================================================================
function CompareHashSums([String]$Command) {
    
    if ($Settings.Debug.CreateBPS -eq $True) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.clean -Force }
    if ($Settings.Debug.IgnoreChecksum -eq $True) { return $True }
    if ( (StrLike -str $Command -val "Inject") -or (StrLike -str $Command -val "Patch Header") -or (StrLike -str $Command -val "Patch VC") -or (StrLike -str $Command -val "Apply Patch") ) { return $True }

    if ($ROMHashSum -eq $CheckHashSum) { return $True }
    elseif (IsSet -Elem $GameType.downgrade) {
        Foreach ($Item in $GameType.downgrade) {
            if ($ROMHashSum -eq $Item.hash) { return $True }
        }
    }
    
    UpdateStatusLabel "Failed! The ROM has an incorrect version or is not proper."
    return $False

}



#==============================================================================================================================================================================================
function PatchDecompressedROM() {

    if (!(StrLike -str (GetPatchFile) -val "\Decompressed")) { return $True }
    
    # Set the status label.
    UpdateStatusLabel ("Patching " + $GameType.mode + " ROM with patch file...")

    # Apply the selected patch to the ROM, if it is provided
    if (!(ApplyPatch -File $GetROM.decomp -Patch (GetPatchFile))) { return $False }

    return $True

}



#==============================================================================================================================================================================================
function PatchCompressedROM() {
    
    if (!(StrLike -str (GetPatchFile) -val "\Compressed")) { return $True }
    
    # Set the status label.
    UpdateStatusLabel ("Patching " + $GameType.mode + " ROM with patch file...")

    # Apply the selected patch to the ROM, if it is provided
    if ($IsWiiVC)        { if (!(ApplyPatch -File $GetROM.patched -Patch (GetPatchFile)))                    { return $False } }
    elseif (!$IsWiiVC)   { if (!(ApplyPatch -File $GetROM.run -Patch (GetPatchFile) -New $GetROM.patched))   { return $False } }

    return $True

}



#==============================================================================================================================================================================================
function ApplyPatchROM([Boolean]$Decompress) {

    $HashSum1 = (Get-FileHash -Algorithm MD5 $GetROM.run).Hash
    if ($Decompress)   { $File = $GetROM.patched }
    else               { $File = $GetROM.run }

    if (!(ApplyPatch -File $File -Patch $PatchPath -New $GetROM.patched -FullPath)) { return $False }
    $HashSum2 = (Get-FileHash -Algorithm MD5 $GetROM.patched).Hash
    if ($HashSum1 -eq $HashSum2) {
        if ($IsWiiVC -and $GameType.downgrade -and !(IsChecked $Patches.Downgrade) )      { UpdateStatusLabel "Failed! Patch file does not match source. ROM has left unchanged. Enable Downgrade?" }
        elseif ($IsWiiVC -and $GameType.downgrade -and (IsChecked $Patches.Downgrade) )   { UpdateStatusLabel "Failed! Patch file does not match source. ROM has left unchanged. Disable Downgrade?" }
        else                                                                              { UpdateStatusLabel "Failed! Patch file does not match source. ROM has left unchanged." }
        return $False
    }

    return $True

}



#==============================================================================================================================================================================================
function ApplyPatch([String]$File, [String]$Patch, [String]$New, [Switch]$FilesPath, [Switch]$FullPath) {

    if ( !(IsSet -Elem $File) -or !(IsSet -Elem $Patch) ) { return $True }

    # File
    if (!(TestFile $File)) {
        UpdateStatusLabel "Failed! Could not find file."
        return $False
    }

    # Patch File
    if ($FullPath)         {  }
    elseif ($FilesPath)    { $Patch = $Paths.Master + $Patch }
    else                   { $Patch = $GameFiles.base + $Patch }

    if (TestFile ($Patch + ".bps"))      { $Patch + ".bps" }
    if (TestFile ($Patch + ".ips"))      { $Patch + ".ips" }
    if (TestFile ($Patch + ".ups"))      { $Patch + ".ups" }
    if (TestFile ($Patch + ".xdelta"))   { $Patch + ".xdelta" }
    if (TestFile ($Patch + ".vcdiff"))   { $Patch + ".vcdiff" }
    if (TestFile ($Patch + ".ppf"))      { $Patch + ".ppf" }

    if (TestFile $Patch) { $Patch = Get-Item -LiteralPath $Patch }
    else {
        UpdateStatusLabel "Failed! Could not find patch file."
        WriteToConsole ("Patch file is missing from: " + $Patch)
        return $False
    }

    # Patching
    WriteToConsole ("Applying patch: " + $Patch)

    if ($Patch -like "*.bps*" -or $Patch -like "*.ips*") {
        if ($New.Length -gt 0) { & $Files.tool.flips --ignore-checksum --apply $Patch $File $New | Out-Null }
        else { & $Files.tool.flips --ignore-checksum $Patch $File | Out-Null }
    }
    elseif ($Patch -like "*.ups*") {
        if ($New.Length -gt 0) { & $Files.tool.ups apply -b $File -p $Patch -o $New | Out-Null }
        else { & $Files.tool.ups apply -b $File -p $Patch -o $File | Out-Null }
    }
    elseif ($Patch -like "*.xdelta*" -or $Patch -like "*.vcdiff*") {
        if ($Patch -like "*.xdelta*")       { $Tool = $Files.tool.xdelta }
        elseif ($Patch -like "*.vcdiff*")   { $Tool = $Files.tool.xdelta3 }

        if ($New.Length -gt 0) {
            RemoveFile $New
            & $Tool -d -s $File $Patch $New | Out-Null
        }
        else {
            & $Tool -d -s $File $Patch ($File + ".ext") | Out-Null
            Move-Item -LiteralPath ($File + ".ext") -Destination $File -Force
        }
    }
    elseif ($Patch -like "*.ppf*") {
        if ($New.Length -gt 0) {
            Copy-Item -LiteralPath $File -Destination $New -Force
            & $Files.tool.applyPPF3 a $New $Patch | Out-Null
        }
        else { & $Files.tool.applyPPF3 a $File $Patch | Out-Null }
    }

    else { return $False }

    WriteToConsole ("Successfully applied Patch: " + $Patch)
    return $True

}



#==============================================================================================================================================================================================
function DecompressROM([Boolean]$Decompress) {
    
    if (!$Decompress) { return $True }
    
    if ($GameType.decompress -eq 1) {
        UpdateStatusLabel ("Decompressing " + $GameType.mode + " ROM...")

        Push-Location $Paths.Temp
        if (IsSet $GamePatch.dmaTable) {
            RemoveFile $Files.dmaTable
            Add-Content $Files.dmaTable $GamePatch.dmaTable
        }
        elseif ($ROMHashSum -ne $CheckHashSum -and (IsChecked $Patches.Downgrade))   {
            RemoveFile $Files.dmaTable
            Add-Content $Files.dmaTable $GameType.dmaTable
        }
        elseif ($Settings.Core.Bit64 -eq $True)                                       { & $Files.tool.TabExt64 $GetROM.run | Out-Null }
        else                                                                          { & $Files.tool.TabExt32 $GetROM.run | Out-Null }
        WriteToConsole ("Generated DMA Table from: " + $GetROM.run)
        & $Files.tool.ndec $GetROM.run $GetROM.decomp | Out-Null
        WriteToConsole ("Decompressed ROM: " + $GetROM.decomp)
        Pop-Location

        if ($Settings.Debug.CreateBPS -eq $True) { Copy-Item -LiteralPath $GetROM.decomp -Destination $GetROM.cleanDecomp -Force }
        
    }
    elseif ($GameType.decompress -eq 2) {
        UpdateStatusLabel ("Extending " + $GameType.mode + " ROM...")

        if (!(IsSet -Elem $GamePatch.extend -Min 18 -Max 64)) {
            UpdateStatusLabel 'Failed. Could not extend SM64 ROM. Make sure the "extend" value is between 18 and 64.'
            return $False
        }

        & $Files.tool.sm64extend $GetROM.run -s $GamePatch.extend $GetROM.decomp | Out-Null
    }

    if ($IsWiiVC) { RemoveFile $GetROM.run }
    return $True

}



#==============================================================================================================================================================================================
function CompressROM([Boolean]$Decompress) {
    
    if (!$Decompress -or !(TestFile $GetROM.decomp)) { return }

    if ($GameType.decompress -eq 1 -and $Settings.Debug.NoCompression -eq $False) {
        UpdateStatusLabel ("Compressing " + $GameType.mode + " ROM...")

        if ($Settings.Debug.KeepDecompressed -eq $True) { Copy-Item -LiteralPath $GetROM.decomp -Destination $GetROM.keepDecomp -Force }
        RemoveFile $Files.archive
        
        Push-Location $Paths.Temp
        if ($Settings.Core.Bit64 -eq $True)   { & $Files.tool.Compress64 $GetROM.decomp $GetROM.patched | Out-Null }
        else                                  { & $Files.tool.Compress32 $GetROM.decomp $GetROM.patched | Out-Null }
        WriteToConsole ("Compressed ROM: " + $GetROM.patched)
        Pop-Location

        if ($Patches.Downgrade.Checked -and (!$Patches.Redux.Checked -or !$Patches.Redux.Visible)) {
            if (TestFile ($GameFiles.downgrade + "\finalize_rev0.bps")) { ApplyPatch -File $GetROM.patched -Patch "\Downgrade\finalize_rev0.bps" }
        }

    }
    else { Move-Item -LiteralPath $GetROM.decomp -Destination $GetROM.patched -Force }

}



#==============================================================================================================================================================================================
function CompressROMC() {
    
    if ($GameType.romc -ne 2) { return }

    UpdateStatusLabel ("Compressing " + $GameType.mode + " VC ROM...")

    RemoveFile $GetROM.romc
    & $Files.tool.romc e $GetROM.run $GetROM.romc | Out-Null
    Move-Item -LiteralPath $GetROM.romc -Destination $GetROM.run -Force

}



#==============================================================================================================================================================================================
function PatchRedux([Boolean]$Decompress) {
    
    # BPS PATCHING REDUX #
    if ( (IsChecked $Patches.Redux) -and (IsSet -Elem $GamePatch.redux.file) ) {

        if ( !$Decompress -and !(TestFile $GetROM.decomp) ) { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.decomp -Force }

        UpdateStatusLabel ("Patching " + $GameType.mode + " REDUX...")

        # Redux patch
        if (IsWidescreen -Patched)                   { ApplyPatch -File $GetROM.decomp -Patch $GamePatch.redux.file_widescreen }
        elseif (IsSet -Elem $GamePatch.redux.file)   { ApplyPatch -File $GetROM.decomp -Patch $GamePatch.redux.file }

        if ($GameType.decompress -eq 1 -and (IsSet -Elem $GameType.dmaTable) ) {
            RemoveFile $Files.dmaTable
            Add-Content $Files.dmaTable $GameType.dmaTable
        }
    }

}



#==============================================================================================================================================================================================
function ExtendROM() {
    
    if ($GameType.romc -ne 1) { return }

    $Bytes = @(08, 00, 00, 00)
    $ByteArray = [IO.File]::ReadAllBytes($GetROM.run)
    [io.file]::WriteAllBytes($GetROM.run, $Bytes + $ByteArray)

    $ByteArray = $null

}



#==============================================================================================================================================================================================
function CheckGameID() {
    
    # Return if freely patching, injecting or extracting
    if ($GameType.checksum -eq 0 -or $Settings.Debug.IgnoreChecksum -eq $True) { return $True }

    # Set the status label.
    UpdateStatusLabel "Checking GameID in .tmd..."

    # Get the ".tmd" file as a byte array.
    $ByteArray = [IO.File]::ReadAllBytes($WadFile.tmd)
    
    $CompareArray = ($GameType.vc_gameID.ToCharArray() | % { [uint32][char]$_ })
    $CompareAgainst = $ByteArray[400..(403)]

    # Check each value of the array.
    for ($i=0; $i-le 4; $i++) {
        # The current values do not match
        if ($CompareArray[$i] -ne $CompareAgainst[$i]) {
            # This is not a vanilla entry.
            UpdateStatusLabel ("Failed! This is not an vanilla " + $GameType.mode + " USA VC WAD file.")
            # Stop wasting time.
            return $False
        }
    }

    $CompareArray = $null
    $CompareAgainst = $null

    return $True

}



#==============================================================================================================================================================================================
function HackOpeningBNRTitle($Title) {
    
    if ($Settings.Debug.NoChannelChange -eq $True)   { return }
    if ($Title -eq $null)                            { return }

    # Set the status label.
    UpdateStatusLabel "Hacking in Opening.bnr custom title..."

    # Get the "00000000.app" file as a byte array.
    $ByteArray = [IO.File]::ReadAllBytes($WadFile.AppFile00)

    # Initially assume the two chunks of data are identical.
    $Identical = $True

    $Start = 0

    $CompareArray = $ByteArray[(GetDecimal -Hex "F1")..((GetDecimal -Hex "F1") + $VCTitleLength)]

    # Scan only the contents of the IMET header within the file.
    for ($i=(GetDecimal -Hex "80"); $i-lt (GetDecimal -Hex "62F"); $i++) {
        $CompareAgainst = $ByteArray[$i..($i + $VCTitleLength)]

        $Matches = $True
        for ($j=0; $j -lt $CompareAgainst.Length; $j++) {
            if ($CompareAgainst[$j] -notcontains $CompareArray[$j]) { $Matches = $False }
        }

        if ($Matches -eq $True) {
            for ($j=0; $j-lt $VCTitleLength; $j++) { $ByteArray[$i + ($j*2)] = 0 }
            for ($j=0; $j-lt $Title.Length; $j++) { $ByteArray[$i + ($j*2)] = [uint32][char]$Title.Substring($j, 1) }
            $i += $VCTitleLength
        }        
    }

    # Overwrite the patch file with the extended file.
    [IO.File]::WriteAllBytes($WadFile.AppFile00, $ByteArray)
    $ByteArray = $null

}



#==============================================================================================================================================================================================
function HackROMGameTitle($Title, $GameID, $Region) {
    
    if ($Title -eq $null -and $GameID -eq $null -and $Region -eq $null) { return }
    if ($Settings.Debug.NoHeaderChange -eq $True) { return }
    if (StrLike -str $Command -val "Patch Header") { Copy-Item -LiteralPath $GetROM.run -Destination $GetROM.patched -Force }
    if (!(TestFile $GetROM.patched)) { return }

    UpdateStatusLabel "Hacking in Custom Title and GameID..."

    # Hi-ROM check and load in Game Array
    $global:ByteArrayGame = [IO.File]::ReadAllBytes($GetROM.patched)
    if ($GameConsole.mode -eq "SNES" -and (IsSet -Elem $GameConsole.rom_title_offset_2) ) { $hiROM = (IsHiROM -Offset (GetDecimal -Hex $GameConsole.rom_title_offset_2) -ROM $ByteArray) }

    # Internal ROM Title
    if ($Title -ne $null -and (IsSet $GameConsole.rom_title_offset) -and (IsSet -Elem $GameConsole.rom_title_length -Min 1) -and ($GameConsole.rom_title -gt 0) ) {
        if ($hiROM) { $offset = $GameConsole.rom_title_offset_2 } else { $offset = $GameConsole.rom_title_offset }
        $emptyTitle = foreach ($i in 1..$GameConsole.rom_title_length) { 20 }
        if ($GameConsole.rom_title_uppercase -gt 0) { $Title = $Title.ToUpper() }
        ChangeBytes -Offset $Offset -Values $emptyTitle
        ChangeBytes -Offset $offset -Values ($Title.ToCharArray() | % { [uint32][char]$_ }) -IsDec
        $emptyTitle = $null
    }

    # GameID
    if ($GameID -ne $null -and (IsSet -Elem $GameConsole.rom_gameID_offset) -and ($GameConsole.rom_gameID -eq 1)) { ChangeBytes -Offset $GameConsole.rom_gameID_offset -Values ($GameID.ToCharArray() | % { [uint32][char]$_ }) -IsDec }
    elseif ($Region -ne $null -and $GameConsole.rom_gameID -eq 2) {
        if ($hiROM) { $offset = $GameConsole.rom_title_offset_2 } else { $offset = $GameConsole.rom_title_offset }
        $offset = ( Get24Bit ( (GetDecimal $Offset) + (GetDecimal "19") ) )
        if ($ByteArrayGame[(GetDecimal $offset)] -ne $Region) {
            $ByteArrayGame[(GetDecimal $offset)] = $Region
            WriteToConsole ("Changed region code: " + (Get8Bit $Region))
            RemoveRegionProtection
        }

    }

    # Write to file and clear variables
    [io.file]::WriteAllBytes($GetROM.patched, $ByteArrayGame)
    $ByteArrayGame = $hiROM = $offset = $null

}



#==============================================================================================================================================================================================
function RemoveRegionProtection() {
    
    # Return conditions
    if ($GameConsole.remove_region_protection -ne 1)   { return }
    if (!(IsChecked $CustomHeader.EnableRegion))       { return }
    if (!$CustomHeader.Region.Visible)                 { return }

    # Load in region protection database
    $regions = SetJSONFile $Files.json.regions

    # Remove region protection for game if applicable
    $entry = $Null
    for ($i=0; $i -lt $regions.Length; $i++) {

        for ($j=0; $j -lt $regions.hash.Length; $j++) {
            if ($regions[$i].hash[$j] -eq $ROMHashSum) {
                $entry = $regions[$i]
                break
            }
        }
    }

    if (IsSet $entry) {
        for ($i=0; $i -lt $entry.offset.Length; $i++) {
            $values = $entry.value[$i] -split '(.{2})' | ? {$_}
            ChangeBytes -Offset $entry.offset[$i] -Values $values
        }
    }

    # Reset variables
    $regions = $entry = $null

}



#==============================================================================================================================================================================================
function IsHiROM([int]$Offset) {
    
    for ($i=$Offset; $i -lt ($Offset + $GameConsole.rom_title_length); $i++) {
        if ( ($ByteArrayGame[$i] -lt 32) -or ($ByteArrayGame[$i] -gt 122) ) { return $False }
    }

    if (!(IsSet -Elem $ByteArrayGame[$Offset + $GameConsole.rom_title_length] -Min 32 -Max 64))   { return $False }
    if ($ByteArrayGame[$Offset + $GameConsole.rom_title_length + 3] -gt 10)                       { return $False }
    if ($ByteArrayGame[$Offset + $GameConsole.rom_title_length + 4] -gt 10)                       { return $False }

    return $True

}



#==============================================================================================================================================================================================
function RepackU8AppFile() {
    
    # The ROM is located witin the "00000005.app" file
    if ($GameConsole.appFile -eq "00000005.app") {
        UpdateStatusLabel 'Repacking "00000005.app" file...'                 # Set the status label
        RemoveFile $WadFile.AppFile05                                        # Remove the original app file as its going to be replaced
        & $Files.tool.wszst 'C' $WadFile.AppPath05 '-d' $WadFile.AppFile05   # Repack the file using wszst
        $AppByteArray = [IO.File]::ReadAllBytes($WadFile.AppFile05)          # Get the file as a byte array
        for ($i=16; $i -le 31; $i++) { $AppByteArray[$i] = 0 }               # Overwrite the values in 0x10 with zeroes. I don't know why, I'm just matching the output from another program
        [IO.File]::WriteAllBytes($WadFile.AppFile05, $AppByteArray)          # Overwrite the patch file with the extended file
        RemoveFile $WadFile.AppPath05                                        # Remove the extracted WAD folder
    }

    # The ROM is located witin the "00000001.app" VC emulator file
    elseif ($GameConsole.appFile -eq "00000001.app") {
        UpdateStatusLabel 'Re-injecting ROM into "00000001.app" file...'     # Set the status label
        $ByteArrayROM = [IO.File]::ReadAllBytes($GetROM.patched)
        $ByteArrayApp = [IO.File]::ReadAllBytes($WADFile.AppFile01)

        for ($i=0; $i -lt (GetDecimal -Hex $WADFile.Length); $i++) {
            $ByteArrayApp[$i + (GetDecimal -Hex $WADFile.Offset)] = $ByteArrayROM[($i)]
        }

        [io.file]::WriteAllBytes($WADFile.AppFile01, $ByteArrayApp)
        $ByteArrayROM = $ByteArrayApp = $null
    }

}



#==============================================================================================================================================================================================
function RepackWADFile($GameID) {
    
    # Set the status label.
    UpdateStatusLabel "Repacking patched WAD file..."
    
    # Loop through all files in the extracted WAD folder.
    foreach($File in Get-ChildItem -LiteralPath $WadFile.Folder -Force) {
        # Move the file to the same folder as the unpacker tool.
        RemoveFile ($Paths.Temp + "\" + $File.Name)
        Move-Item -LiteralPath $File.FullName -Destination $Paths.Temp
        
        # Create an entry for the database.
        $ListEntry = $RepackPath + '\' + $File.Name
        
        # Some files need to be fed into the tool so keep track of them.
        switch ($File.Extension) {
            '.tik'  { $tik  = [System.String](Get-Location) + "\Files\Temp\" + $File.Name }
            '.tmd'  { $tmd  = [System.String](Get-Location) + "\Files\Temp\" + $File.Name }
            '.cert' { $cert = [System.String](Get-Location) + "\Files\Temp\" + $File.Name }
        }
    }

    # We need to be in the same path as some files so just jump there.
    Push-Location $Paths.Temp

    # Repack the WAD using the new files
    if ($GameID -ne $null)   { & $Files.tool.wadpacker $tik $tmd $cert $WadFile.Patched '-sign' '-i' $GameID }
    else                     { & $Files.tool.wadpacker $tik $tmd $cert $WadFile.Patched '-sign' }

    # Doesn't matter, but return to where we were.
    Pop-Location

    # If the patched file was created or could not be created.
    if (TestFile $WadFile.Patched) { 
        # [System.Media.SystemSounds]::Beep.Play()                                   # Play a sound when it is finished.
        UpdateStatusLabel "Complete! Patched Wii VC WAD was successfully patched."   # Set the status label.
    }
    else { UpdateStatusLabel "Failed! Patched Wii VC WAD was not created." }

    # Remove the folder the extracted files were in, and delete files
    RemovePath $WadFile.Folder

}



#==============================================================================================================================================================================================
function IsWidescreen([Switch]$Patched, [Switch]$Experimental) {
    
    if (IsChecked $Redux.Graphics.Widescreen -Not)                         { return $False }
    if ($IsWiiVC)                                                          { return $False }
    if ($Patched -and !(IsSet -Elem $GamePatch.redux.file_widescreen) )    { return $False }
    if ($Settings.Debug.LiteGUI -eq $True)                                 { return $False }

    if     (!$Patched -and !$Experimental)   { return ( !$Patches.Redux.Checked -and $Settings.Debug.ChangeWidescreen -eq $False) }
    elseif ( $Patched -and !$Experimental)   { return (  $Patches.Redux.Checked -and $Settings.Debug.ChangeWidescreen -eq $False) }
    elseif (!$Patched -and  $Experimental)   { return ( !$Patches.Redux.Checked -and $Settings.Debug.ChangeWidescreen -eq $True)  }
    elseif ( $Patched -and  $Experimental)   { return (  $Patches.Redux.Checked -and $Settings.Debug.ChangeWidescreen -eq $True)  }

}



#==============================================================================================================================================================================================

Export-ModuleMember -Function MainFunction
Export-ModuleMember -Function ApplyPatch
Export-ModuleMember -Function Cleanup
Export-ModuleMember -Function IsWidescreen