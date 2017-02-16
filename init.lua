--This code is based on code from mesecons by Jeija, at:
--https://github.com/Jeija/minetest-mod-mesecons/blob/c2e3d7c4e58b2563e79aead60c6efedf27c786cf/mesecons_wires/init.lua#L12
local wire_getconnect = function (from_pos, self_pos)
	local node = minetest.get_node(self_pos)
	if minetest.registered_nodes[node.name]
	and minetest.registered_nodes[node.name].mesecons then
		-- rules of node to possibly connect to
		local rules = {}
		if (minetest.registered_nodes[node.name].mesecon_ito_wire or minetest.registered_nodes[node.name].mesecon_wire) then
			rules = mesecon.rules.default
		else
			rules = mesecon.get_any_rules(node)
		end

		for _, r in ipairs(mesecon.flattenrules(rules)) do
			if (vector.equals(vector.add(self_pos, r), from_pos)) then
				return true
			end
		end
	end
	return false
end

-- Update this node
local wire_updateconnect = function (pos,ito)
	local connections = {}

	for _, r in ipairs(mesecon.rules.default) do
		if wire_getconnect(pos, vector.add(pos, r)) then
			table.insert(connections, r)
		end
	end

	local nid = {}
	for _, vec in ipairs(connections) do
		-- flat component
		if vec.x ==  1 then nid[0] = "1" end
		if vec.z ==  1 then nid[1] = "1" end
		if vec.x == -1 then nid[2] = "1" end
		if vec.z == -1 then nid[3] = "1"  end

		-- slopy component
		if vec.y == 1 then
			if vec.x ==  1 then nid[4] = "1" end
			if vec.z ==  1 then nid[5] = "1" end
			if vec.x == -1 then nid[6] = "1" end
			if vec.z == -1 then nid[7] = "1" end
		end
	end

	local nodeid = 	  (nid[0] or "0")..(nid[1] or "0")..(nid[2] or "0")..(nid[3] or "0")
			..(nid[4] or "0")..(nid[5] or "0")..(nid[6] or "0")..(nid[7] or "0")

	local state_suffix = string.find(minetest.get_node(pos).name, "_off") and "_off" or "_on"
	if ito then
		minetest.set_node(pos, {name = "mesecons_ito:wire_"..nodeid..state_suffix})
	else
		minetest.set_node(pos, {name = "mesecons:wire_"..nodeid..state_suffix})
	end
end

local update_on_place_dig = function (pos, node)
	-- Update placed node (get_node again as it may have been dug)
	local nn = minetest.get_node(pos)
	if (minetest.registered_nodes[nn.name])
	and (minetest.registered_nodes[nn.name].mesecon_ito_wire or minetest.registered_nodes[nn.name].mesecon_wire) then
		wire_updateconnect(pos,minetest.registered_nodes[nn.name].mesecon_ito_wire)
	end

	-- Update nodes around it
	local rules = {}
	if minetest.registered_nodes[node.name]
	and minetest.registered_nodes[node.name].mesecon_ito_wire or minetest.registered_nodes[node.name].mesecon_wire then
		rules = mesecon.rules.default
	else
		rules = mesecon.get_any_rules(node)
	end
	if (not rules) then return end

	for _, r in ipairs(mesecon.flattenrules(rules)) do
		local np = vector.add(pos, r)
		if minetest.registered_nodes[minetest.get_node(np).name]
		and minetest.registered_nodes[minetest.get_node(np).name].mesecon_ito_wire or minetest.registered_nodes[minetest.get_node(np).name].mesecon_wire then
			wire_updateconnect(np,minetest.registered_nodes[minetest.get_node(np).name].mesecon_ito_wire)
		end
	end
end

mesecon.register_autoconnect_hook("wire", update_on_place_dig)

local tiles_off = { "mesecons_ito_mesecons.png" }
local tiles_on = { "mesecons_ito_mesecons.png" }

local box_center = {-1/16, -.5, -1/16, 1/16, -.5+1/32, 1/16}
local box_bump1 =  { -2/16, -8/16,  -2/16, 2/16, -14/32, 2/16 }

local nbox_nid =
{
	[0] = {1/16, -.5, -1/16, 8/16, -.5+1/32, 1/16}, -- x positive
	[1] = {-1/16, -.5, 1/16, 1/16, -.5+1/32, 8/16}, -- z positive
	[2] = {-8/16, -.5, -1/16, -1/16, -.5+1/32, 1/16}, -- x negative
	[3] = {-1/16, -.5, -8/16, 1/16, -.5+1/32, -1/16}, -- z negative

	[4] = {.5-1/16, -.5+1/16, -1/16, .5, .4999+1/32, 1/16}, -- x positive up
	[5] = {-1/16, -.5+1/16, .5-1/16, 1/16, .4999+1/32, .5}, -- z positive up
	[6] = {-.5, -.5+1/16, -1/16, -.5+1/16, .4999+1/32, 1/16}, -- x negative up
	[7] = {-1/16, -.5+1/16, -.5, 1/16, .4999+1/32, -.5+1/16}  -- z negative up
}

