-- floatindev 0.3.1 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL

-- use voxelmanip for scanning chunk below
-- use sidelen, works with any chunksize

-- Parameters

local YMIN = 1 -- Approximate realm limits
local YMAX = 33000
local XMIN = -33000
local XMAX = 33000
local ZMIN = -33000
local ZMAX = 33000

local CHUINT = 8 -- Chunk interval for floatland layers
local WAVAMP = 48 -- Structure wave amplitude
local HISCAL = 96 -- Upper structure vertical scale
local LOSCAL = 96 -- Lower structure vertical scale
local HIEXP = 0.33 -- Upper structure density gradient exponent
local LOEXP = 0.33 -- Lower structure density gradient exponent
local CLUSAV = 0 -- Large scale variation average
local CLUSAM = 0 -- Large scale variation amplitude
local TSTONE = 0.1 -- Stone density threshold
local TTUN = 0.03 -- Tunnel width
local TVOID = 0.6 -- Void threshold
local FLOCHA = 1 / 17 ^ 3 -- Floc chance per stone node

-- 3D noise for floatlands

local np_float = {
	offset = 0,
	scale = 1,
	spread = {x=384, y=192, z=384},
	seed = 277777979,
	octaves = 5,
	persist = 0.67
}

-- 3D noises for tunnels

local np_weba = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = -89000,
	octaves = 3,
	persist = 0.5
}

local np_webb = {
	offset = 0,
	scale = 1,
	spread = {x=127, y=127, z=127},
	seed = 85911,
	octaves = 3,
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

-- 3D noise for wave

local np_wave = {
	offset = 0,
	scale = 1,
	spread = {x=512, y=512, z=512},
	seed = -4000000089,
	octaves = 3,
	persist = 0.4
}

-- Stuff

floatindev = {}

-- Nodes

minetest.register_node("floatindev:floatstone", {
	description = "Floatstone",
	tiles = {"floatindev_floatstone.png"},
	is_ground_content = false, -- stops cavegen removing this node
	groups = {cracky=3},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("floatindev:floatsand", {
	description = "Floatsand",
	tiles = {"floatindev_floatsand.png"},
	is_ground_content = false,
	groups = {crumbly=3, falling_node=1, sand=1},
	sounds = default.node_sound_sand_defaults(),
})

minetest.register_node("floatindev:floc", {
	description = "Float crystal block",
	tiles = {"floatindev_floc.png"},
	is_ground_content = false,
	groups = {cracky=1},
	sounds = default.node_sound_stone_defaults(),
})

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.x < XMIN or maxp.x > XMAX
	or minp.y < YMIN or maxp.y > YMAX
	or minp.z < ZMIN or maxp.z > ZMAX then
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
	local c_water = minetest.get_content_id("default:water_source")
	
	local c_floatstone = minetest.get_content_id("floatindev:floatstone")
	local c_floatsand = minetest.get_content_id("floatindev:floatsand")
	local c_floc = minetest.get_content_id("floatindev:floc")
	
	local sidelen = x1 - x0 + 1
	local chulens = {x=sidelen, y=sidelen, z=sidelen}
	local minposxyz = {x=x0, y=y0, z=z0}
	
	local nvals_float = minetest.get_perlin_map(np_float, chulens):get3dMap_flat(minposxyz)
	local nvals_weba = minetest.get_perlin_map(np_weba, chulens):get3dMap_flat(minposxyz)
	local nvals_webb = minetest.get_perlin_map(np_webb, chulens):get3dMap_flat(minposxyz)
	local nvals_cluster = minetest.get_perlin_map(np_cluster, chulens):get3dMap_flat(minposxyz)
	local nvals_wave = minetest.get_perlin_map(np_wave, chulens):get3dMap_flat(minposxyz)
	
	local chulay = math.floor((minp.y + 32) / 80) -- chunk layer number, 0 = surface chunk
	local tercen = (math.floor(chulay / CHUINT) * CHUINT + CHUINT / 2) * 80 - 32 -- terrain centre of this layer

	local nixyz = 1
	local nixz = 1
	local stable = {}
	for z = z0, z1 do -- for each xy plane progressing northwards
		local viu = area:index(x0, y0-1, z) -- initialise stability table
		for x = x0, x1 do
			local si = x - x0 + 1
			local nodidu = data[viu]
			if nodidu == c_air
			or nodidu == c_water then
				stable[si] = 0
			else -- all else including ignore in ungenerated chunks
				stable[si] = 2
			end
			viu = viu + 1
		end
		for y = y0, y1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z)
			for x = x0, x1 do -- for each node do
				local si = x - x0 + 1
				local flomid = tercen + nvals_wave[nixyz] * WAVAMP -- y of floatland middle

				local grad -- density for node
				if y > flomid then
					grad = ((y - flomid) / HISCAL) ^ HIEXP
				else
					grad = ((flomid - y) / LOSCAL) ^ LOEXP
				end
				local density = nvals_float[nixyz] - grad + CLUSAV + nvals_cluster[nixyz] * CLUSAM

				local weba = math.abs(nvals_weba[nixyz]) < TTUN -- check for tunnel
				local webb = math.abs(nvals_webb[nixyz]) < TTUN
				local notun = not (weba and webb)

				if density > 0 and density < TVOID and notun then -- if floatland shell
					if y > flomid and density < TSTONE and stable[si] >= 2 then
						data[vi] = c_floatsand -- sand
					else
						if math.random() < FLOCHA then
							data[vi] = c_floc -- floc
						else
							data[vi] = c_floatstone -- stone
						end
						stable[si] = stable[si] + 1
					end
				else -- air
					stable[si] = 0
				end
				nixyz = nixyz + 1
				nixz = nixz + 1
				vi = vi + 1
			end
			nixz = nixz - sidelen
		end
		nixz = nixz + sidelen
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	local chugent = math.ceil((os.clock() - t1) * 1000)
	print ("[floatindev] "..chugent.." ms")
end)
