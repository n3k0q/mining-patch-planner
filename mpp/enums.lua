local enums = {}

---@type LuaEntityPrototype[]
local cached_miners = {}
---@type table<string, boolean>
local cached_resource_categories = {}

local invalid_resource = { --fluid or otherwise
	["se-core-mining"] = true,
}
local miner_blacklist = {
	["se-core-miner-drill"] = true
}

function enums.get_default_miner()
	if script.active_mods["nullius"] then
		return "nullius-medium-miner-1"
	end
	return "electric-mining-drill"
end

local FMD_active = script.active_mods["Cursed-FMD"]

---Get mining drills and resource categories
---@return LuaEntityPrototype[], table
function enums.get_available_miners()
	enums.get_available_miners = function() return cached_miners, cached_resource_categories end

	local all_miners = prototypes.get_entity_filtered{{filter="type", type="mining-drill"}}
	---@type table<string, LuaEntityPrototype>
	--local all_fluids = game.get_filtered_item_prototypes({filter="type", type="
	local all_resources = prototypes.get_entity_filtered{{filter="type", type="resource"}}
	---@type table<string, LuaResourceCategoryPrototype>

	for name, proto in pairs(all_resources) do
		---@cast proto LuaEntityPrototype
		local mineable_properties = proto.mineable_properties

		if mineable_properties.products then
			for _, product in ipairs(mineable_properties.products) do
				if product.type == "fluid" then
					invalid_resource[name] = true
					break
				end
			end
		else
			invalid_resource[name] = true
			break
		end
	end

	for miner_name, miner_proto in pairs(all_miners) do
		if miner_blacklist[miner_name] then goto continue_miner end
		if miner_proto.resource_categories then
			for resource_cat, bool in pairs(miner_proto.resource_categories) do
				if invalid_resource[resource_cat] then
					miner_blacklist[miner_name] = true
				end
			end
		else
			miner_blacklist[miner_name] = true
			goto continue_miner
		end

		---@cast miner_proto LuaEntityPrototype
		local fluidboxes = miner_proto.fluidbox_prototypes
		for _, fluidbox in pairs(fluidboxes) do
			---@cast fluidbox LuaFluidBoxPrototype
			if fluidbox.production_type == "output" then
				miner_blacklist[miner_name] = true
			end
		end
		::continue_miner::
	end

	local miners = {}
	local resource_categories = {
		["basic-solid"] = true,
		["hard-resource"] = true,
	}
	for name, proto in pairs(all_miners) do
		if FMD_active and string.find(name, "__") then goto continue_miner end
		if proto.hidden then goto continue_miner end
		if miner_blacklist[name] then goto continue_miner end
		--if not proto.resource_categories["basic-solid"] then goto continue_miner end
		for resource_category, bool in pairs(proto.resource_categories) do
			resource_categories[resource_category] = bool
		end

		miners[name] = proto

		::continue_miner::
	end

	cached_miners = miners
	cached_resource_categories = resource_categories
	--[[ {
		["basic-solid"] = true,
		["hard-resource"] = true,
	}]]
	return enums.get_available_miners()
end

enums.space_surfaces = {
	["asteroid-belt"] = true,
	["asteroid-field"] = true,
	["orbit"] = true,
	["anomaly"] = true,
}

return enums