local selectionbox =
{
	type = "fixed",
	fixed = {-.5, -.5, -.5, .5, -.5+4/16, .5}
}

-- go to the next nodeid (ex.: 01000011 --> 01000100)
local nid_inc = function() end
nid_inc = function (nid)
	local i = 0
	while nid[i-1] ~= 1 do
		nid[i] = (nid[i] ~= 1) and 1 or 0
		i = i + 1
	end

	-- BUT: Skip impossible nodeids:
	if ((nid[0] == 0 and nid[4] == 1) or (nid[1] == 0 and nid[5] == 1)
	or (nid[2] == 0 and nid[6] == 1) or (nid[3] == 0 and nid[7] == 1)) then
		return nid_inc(nid)
	end

	return i <= 8
end

local function register_wires()
	local nid = {}
	while true do
		-- Create group specifiction and nodeid string (see note above for details)
		local nodeid = 	  (nid[0] or "0")..(nid[1] or "0")..(nid[2] or "0")..(nid[3] or "0")
				..(nid[4] or "0")..(nid[5] or "0")..(nid[6] or "0")..(nid[7] or "0")

		-- Calculate nodebox
		local nodebox = {type = "fixed", fixed={box_center}}
		for i=0,7 do
			if nid[i] == 1 then
				table.insert(nodebox.fixed, nbox_nid[i])
			end
		end

		-- Add bump to nodebox if curved
		if (nid[0] == 1 and nid[1] == 1) or (nid[1] == 1 and nid[2] == 1)
		or (nid[2] == 1 and nid[3] == 1) or (nid[3] == 1 and nid[0] == 1) then
			table.insert(nodebox.fixed, box_bump1)
		end

		-- If nothing to connect to, still make a nodebox of a straight wire
		if nodeid == "00000000" then
			nodebox.fixed = {-8/16, -.5, -1/16, 8/16, -.5+1/16, 1/16}
		end

		local rules = {}
		if (nid[0] == 1) then table.insert(rules, vector.new( 1,  0,  0)) end
		if (nid[1] == 1) then table.insert(rules, vector.new( 0,  0,  1)) end
		if (nid[2] == 1) then table.insert(rules, vector.new(-1,  0,  0)) end
		if (nid[3] == 1) then table.insert(rules, vector.new( 0,  0, -1)) end

		if (nid[0] == 1) then table.insert(rules, vector.new( 1, -1,  0)) end
		if (nid[1] == 1) then table.insert(rules, vector.new( 0, -1,  1)) end
		if (nid[2] == 1) then table.insert(rules, vector.new(-1, -1,  0)) end
		if (nid[3] == 1) then table.insert(rules, vector.new( 0, -1, -1)) end

		if (nid[4] == 1) then table.insert(rules, vector.new( 1,  1,  0)) end
		if (nid[5] == 1) then table.insert(rules, vector.new( 0,  1,  1)) end
		if (nid[6] == 1) then table.insert(rules, vector.new(-1,  1,  0)) end
		if (nid[7] == 1) then table.insert(rules, vector.new( 0,  1, -1)) end

		local meseconspec_off = { conductor = {
			rules = rules,
			state = mesecon.state.off,
			onstate = "mesecons_ito:wire_"..nodeid.."_on"
		}}

		local meseconspec_on = { conductor = {
			rules = rules,
			state = mesecon.state.on,
			offstate = "mesecons_ito:wire_"..nodeid.."_off"
		}}

		local groups_on = {dig_immediate = 3, mesecon_conductor_craftable = 1,
			not_in_creative_inventory = 1}
		local groups_off = {dig_immediate = 3, mesecon_conductor_craftable = 1}
		if nodeid ~= "00000000" then
			groups_off["not_in_creative_inventory"] = 1
		end

		mesecon.register_node("mesecons_ito:wire_"..nodeid, {
			description = "Transparent Mesecon",
			drawtype = "nodebox",
			inventory_image = "mesecons_wire_inv.png^[brighten",
			wield_image = "mesecons_wire_inv.png^[brighten",
			paramtype = "light",
			paramtype2 = "facedir",
			use_texture_alpha = true,
			sunlight_propagates = true,
			selection_box = selectionbox,
			node_box = nodebox,
			walkable = false,
			drop = "mesecons_ito:wire_00000000_off",
			mesecon_ito_wire = true
		}, {tiles = tiles_off, mesecons = meseconspec_off, groups = groups_off},
		{tiles = tiles_on, mesecons = meseconspec_on, groups = groups_on})

		if (nid_inc(nid) == false) then return end
	end
end
register_wires()
--Code from mesecons ends here


--This code is based on code from digilines by Jeija, at:
--https://github.com/minetest-mods/digilines/blob/master/wire_std.lua#L6
box_center = {-1/16, -.5, -1/16, 1/16, -.5+1/16, 1/16}
box_bump1 =  { -2/16, -8/16,  -2/16, 2/16, -13/32, 2/16 }
box_bump2 =  { -3/32, -13/32, -3/32, 3/32, -12/32, 3/32 }

