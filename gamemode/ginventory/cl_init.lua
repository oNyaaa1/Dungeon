include("party/shared.lua")
local pickle_Inv = {}
local invBtn = {}
local WepImg = {}
surface.CreateFont("DarkDriftInv", {
    font = "Roboto",
    size = 16,
    weight = 700,
    antialias = true,
})



hook.Add("InitPostEntity", "SetSlots", function()
    print("Inventory Loaded")
    if IsValid(frame2) then frame2:Remove() end
    frame2 = vgui.Create("DPanel")
    frame2:SetSize(500, 100)
    frame2:SetPos(ScrW() * 0.29 + 93, ScrH() * 0.85)
    frame2.Paint = function(_, w, h) end
    local grid2 = vgui.Create("ThreeGrid", frame2)
    grid2:Dock(FILL)
    grid2:DockMargin(4, 4, 4, 4)
    grid2:SetColumns(6)
    grid2:SetHorizontalMargin(2)
    grid2:SetVerticalMargin(2)
    grid2:InvalidateParent(true)
    grid2:InvalidateLayout(true)
    for i = 1, 6 do
        pickle_Inv[i] = vgui.Create("DPanel")
        pickle_Inv[i]:SetSize(80, 80)
        pickle_Inv[i].SlotID = i
        pickle_Inv[i].Paint = function(_, pw, ph)
            surface.SetDrawColor(0, 0, 0, 100)
            surface.DrawRect(0, 0, pw, ph)
            surface.SetDrawColor(94, 94, 94, 150)
            surface.DrawRect(0, 0, pw, ph)
        end

        grid2:AddCell(pickle_Inv[i])
    end
end)

local function AddItemToInventory(parent, num, name, mat, gun_name)
    WepImg[num] = vgui.Create("DImage", pickle_Inv[num or 1])
    WepImg[num]:Dock(TOP)
    WepImg[num]:SetSize(30, 70)
    WepImg[num]:SetImage(mat)
    invBtn[num] = vgui.Create("DButton", pickle_Inv[num or 1])
    invBtn[num]:Dock(BOTTOM)
    invBtn[num]:SizeToContents()
    invBtn[num].Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(52, 52, 52, 0))
        draw.DrawText(tostring(name), "DarkDriftInv", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
    end

    invBtn[num]:SetText("")
    return nil
end

net.Receive("DarkDrift_Guns", function()
    local name = net.ReadString()
    local mat = net.ReadString()
    local gun_name = net.ReadString()
    local num = net.ReadFloat()
    AddItemToInventory(pickle_Inv, num, name, mat, gun_name)
end)

net.Receive("DarkDrift_Clear", function()
    for k, v in pairs(invBtn) do
        v:Remove()
    end

    for k, v in pairs(WepImg) do
        v:Remove()
    end
end)