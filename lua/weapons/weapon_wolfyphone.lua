-- WolfyPhone SWEP: hold it and press attack to open the phone UI.
-- Sandbox-spawnable (Weapons tab > Wolfy) and given via !phone /
-- wolfyphone_give / Config.GiveToNewPlayers.

AddCSLuaFile()

SWEP.PrintName      = "WolfyPhone"
SWEP.Category       = "Wolfy"
SWEP.Author         = "CommunityPoke"
SWEP.Instructions   = "Left click: open phone  |  Right click: close phone"

SWEP.Spawnable      = true
SWEP.AdminOnly      = false
SWEP.Weight         = 1
SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = false

SWEP.ViewModelFOV   = 62
SWEP.ViewModel      = ""                       -- hands-free: the UI is the view
SWEP.WorldModel     = WolfyPhone and WolfyPhone.Config.PhoneWorldModel
                      or "models/props/cs_office/phone.mdl"
SWEP.HoldType       = "slam"
SWEP.UseHands       = false

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.3)
    if CLIENT and IsFirstTimePredicted() then
        WolfyPhone.OpenPhone()
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.3)
    if CLIENT and IsFirstTimePredicted() then
        WolfyPhone.ClosePhone()
    end
end

function SWEP:Reload()
    return true -- phones don't reload
end
