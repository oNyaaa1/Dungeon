util.AddNetworkString("BreadCrumbs_Timer")
hook.Add("Tick", "CountDownTimer", function()
    local Time = CurTime() + 1
    for k, ply in pairs(player.GetAll()) do
        if IsValid(ply) then
            if ply.Timer == nil then ply.Timer = CurTime() + 0 end
            net.Start("BreadCrumbs_Timer")
            net.WriteFloat(Time + ply.Timer)
            net.Broadcast()
        end
    end
end)