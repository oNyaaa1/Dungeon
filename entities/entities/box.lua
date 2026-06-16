AddCSLuaFile()
DEFINE_BASECLASS("base_anim")
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Loot Box"
ENT.Category = "Dark Drift"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.Model = "models/props_junk/wood_crate001a.mdl"
ENT.IsLootBox = true
-- ═══════════════════════════════════════════════════════
-- Weapons this box can give (weighted for randomness)
-- ═══════════════════════════════════════════════════════
ENT.LootTable = {
	{
		weapon = "confetti_gun",
		weight = 100
	},
}

-- ═══════════════════════════════════════════════════════
-- SERVER
-- ═══════════════════════════════════════════════════════
if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:SetUseType(SIMPLE_USE)
		self.looted = false
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Wake()
		end
	end

	function ENT:Use(activator, caller)
		if not IsValid(activator) or not activator:IsPlayer() then return end
		if self.looted then return end
		-- Pick a random weapon from the loot table
		local weaponClass = self:PickLoot()
		if not weaponClass then return end
		-- Check if player already has this weapon
		if activator:HasWeapon(weaponClass) then
			activator:ChatPrint("You already have that weapon!")
			return
		end

		-- Give the weapon
		activator:Give(weaponClass)
		activator:ChatPrint("You found a " .. weaponClass .. "!")
		-- Mark as looted and play effects
		self.looted = true
		self:SetColor(Color(100, 100, 100, 255))
		self:EmitSound("items/ammo_pickup.wav", 70, 100)
		-- Visual feedback
		local effectData = EffectData()
		effectData:SetOrigin(self:GetPos() + Vector(0, 0, 32))
		effectData:SetMagnitude(2)
		util.Effect("confetti", effectData)
		-- Remove after a short delay so the sound plays
		timer.Simple(0.1, function() if IsValid(self) then self:Remove() end end)
	end

	-- Pick a weighted random weapon from the loot table
	function ENT:PickLoot()
		if not self.LootTable or #self.LootTable == 0 then return nil end
		local total = 0
		for _, entry in ipairs(self.LootTable) do
			total = total + entry.weight
		end

		local r = math.random(1, total)
		local acc = 0
		for _, entry in ipairs(self.LootTable) do
			acc = acc + entry.weight
			if r <= acc then return entry.weapon end
		end
		return self.LootTable[#self.LootTable].weapon
	end
end

-- ═══════════════════════════════════════════════════════
-- CLIENT
-- ═══════════════════════════════════════════════════════
if CLIENT then
	surface.CreateFont("DarkDriftLootTip", {
		font = "Roboto",
		size = 48,
		weight = 700,
		antialias = true,
	})

	local DRAW_DIST_SQR = 220 * 220 -- only show the prompt when a player is close

	function ENT:Draw()
		self:DrawModel()

		local pos = self:GetPos() + self:GetUp() * 28
		local eyePos = EyePos()
		if eyePos:DistToSqr(pos) > DRAW_DIST_SQR then return end

		-- Billboard the text so it always faces the player
		local ang = (pos - eyePos):Angle()
		ang:RotateAroundAxis(ang:Up(), -90)
		ang:RotateAroundAxis(ang:Forward(), 90)

		-- Show whatever key is actually bound to +use (falls back to E)
		local useKey = (input.LookupBinding("+use") or "E"):upper()
		local text = "Open with [" .. useKey .. "]"

		cam.Start3D2D(pos, ang, 0.1)
			surface.SetFont("DarkDriftLootTip")
			local tw, th = surface.GetTextSize(text)
			draw.RoundedBox(8, -tw * 0.5 - 16, -th * 0.5 - 8, tw + 32, th + 16, Color(0, 0, 0, 200))
			draw.SimpleText(text, "DarkDriftLootTip", 0, 0, Color(250, 250, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end