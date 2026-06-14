if SERVER then
    AddCSLuaFile()
    SWEP.Weight = 5
    SWEP.AutoSwitchTo = false
    SWEP.AutoSwitchFrom = false
elseif CLIENT then
    SWEP.PrintName = "Confetti gun"
    SWEP.Slot = 4
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false
end

SWEP.Author = "oNyaaa"
SWEP.Contact = ""
SWEP.Purpose = "Powerful Confetti gun"
SWEP.Instructions = "Right click to kill Nextbots / NPCS"
SWEP.Category = "oNyaaa"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Reload()
end

function SWEP:Think()
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end