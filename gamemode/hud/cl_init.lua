local PLAYER = FindMetaTable("Player")
function PLAYER:GetRoomDepth()
    return self:GetNWInt("DungeonRoomNumber", 0)
end

hook.Add("HUDPaint", "HudPaint", function()
    local SW, SH = ScrW(), ScrH()
    draw.RoundedBox(0, 0, SH / 2, 120, 50, Color(120, 120, 120, 200))
    draw.DrawText("Health: " .. LocalPlayer():Health(), "DarkDrift", 0, SH / 2, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
    local t = string.FormattedTime(LocalPlayer().timer)
    local str = string.format("%02i:%02i:%02i:%02i", t.h, t.m, t.s, t.ms)
    draw.DrawText("Time: " .. tostring(str), "DarkDrift", 0, SH / 2 + 15, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
    draw.DrawText("Room: " .. LocalPlayer():GetRoomDepth(), "DarkDrift", 0, SH / 2 + 30, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
end)