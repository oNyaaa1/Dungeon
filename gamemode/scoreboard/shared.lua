if SERVER then
else
    surface.CreateFont("DarkDrift", {
        font = "Helvetica",
        size = 18,
        weight = 700
    })

    net.Receive("BreadCrumbs_Timer", function() LocalPlayer().timer = net.ReadFloat() end)
    local ScoreBoard = {}
    function ScoreBoard:Show()
        ScoreBoard.sb = vgui.Create("DPanel")
        ScoreBoard.sb:SetSize(ScrW() / 2, ScrH() / 2)
        ScoreBoard.sb:Center()
        ScoreBoard.sb.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(64, 64, 64, 200)) end
        ScoreBoard.sb2 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb2:Dock(TOP)
        ScoreBoard.sb2:SetSize(ScoreBoard.sb:GetWide(), 64)
        ScoreBoard.sb2.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 0))
            draw.DrawText("DarkDrift", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
            draw.DrawText("Gamemode", "DarkDrift", ScoreBoard.sb:GetWide() - 80, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        local likable = vgui.Create("DImage", ScoreBoard.sb2)
        likable:SetPos(ScoreBoard.sb:GetWide() / 2 - 50, 10)
        likable:SetSize(64, 64)
        likable:SetImage("darkdrift/skeleton.png")
        ScoreBoard.sb3 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb3:Dock(LEFT)
        ScoreBoard.sb3:SetWide(110)
        ScoreBoard.sb3.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Name", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.sb32 = vgui.Create("DPanel", ScoreBoard.sb3)
        ScoreBoard.sb32:Dock(LEFT)
        ScoreBoard.sb32:DockMargin(0, 25, 0, 0)
        ScoreBoard.sb32:SetWide(110)
        ScoreBoard.sb32.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.sb32)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:Nick()), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.sb3232 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb3232:Dock(LEFT)
        ScoreBoard.sb3232:SetWide(110)
        ScoreBoard.sb3232.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Health", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.sb324 = vgui.Create("DPanel", ScoreBoard.sb3232)
        ScoreBoard.sb324:Dock(LEFT)
        ScoreBoard.sb324:DockMargin(0, 25, 0, 0)
        ScoreBoard.sb324:SetWide(110)
        ScoreBoard.sb324.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.sb324)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:Health()), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.bctimer = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.bctimer:Dock(LEFT)
        ScoreBoard.bctimer:SetWide(110)
        ScoreBoard.bctimer.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Time", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.bctimer1 = vgui.Create("DPanel", ScoreBoard.bctimer)
        ScoreBoard.bctimer1:Dock(LEFT)
        ScoreBoard.bctimer1:DockMargin(0, 25, 0, 0)
        ScoreBoard.bctimer1:SetWide(200)
        ScoreBoard.bctimer1.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.bctimer1)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                local t = string.FormattedTime(name.timer)
                local str = string.format("%02i:%02i:%02i:%02i", t.h, t.m, t.s, t.ms)
                draw.DrawText(tostring(str), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.roomdepth = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.roomdepth:Dock(LEFT)
        ScoreBoard.roomdepth:SetWide(110)
        ScoreBoard.roomdepth.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Depth", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.roomdepth1 = vgui.Create("DPanel", ScoreBoard.roomdepth)
        ScoreBoard.roomdepth1:Dock(LEFT)
        ScoreBoard.roomdepth1:DockMargin(0, 25, 0, 0)
        ScoreBoard.roomdepth1:SetWide(110)
        ScoreBoard.roomdepth1.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.roomdepth1)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:GetRoomDepth()) or 0, "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.sb4 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb4:Dock(LEFT)
        ScoreBoard.sb4:SetWide(110)
        ScoreBoard.sb4.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Kills", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.sb42 = vgui.Create("DPanel", ScoreBoard.sb4)
        ScoreBoard.sb42:Dock(LEFT)
        ScoreBoard.sb42:DockMargin(0, 25, 0, 0)
        ScoreBoard.sb42:SetWide(110)
        ScoreBoard.sb42.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.sb42)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:Frags()), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.sb5 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb5:Dock(LEFT)
        ScoreBoard.sb5:SetWide(110)
        ScoreBoard.sb5.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Deaths", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.sb52 = vgui.Create("DPanel", ScoreBoard.sb5)
        ScoreBoard.sb52:Dock(LEFT)
        ScoreBoard.sb52:DockMargin(0, 25, 0, 0)
        ScoreBoard.sb52:SetWide(200)
        ScoreBoard.sb52.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.sb52)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:Deaths()), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end

        ScoreBoard.sb6 = vgui.Create("DPanel", ScoreBoard.sb)
        ScoreBoard.sb6:Dock(LEFT)
        ScoreBoard.sb6:SetWide(200)
        ScoreBoard.sb6.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 255))
            draw.DrawText("Ping", "DarkDrift", 0, 0, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
        end

        ScoreBoard.sb62 = vgui.Create("DPanel", ScoreBoard.sb6)
        ScoreBoard.sb62:Dock(LEFT)
        ScoreBoard.sb62:DockMargin(0, 25, 0, 0)
        ScoreBoard.sb62:SetWide(140)
        ScoreBoard.sb62.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(120, 120, 120, 255)) end
        for k, name in pairs(player.GetAll()) do
            ScoreBoard.dbutton = vgui.Create("DButton", ScoreBoard.sb62)
            ScoreBoard.dbutton:Dock(TOP)
            ScoreBoard.dbutton:SizeToContents()
            ScoreBoard.dbutton.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
                draw.DrawText(tostring(name:Ping()), "DarkDrift", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            end

            ScoreBoard.dbutton:SetText("")
        end
    end

    hook.Add("ScoreboardShow", "Scoreboard_Open", function()
        ScoreBoard:Show()
        return true
    end)

    hook.Add("ScoreboardHide", "Scoreboard_Open", function()
        local sb = ScoreBoard.sb
        if IsValid(sb) then sb:Remove() end
        return true
    end)
end