box_xp = {1/16, -.5, -1/16, 8/16, -.5+1/16, 1/16}
box_zp = {-1/16, -.5, 1/16, 1/16, -.5+1/16, 8/16}
box_xm = {-8/16, -.5, -1/16, -1/16, -.5+1/16, 1/16}
box_zm = {-1/16, -.5, -8/16, 1/16, -.5+1/16, -1/16}

box_xpy = {.5-1/16, -.5+1/16, -1/16, .5, .4999+1/16, 1/16}
box_zpy = {-1/16, -.5+1/16, .5-1/16, 1/16, .4999+1/16, .5}
box_xmy = {-.5, -.5+1/16, -1/16, -.5+1/16, .4999+1/16, 1/16}
box_zmy = {-1/16, -.5+1/16, -.5, 1/16, .4999+1/16, -.5+1/16}

for xp=0, 1 do
for zp=0, 1 do
for xm=0, 1 do
for zm=0, 1 do
for xpy=0, 1 do
for zpy=0, 1 do
for xmy=0, 1 do
for zmy=0, 1 do
	if (xpy == 1 and xp == 0) or (zpy == 1 and zp == 0) 
	or (xmy == 1 and xm == 0) or (zmy == 1 and zm == 0) then break end

	local groups
	local nodeid = 	tostring(xp )..tostring(zp )..tostring(xm )..tostring(zm )..
			tostring(xpy)..tostring(zpy)..tostring(xmy)..tostring(zmy)

	if nodeid == "00000000" then
		groups = {dig_immediate = 3}
		wiredesc = "Transparent Digiline"
	else
		groups = {dig_immediate = 3, not_in_creative_inventory = 1}
	end

	local nodebox = {}
	local adjx = false
	local adjz = false
	if xp == 1 then table.insert(nodebox, box_xp) adjx = true end
	if zp == 1 then table.insert(nodebox, box_zp) adjz = true end
	if xm == 1 then table.insert(nodebox, box_xm) adjx = true end
	if zm == 1 then table.insert(nodebox, box_zm) adjz = true end
	if xpy == 1 then table.insert(nodebox, box_xpy) end
	if zpy == 1 then table.insert(nodebox, box_zpy) end
	if xmy == 1 then table.insert(nodebox, box_xmy) end
	if zmy == 1 then table.insert(nodebox, box_zmy) end

	if adjx and adjz and (xp + zp + xm + zm > 2) then
		table.insert(nodebox, box_bump1)
		table.insert(nodebox, box_bump2)
		tiles = {
			"mesecons_ito_digilines.png",
		}
	else
		table.insert(nodebox, box_center)
		tiles = {
			"mesecons_ito_digilines.png",
		}
	end

	if nodeid == "00000000" then
		nodebox = {-8/16, -.5, -1/16, 8/16, -.5+1/16, 1/16}
	end

	minetest.register_node("mesecons_ito:wire_std_"..nodeid, {
		description = wiredesc,
		drawtype = "nodebox",
		tiles = tiles,
		inventory_image = "digiline_std_inv.png^[brighten",
		wield_image = "digiline_std_inv.png^[brighten",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		use_texture_alpha = true,
		digiline = 
		{
			wire = 
			{
				basename = "mesecons_ito:wire_std_",
				use_autoconnect = true
			}
		},
		selection_box = {
              	type = "fixed",
			fixed = {-.5, -.5, -.5, .5, -.5+1/16, .5}
		},
		node_box = {
			type = "fixed",
			fixed = nodebox
		},
		groups = groups,
		walkable = false,
		stack_max = 99,
		drop = "mesecons_ito:wire_std_00000000"
	})
end
end
end
end
end
end
end
end
--Code from digilines ends here

minetest.register_craftitem("mesecons_ito:ito",{
	description = "Indium/tin/mese Mixture",
	inventory_image = "mesecons_ito_dust.png",
})

minetest.register_craft({
	type = "shapeless",
	output = "mesecons_ito:ito 8",
	recipe = {
		"technic:zinc_lump",
		"technic:zinc_lump",
		"technic:zinc_lump",
		"technic:zinc_lump",
		"technic:zinc_lump",
		"technic:zinc_lump",
		"technic:zinc_lump",
		"moreores:tin_ingot",
		"default:mese_crystal",
	},
})

minetest.register_craft({
	type = "cooking",
	output = "mesecons_ito:wire_00000000_off 25",
	recipe = "mesecons_ito:ito",
	cooktime = 3,
})

minetest.register_craft({
	output = "mesecons_ito:wire_std_00000000",
	recipe = {
		{"","",""},
		{"mesecons_ito:wire_00000000_off","mesecons_ito:wire_00000000_off","mesecons_ito:wire_00000000_off",},
		{"","default:glass",""},
	},
})
