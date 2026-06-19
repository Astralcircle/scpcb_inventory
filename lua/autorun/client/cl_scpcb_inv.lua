local inventory = {}
local icons_parent
local inventory_key = CreateClientConVar("scp_cb_inventory_key", "G", true)
local menublack = Material("scpcb/menublack.png", "noclamp")
local menuwhite = Material("scpcb/menuwhite.png", "noclamp")
local menuscale = ScrH() / 1024

surface.CreateFont("SCPCB_Inventory", {
	font = "Courier New",
	size = 19 * menuscale,
	extended = true,
	shadow = true
})

if IsValid(icons_parent) then
	icons_parent:Remove()
end

local function GetClassIcon(class)
	if file.Exists("materials/entities/" .. class .. ".png", "GAME") then
		return "entities/" .. class .. ".png"
	end

	if file.Exists("materials/vgui/entities/" .. class .. ".vtf", "GAME") then
		return "vgui/entities/" .. class
	end

	if file.Exists("materials/vgui/entities/" .. class .. ".vmt", "GAME") then
		return "vgui/entities/" .. class
	end

	local swep = weapons.GetStored(class)

	if swep and swep.IconOverride then
		return swep.IconOverride
	end

	local ent = scripted_ents.GetStored(class)

	if ent and ent.IconOverride then
		return ent.IconOverride
	end

	return "scpcb/alface2.png"
end

local function GetClassName(class)
	local name = language.GetPhrase(class)

	if name ~= class then
		return name
	end

	local swep = weapons.GetStored(class)

	if swep and swep.PrintName then
		return swep.PrintName
	end

	local ent = scripted_ents.GetStored(class)

	if ent and ent.PrintName then
		return ent.PrintName
	end

	return "???"
end

hook.Add("HUDShouldDraw", "SCPCB_HideHUD", function(name)
	if name == "CHudWeaponSelection" then
		return false
	end

	if name == "CHudCrosshair" and IsValid(icons_parent) then
		return false
	end
end)

hook.Add("PostGamemodeLoaded", "SCPCB_HideHUD", function()
	function GAMEMODE:HUDWeaponPickedUp()

	end
end)

