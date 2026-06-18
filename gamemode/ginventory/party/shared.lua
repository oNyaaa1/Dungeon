local Guns = {}
Guns.Pack1 = {
    ["name"] = "Confetti gun",
    ["material"] = "darkdrift/confetti.png",
    ["weapon"] = "confetti_gun",
}

function WeaponGetter(name)
    for k, v in pairs(Guns) do
        if v["weapon"] == name then return v end
    end
end