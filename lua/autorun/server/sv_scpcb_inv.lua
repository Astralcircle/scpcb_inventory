resource.AddWorkshop("3747919146")
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

local function SendSlotClear(slot, ply)
	net.Start("SCPCB_ClearInventory")
	net.WriteUInt(slot, 4)
	net.Send(ply)
end

net.Receive("SCPCB_Inventory", function(len, ply)
	local inventory = SetupInventory(ply)
	local action = net.ReadUInt(3)

	-- Drop
	if action == 1 then
		local dropped_slot = net.ReadUInt(4)
		local item = inventory[dropped_slot]

		if item then
			local weapon = ply:GetWeapon(item.class)

			if weapon:IsValid() then
				ply.SCPCBEnableSwitchCheck = true

				weapon.ammo_given = item.ammo_given
				ply:DropNamedWeapon(item.class)

				ply.SCPCBEnableSwitchCheck = nil
			end
		end
	end

	-- Use
	if action == 2 then
		local used_slot = net.ReadUInt(4)
		local item = inventory[used_slot]

		if item then
			local active_weapon = ply:GetActiveWeapon()

			if active_weapon:IsValid() and active_weapon:GetClass() == item.class then
				ply:SetActiveWeapon(NULL)
			else
				ply:SelectWeapon(item.class)
				item.ammo_given = true
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

hook.Add("WeaponEquip", "SCPCB_PickupWeapon", function(weapon, ply)
	if weapon:IsMarkedForDeletion() then
		return
	end

	if not ply.SCPCBDisableSpawnChecks then
		ply.SCPCBEnableSwitchCheck = true

		timer.Simple(0, function()
			if ply:IsValid() then
				ply.SCPCBEnableSwitchCheck = nil
			end
		end)
	end

	local inventory = SetupInventory(ply)
	local slot = FindFreeSlot(inventory)

	if slot then
		local class = weapon:GetClass()
		inventory[slot] = {class = class, ammo_given = weapon.ammo_given}
		SendSlotChange(slot, class, ply)

		if not ply.SCPCBDisableSpawnChecks then
			ply:EmitSound("scpcb/pickitem2.ogg")
		end
	else
		weapon:Remove()
	end

	return false
end)

local function ClearRemovedWeapon(owner, weapon)
	local inventory = SetupInventory(owner)
	local class = weapon:GetClass()

	for slot = 1, 10 do
		local item = inventory[slot]

		if item and item.class == class then
			inventory[slot] = nil
			SendSlotClear(slot, owner)
			break
		end
	end
end

hook.Add("PlayerDroppedWeapon", "SCPCB_CleanInventory", function(owner, weapon)
	if owner:IsPlayer() then
		ClearRemovedWeapon(owner, weapon)
	end
end)

hook.Add("EntityRemoved", "SCPCB_CleanInventory", function(ent)
	if ent:IsWeapon() then
		local owner = ent:GetOwner()

		if owner:IsValid() and owner:IsPlayer() then
			ClearRemovedWeapon(owner, ent)
		end
	end
end)

hook.Add("PlayerSwitchWeapon", "SCPCB_SwitchWeaponDisallow", function(ply)
	return ply.SCPCBEnableSwitchCheck
end)

hook.Add("PlayerInitialSpawn", "SCPCB_TransitionCompact", function(ply, transition)
	if transition then
		local inventory = SetupInventory(ply)

		for slot = 1, 10 do
			local item = inventory[slot]

			if item and ply:HasWeapon(item.class) then
				SendSlotChange(slot, item.class, ply)
			else
				inventory[slot] = nil
				SendSlotClear(slot, ply)
			end
		end
	end
end)

hook.Add("PlayerSpawn", "SCPCB_SilentSpawnEquip", function(ply)
	ply.SCPCBDisableSpawnChecks = true

	timer.Simple(0, function()
		if ply:IsValid() then
			ply.SCPCBDisableSpawnChecks = nil
		end
	end)
end)
