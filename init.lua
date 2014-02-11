-- floatindev 0.2.0 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL

-- Parameters

local YMIN = 128 -- Approximate realm limits.
local YMAX = 33000
local XMIN = -33000
local XMAX = 33000
local ZMIN = -33000
local ZMAX = 33000

local CHUINT = 2 -- Chunk interval for floatland layers
local WAVAMP = 16 -- Structure wave amplitude
local HISCAL = 24 -- Upper structure vertical scale
local LOSCAL = 24 -- Lower structure vertical scale
local HIEXP = 0.5 -- Upper structure density gradient exponent
local LOEXP = 0.5 -- Lower structure density gradient exponent
local CLUSAV = 0 -- Large scale variation average
local CLUSAM = 0 -- Large scale variation amplitude
local DIRTHR = 0.04 -- Dirt density threshold
local STOTHR = 0.08 -- Stone density threshold
local STABLE = 2 -- Minimum number of stacked stone nodes in column for dirt / sand on top

local APPCHA = 0.02 -- Appletree chance
local FLOCHA = 0.02 -- Flower chance
local GRACHA = 0.11 -- Grass chance
local ORECHA = 1 / (5 * 5 * 5)

-- 3D noise for floatlands

local np_float = {
	offset = 0,
	scale = 1,
	spread = {x=256, y=256, z=256},
	seed = 277777979,
	octaves = 6,
	persist = 0.6
}

-- 3D noise for caves

local np_caves = {
	offset = 0,
	scale = 1,
	spread = {x=8, y=8, z=8},
	seed = -89000,
	octaves = 2,
	persist = 0.5
}

-- 3D noise for large scale floatland size/density variation

local np_cluster = {
	offset = 0,
	scale = 1,
	spread = {x=2048, y=2048, z=2048},
	seed = 23,
	octaves = 1,
	persist = 0.5
}

-- 2D noise for wave

local np_wave = {
	offset = 0,
	scale = 1,
	spread = {x=256, y=256, z=256},
	seed = -400000000089,
	octaves = 3,
	persist = 0.5
}

-- 2D noise for biome

local np_biome = {
	offset = 0,
	scale = 1,
	spread = {x=250, y=250, z=250},
	seed = 9130,
	octaves = 3,
	persist = 0.5
}

-- Stuff

floatindev = {}

-- Nodes

