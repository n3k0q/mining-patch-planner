local common = {}

local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max

---@param miner MinerStruct
function common.simple_miner_placement(miner)
	local near, far, size, fullsize = miner.near, miner.far, miner.size, miner.full_size
	local neighbor_cap = (near + 1) ^ 2
	local leech = (far + 1) ^ 2

	---@param center GridTile
	return function(center)
		return center.neighbor_count > neighbor_cap
		-- return center.neighbor_count > neighbor_cap or center.far_neighbor_count > leech
	end
end

---@param miner MinerStruct
function common.overfill_miner_placement(miner)
	local near, far, size, fullsize = miner.near, miner.far, miner.size, miner.full_size
	local neighbor_cap = (near + 1) ^ 2 - 1
	local leech = (far + 1) ^ 2 - 1

	---@param center GridTile
	return function(center)
		return center.neighbor_count > 0 or center.far_neighbor_count > neighbor_cap
	end
end

---@param attempt PlacementAttempt
function common.simple_layout_heuristic(attempt)
	return (attempt.real_density - attempt.simple_density) * math.log(#attempt.lane_layout)
end

---@param attempt PlacementAttempt
function common.overfill_layout_heuristic(attempt)
	return attempt.simple_density - attempt.real_density -- * math.log(#attempt.lane_layout)
end

---Utility to fill in postponed miners on unconsumed resources
---@param state SimpleState
---@param heuristics PlacementAttempt
---@param miners MinerPlacement[]
---@param postponed MinerPlacement[]
function common.process_postponed(state, heuristics, miners, postponed)
	local grid = state.grid
	local size, near, far, fullsize = state.miner.size, state.miner.near, state.miner.far, state.miner.full_size

	for _, miner in ipairs(miners) do
		grid:consume(miner.center.x, miner.center.y)
	end

	for _, miner in ipairs(postponed) do
		local center = miner.center
		miner.unconsumed = grid:get_unconsumed(center.x, center.y)
	end

	table.sort(postponed, function(a, b)
		if a.unconsumed == b.unconsumed then
			local a_center, b_center = a.center, b.center
			if a_center.neighbor_count == b_center.neighbor_count then
				return a_center.far_neighbor_count > b_center.far_neighbor_count
			end
			return a_center.neighbor_count > b_center.neighbor_count
		end
		return a.unconsumed > b.unconsumed
	end)

	for _, miner in ipairs(postponed) do
		local center = miner.center
		local unconsumed_count = grid:get_unconsumed(center.x, center.y)
		if unconsumed_count > 0 then
			heuristics.neighbor_sum = heuristics.neighbor_sum + center.neighbor_count
			heuristics.far_neighbor_sum = heuristics.far_neighbor_sum + center.far_neighbor_count
			heuristics.simple_density = heuristics.simple_density + center.neighbor_count / (size ^ 2)
			heuristics.real_density = heuristics.real_density + center.far_neighbor_count / (fullsize ^ 2)
			heuristics.leech_sum = heuristics.leech_sum + max(0, center.far_neighbor_count - center.neighbor_count)
			heuristics.postponed_count = heuristics.postponed_count + 1

			grid:consume(center.x, center.y)
			miners[#miners+1] = miner
			miner.postponed = true
		end
	end
	local unconsumed_sum = 0
	for _, tile in ipairs(state.resource_tiles) do
		if not tile.consumed then unconsumed_sum = unconsumed_sum + 1 end
	end
	heuristics.unconsumed_count = unconsumed_sum
	
	grid:clear_consumed(state.resource_tiles)
end

return common
