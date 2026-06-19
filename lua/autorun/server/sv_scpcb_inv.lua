util.AddNetworkString("SCPCB_Inventory")
util.AddNetworkString("SCPCB_ClearInventory")

local function FindFreeSlot(inventory)
	for i = 1, 10 do
		if not inventory[i] then
			return i
		end
	end
end

local function SetupInventory(ply)
	local inventory = ply.SCPCBItems

	if not inventory then
		inventory = {}
		ply.SCPCBItems = inventory
	end

	return inventory
end

local function SendSlotChange(slot, class, ply)
	net.Start("SCPCB_Inventory")
	net.WriteUInt(slot, 4)
	net.WriteString(class)
	net.Send(ply)
end

local ignore_pickupcheck
local ignore_soundcheck

net.Receive("SCPCB_Inventory", function(len, ply)
	local inventory = SetupInventory(ply)
	local action = net.ReadUInt(3)

	-- Drop
	if action == 1 then
		local dropped_slot = net.ReadUInt(4)
		local item = inventory[dropped_slot]

		if item then
			ignore_pickupcheck = true

			local weapon = ply:Give(item.class, true)
			ply:GetWeapon(item.class).ammo_given = item.ammo_given
			ply:DropNamedWeapon(item.class)

			ignore_pickupcheck = false
		end

		inventory[dropped_slot] = nil
	end

	-- Use
	if action == 2 then
		local used_slot = net.ReadUInt(4)
		local item = inventory[used_slot]

		if item then
			local active_weapon = ply:GetActiveWeapon()

			if active_weapon:IsValid() and active_weapon:GetClass() == item.class then
				ply:StripWeapons()
			else
				ignore_pickupcheck = true

				ply:StripWeapons()
				ply:Give(item.class, item.ammo_given)
				item.ammo_given = true

				ignore_pickupcheck = false
			end

			ply:EmitSound("scpcb/pickitem2.ogg")
		end
	end

	-- Move
	if action == 3 then
		local dropped_slot = net.ReadUInt(4)
		local receiver_slot = net.ReadUInt(4)

		if inventory[receiver_slot] or not inventory[dropped_slot] then
			return
		end

		inventory[receiver_slot] = inventory[dropped_slot]
		inventory[dropped_slot] = nil
	end
end)

hook.Add("PlayerCanPickupWeapon", "SCPCB_PickupWeapon", function(ply, weapon)
	if ignore_pickupcheck or weapon:IsMarkedForDeletion() then
		return
	end

	local inventory = SetupInventory(ply)
	local slot = FindFreeSlot(inventory)

	if slot then
		local class = weapon:GetClass()
		inventory[slot] = {class = class, ammo_given = weapon.ammo_given}
		SendSlotChange(slot, class, ply)

		if not ignore_soundcheck then
			ply:EmitSound("scpcb/pickitem2.ogg")
		end

		weapon:Remove()
	end

	return false
end)

hook.Add("PlayerSwitchWeapon", "SCPCB_SwitchWeaponDisallow", function()
	if ignore_pickupcheck then
		return
	end

	return true
end)

hook.Add("PlayerSpawn", "SCPCB_SilentSpawnEquip", function()
	ignore_soundcheck = true
end)

hook.Add("PlayerSetModel", "SCPCB_SilentSpawnEquip", function()
	ignore_soundcheck = false
end)

hook.Add("PostPlayerDeath", "SCPCB_ClearInventory", function(ply)
	ply.SCPCBItems = {}
	net.Start("SCPCB_ClearInventory")
	net.Send(ply)
end)
