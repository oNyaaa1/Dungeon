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
    SWEP.DrawCrosshair = true
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
    local pl = self:GetOwner()
    if not IsValid(pl) then return end
    if pl:Health() <= 0 then return end
    local tr = pl:GetEyeTrace()
    self:EmitSound("darkdrift/darkdrift_confetti.mp3")
    if CLIENT then
        local effects = EffectData()
        effects:SetOrigin(pl:GetShootPos())
        util.Effect("confetti", effects)
        local effectdata = EffectData()
        effectdata:SetOrigin(tr.HitPos)
        effectdata:SetStart(tr.StartPos)
        effectdata:SetSurfaceProp(tr.SurfaceProps) -- For the sound
        effectdata:SetEntity(tr.Entity) -- The hit entity
        effectdata:SetHitBox(tr.HitBoxBone or 0) -- For the decal
        effectdata:SetDamageType(DMG_BULLET) -- For the decal
        util.Effect("Explosion", effectdata)
    end

    if SERVER then
        for k, target in pairs(ents.FindInSphere(tr.Entity:GetPos(), 50)) do
            target:TakeDamage(100, pl, pl)
        end
    end

    self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:SecondaryAttack()
end