local function ToggleInventory()
	if IsValid(icons_parent) then
		icons_parent:Remove()
		return
	end

	local slot_size, spacing = 70 * menuscale, 35 * menuscale
	local rows, cols = 2, 5

	local local_player = LocalPlayer()
	local total_width = cols * slot_size + (cols - 1) * spacing
	local total_height = rows * slot_size + (rows - 1) * slot_size

	icons_parent = vgui.Create("Panel")
	icons_parent:SetSize(total_width, total_height)
	icons_parent:MakePopup()
	icons_parent:SetKeyboardInputEnabled(false)
	icons_parent:Center()

	local function CreateIconFrame(x, y, w, h, slot)
		local icon = vgui.Create("Panel", icons_parent)
		icon:SetPos(x, y)
		icon:SetSize(w, h)

		local cached_class
		local cached_name
		local cached_icon

		local function UpdateCache(class)
			if class ~= cached_class then
				cached_class = class
				cached_name = GetClassName(cached_class)
				cached_icon = Material(GetClassIcon(cached_class), "smooth")
			end
		end

		UpdateCache(inventory[slot])
		local offset = math.floor(3 * menuscale)

		function icon:Paint(w, h)
			surface.SetDrawColor(255, 255, 255)

			local tile_x, tile_y = ((slot - 1) % 5) * w, math.floor((slot - 1) / 5) * h
			local u1, v1 = tile_x / 1024, tile_y / 1024
			local u2, v2 = (tile_x + w) / 1024, (tile_y + h) / 1024

			surface.SetMaterial(menuwhite)
			surface.DrawTexturedRectUV(0, 0, w, h, u1, v1, u2, v2)

			surface.SetMaterial(menublack)
			surface.DrawTexturedRectUV(offset, offset, w - offset * 2, h - offset * 2, u1, v1, u2, v2)

			local class = inventory[slot]

			if class then
				local active_weapon = local_player:GetActiveWeapon()

				if active_weapon:IsValid() and active_weapon:GetClass() == class then
					DisableClipping(true)
						surface.SetDrawColor(200, 200, 200)
						surface.DrawOutlinedRect(-3, -3, w + 6, h + 6, 3)
					DisableClipping(false)
				end
			end

			if self:IsHovered() or self:IsChildHovered() then
				DisableClipping(true)
					surface.SetDrawColor(255, 0, 0)
					surface.DrawOutlinedRect(-1, -1, w + 2, h + 2, 1)

					local class = inventory[slot]

					if class then
						UpdateCache(class)
						draw.SimpleText(cached_name, "SCPCB_Inventory", w / 2, h + spacing / 1.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
					end
				DisableClipping(false)
			end

			return true
		end

		local image = vgui.Create("DPanel", icon)
		image:SetPos(offset, offset)
		image:SetSize(w - offset * 2, h - offset * 2)
		image:SetMouseInputEnabled(true)
		image:Droppable("scpcb_slot")
		image.SlotIndex = slot

		function image:Paint(w, h)
			local class = inventory[slot]
			if not class then return end

			UpdateCache(class)

			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(cached_icon)
			surface.DrawTexturedRect(0, 0, w, h)

			return true
		end

		-- Dragdrop support
		local OnMousePressed = image.OnMousePressed

		function image:OnMousePressed(key)
			local last_click = self.LastClick
			OnMousePressed(self, key)

			if not last_click then
				self.LastClick = SysTime()
				return
			end

			if SysTime() - last_click > 0.3 then
				self.LastClick = SysTime()
				return
			end

			net.Start("SCPCB_Inventory")
			net.WriteUInt(2, 3)
			net.WriteUInt(slot, 4)
			net.SendToServer()
		end

		image:Receiver("scpcb_slot", function(receiver, tab, fully_dropped)
			if not fully_dropped then
				return
			end

			local dropped = tab[1]
			local receiver_slot = receiver.SlotIndex
			local dropped_slot = dropped.SlotIndex

			if inventory[receiver_slot] or not inventory[dropped_slot] then
				return
			end

			net.Start("SCPCB_Inventory")
			net.WriteUInt(3, 3)
			net.WriteUInt(dropped_slot, 4)
			net.WriteUInt(receiver_slot, 4)
			net.SendToServer()

			inventory[receiver_slot] = inventory[dropped_slot]
			inventory[dropped_slot] = nil
		end)
	end

	local world_panel = vgui.GetWorldPanel()

	world_panel:Receiver("scpcb_slot", function(receiver, tab, fully_dropped)
		if not fully_dropped then
			return
		end

		local dropped = tab[1]
		local dropped_slot = dropped.SlotIndex

		if not inventory[dropped_slot] then
			return
		end

		net.Start("SCPCB_Inventory")
		net.WriteUInt(1, 3)
		net.WriteUInt(dropped_slot, 4)
		net.SendToServer()

		surface.PlaySound("scpcb/pickitem2.ogg")
		inventory[dropped_slot] = nil
	end)

	for row = 1, rows do
		for col = 1, cols do
			local x = (col - 1) * (slot_size + spacing)
			local y = (row - 1) * (slot_size * 2)
			CreateIconFrame(x, y, slot_size, slot_size, (row - 1) * cols + col)
		end
	end
end

hook.Add("OnScreenSizeChanged", "SCPCB_UpdateResolution", function()
	menuscale = ScrH() / 1024

	surface.CreateFont("SCPCB_Inventory", {
		font = "Courier New",
		size = 19 * menuscale,
		extended = true,
		shadow = true
	})

	if IsValid(icons_parent) then
		icons_parent:Remove()
		ToggleInventory()
	end
end)

hook.Add("PlayerBindPress", "SCPCB_OpenInventory", function(ply, bind, pressed, button)
	if button == input.GetKeyCode(inventory_key:GetString()) and pressed then
		ToggleInventory()
	end
end)

net.Receive("SCPCB_Inventory", function()
	inventory[net.ReadUInt(4)] = net.ReadString()
end)

net.Receive("SCPCB_ClearInventory", function(len)
	if len > 0 then
		inventory[net.ReadUInt(4)] = nil
	else
		inventory = {}
	end
end)
