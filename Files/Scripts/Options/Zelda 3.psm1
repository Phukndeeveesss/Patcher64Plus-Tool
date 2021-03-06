function PatchOptionsALinkToThePast() {
    
    if (IsChecked $Redux.Revert.PinkHairGFX)    { ApplyPatch -File $GetROM.decomp -Patch "\Compressed\Original\pink_hair.ips" }
    if (IsChecked $Redux.Revert.MenuGFX)        { ApplyPatch -File $GetROM.decomp -Patch "\Compressed\Original\menu.ips" }
    
    if (IsChecked $Redux.Script.ReWizardized)   { ApplyPatch -File $GetROM.decomp -Patch "\Compressed\rewizardized.ips" }

}



#==============================================================================================================================================================================================
function CreateOptionsALinkToThePast() {
    
    CreateOptionsDialog -Width 390 -Height 250

    # GRAPHICS #
    CreateReduxGroup    -Tag "Revert" -Text "Original (Revert)"
    CreateReduxCheckBox -Name "PinkHairGFX"  -Column 1 -Text "Pink Hair GFX"        -Info "Restores the Pink Hair for Link to that of the original game"                                     -Credits "ShadowOne333"
    CreateReduxCheckBox -Name "MenuGFX"      -Column 2 -Text "Menu GFX"             -Info "Restores the menu to that of the original game"                                                   -Credits "ShadowOne333"

    CreateReduxGroup    -Tag "Script" -Text "Script"
    CreateReduxCheckBox -Name "ReWizardized" -Column 1 -Text "Re-Wizardized Script" -Info "Addresses some script changes, such as addressing Agahnim's role as 'Wizard' insteaf of 'Priest'" -Credits "Kyler Ashton"

}



#==============================================================================================================================================================================================

Export-ModuleMember -Function PatchOptionsALinkToThePast

Export-ModuleMember -Function CreateOptionsALinkToThePast