minetest.register_node("floatindev:stone", {
	description = "FLI Stone",
	tiles = {"default_stone.png"},
	is_ground_content = false, -- stops cavegen removing this node
	groups = {cracky=3},
	drop = "default:cobble",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("floatindev:desertstone", {
	description = "FLI Desert Stone",
	tiles = {"default_desert_stone.png"},
	is_ground_content = false, -- stops cavegen removing this node
	groups = {cracky=3},
	drop = "default:desert_stone",
	sounds = default.node_sound_stone_defaults(),
})

-- Functions

local function floatindev_appletree(x, y, z, area, data)
	local c_tree = minetest.get_content_id("default:tree")
	local c_apple = minetest.get_content_id("default:apple")
	local c_leaves = minetest.get_content_id("default:leaves")
	for j = -2, 4 do
		if j >= 1 then
			for i = -2, 2 do
			for k = -2, 2 do
				local vi = area:index(x + i, y + j + 1, z + k)
				if math.random(48) == 2 then
					data[vi] = c_apple
				elseif math.random(3) ~= 2 then
					data[vi] = c_leaves
				end
			end
			end
		end
		local vi = area:index(x, y + j, z)
		data[vi] = c_tree
	end
end

local function floatindev_grass(data, vi)
	local c_grass1 = minetest.get_content_id("default:grass_1")
	local c_grass2 = minetest.get_content_id("default:grass_2")
	local c_grass3 = minetest.get_content_id("default:grass_3")
	local c_grass4 = minetest.get_content_id("default:grass_4")
	local c_grass5 = minetest.get_content_id("default:grass_5")
	local rand = math.random(5)
	if rand == 1 then
		data[vi] = c_grass1
	elseif rand == 2 then
		data[vi] = c_grass2
	elseif rand == 3 then
		data[vi] = c_grass3
	elseif rand == 4 then
		data[vi] = c_grass4
	else
		data[vi] = c_grass5
	end
end

local function floatindev_flower(data, vi)
	local c_danwhi = minetest.get_content_id("flowers:dandelion_white")
	local c_danyel = minetest.get_content_id("flowers:dandelion_yellow")
	local c_rose = minetest.get_content_id("flowers:rose")
	local c_tulip = minetest.get_content_id("flowers:tulip")
	local c_geranium = minetest.get_content_id("flowers:geranium")
	local c_viola = minetest.get_content_id("flowers:viola")
	local rand = math.random(6)
	if rand == 1 then
		data[vi] = c_danwhi
	elseif rand == 2 then
		data[vi] = c_rose
	elseif rand == 3 then
		data[vi] = c_tulip
	elseif rand == 4 then
		data[vi] = c_danyel
	elseif rand == 5 then
		data[vi] = c_geranium
	else
		data[vi] = c_viola
	end
end

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.x < XMIN or maxp.x > XMAX
	or minp.y < YMIN or maxp.y > YMAX
	or minp.z < ZMIN or maxp.z > ZMAX then
		return
	end
	local chulay = math.floor((minp.y + 32) / 80) -- chunk layer number, 0 = surface chunk
	if math.fmod(chulay, CHUINT) ~= 0 then -- if chulay / CHUINT has a remainder
		return
	end

	local t1 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	print ("[floatindev] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_air = minetest.get_content_id("air")
	local c_stodiam = minetest.get_content_id("default:stone_with_diamond")
	local c_stomese = minetest.get_content_id("default:stone_with_mese")
	local c_stogold = minetest.get_content_id("default:stone_with_gold")
	local c_stocopp = minetest.get_content_id("default:stone_with_copper")
	local c_stoiron = minetest.get_content_id("default:stone_with_iron")
	local c_stocoal = minetest.get_content_id("default:stone_with_coal")
	local c_grass = minetest.get_content_id("default:dirt_with_grass")
	local c_dirt = minetest.get_content_id("default:dirt")
	local c_desand = minetest.get_content_id("default:desert_sand")
	
	local c_flistone = minetest.get_content_id("floatindev:stone")
	local c_flidestone = minetest.get_content_id("floatindev:desertstone")
	
	local sidelen = x1 - x0 + 1
	local chulens = {x=sidelen, y=sidelen, z=sidelen}
	local minposxyz = {x=x0, y=y0, z=z0}
	local minposxz = {x=x0, y=z0}
	
	local nvals_float = minetest.get_perlin_map(np_float, chulens):get3dMap_flat(minposxyz)
	local nvals_caves = minetest.get_perlin_map(np_caves, chulens):get3dMap_flat(minposxyz)
	local nvals_cluster = minetest.get_perlin_map(np_cluster, chulens):get3dMap_flat(minposxyz)
	
	local nvals_wave = minetest.get_perlin_map(np_wave, chulens):get2dMap_flat(minposxz)
	local nvals_biome = minetest.get_perlin_map(np_biome, chulens):get2dMap_flat({x=x0+150, y=z0+50})
	
	local nixyz = 1
	local nixz = 1
	local stable = {}
	local dirt = {}
	local chumid = y0 + sidelen / 2
	for z = z0, z1 do -- for each xy plane progressing northwards
		for x = x0, x1 do
			local si = x - x0 + 1
			dirt[si] = 0
			local nodename = minetest.get_node({x=x,y=y0-1,z=z}).name
			if nodename == "air"
			or nodename == "default:water_source" then
				stable[si] = 0
			else -- all else including ignore in ungenerated chunks
				stable[si] = STABLE
			end
		end
		for y = y0, y1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z)
			for x = x0, x1 do -- for each node do
				local si = x - x0 + 1
				local flomid = chumid + nvals_wave[nixz] * WAVAMP
				local grad
				if y > flomid then
					grad = ((y - flomid) / HISCAL) ^ HIEXP
				else
					grad = ((flomid - y) / LOSCAL) ^ LOEXP
				end
				local density = nvals_float[nixyz] - grad + CLUSAV + nvals_cluster[nixyz] * CLUSAM
				if density > 0 and density < 0.7 then -- if floatland shell
					if nvals_caves[nixyz] - density > -0.7 then -- if no cave
						if y > flomid and density < STOTHR and stable[si] >= STABLE then
							if nvals_biome[nixz] > 0.45 then -- fine materials
								data[vi] = c_desand
							else
								if density < DIRTHR then
									data[vi] = c_grass
								else
									data[vi] = c_dirt
								end
								dirt[si] = dirt[si] + 1
							end
						else
							if nvals_biome[nixz] > 0.45 then -- stone
								data[vi] = c_flidestone
							elseif math.random() < ORECHA then
								local osel = math.random(34)
								if osel == 34 then
									data[vi] = c_stodiam
								elseif osel >= 31 then
									data[vi] = c_stomese
								elseif osel >= 28 then
									data[vi] = c_stogold
								elseif osel >= 19 then
									data[vi] = c_stocopp
								elseif osel >= 10 then
									data[vi] = c_stoiron
								else
									data[vi] = c_stocoal
								end
							else
								data[vi] = c_flistone
							end
							stable[si] = stable[si] + 1
						end
					else -- cave
						stable[si] = 0
					end
				elseif y > flomid and density < 0 and dirt[si] >= 1 then -- node above surface dirt
					if dirt[si] >= 2 and math.random() < APPCHA then
						floatindev_appletree(x, y, z, area, data)
					elseif math.random() < FLOCHA then
						floatindev_flower(data, vi)
					elseif math.random() < GRACHA then
						floatindev_grass(data, vi)
					end
					dirt[si] = 0
				else -- atmosphere
					stable[si] = 0
				end
				nixyz = nixyz + 1
				nixz = nixz + 1
				vi = vi + 1
			end
			nixz = nixz - 80
		end
		nixz = nixz + 80
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	local chugent = math.ceil((os.clock() - t1) * 1000)
	print ("[floatindev] "..chugent.." ms")
end)