local mode = TOOL.Mode

local advBsKeys = (
	SERVER and {
		"forcelimit", "torquelimit",
		"xmin", "ymin", "zmin",
		"xmax", "ymax", "zmax",
		"xfric", "yfric", "zfric",
		"onlyrotation", "nocollide",
	} or nil
)

local advBsValues = (
	SERVER and {
		0, 0,
		-0.01, -0.01, -0.01,
		0.01, 0.01, 0.01,
		0, 0, 0,
		1, 0,
	} or nil
)

local advBsKeyValues = SERVER and {} or nil
for i, value in ipairs( SERVER and advBsValues or {} ) do
	advBsKeyValues[advBsKeys[i]] = value
end

advBsKeys = nil


if CLIENT then

	TOOL.Category	= "Constraints"
	TOOL.Name		= "Rotation Matcher"

	TOOL.Information = {
		{ name = "left_0", stage = 0 },
		{ name = "left_1", stage = 1 },
		{ name = "reload" },
	}

	TOOL.ClientConVar = {
		--["width"] = 1
	}

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 2 then table.insert( a, 1, t ) elseif #a < 2 then return end
		language.Add( a[1] .. a[2], a[3] )
	end

	l( "listname", "Rotation Matcher" )
	l( "name", TOOL.Name )
	l( "desc", "Make the rotation of two entities match each other through the use of a constraint." )
	l( "left_0", "Start by selecting the first entity to constrain.")
	l( "left_1", "Finish by selecting the second entity to constrain.")
	l( "reload", "Remove any constraint that has the same values as those created by this tool.")

end




-- Similar to constraint.FindConstraints but you can specify specific values.
-- It also returns the found count and the original constraint table
-- The keys are preserved between the original and the found constraint table
local FindConstraints = ( SERVER and function( ent, constrType, values )

	local constrs = ent.Constraints
	if not constrs or ( next( constrs ) == nil ) then return {}, 0, {} end

	local foundConstrs = {}
	local foundCount = 0

	for k, constr in pairs( constrs ) do

		if IsValid( constr ) and constr.Type == constrType then

			local hasRightValues = true
			for key, value in pairs( values ) do
				if constr[key] ~= value then
					hasRightValues = false
					break
				end
			end

			if hasRightValues then
				foundConstrs[k] = constr
				foundCount = foundCount + 1
			end

		end

	end

	return foundConstrs, foundCount, constrs

end) or nil




function TOOL:LeftClick( trace )

	local ent = trace.Entity

	if IsValid( ent ) and ent:IsPlayer() then return false end

	-- If there's no physics object then we can't constraint it!
	if SERVER and not util.IsValidPhysicsObject( ent, trace.PhysicsBone ) then return false end

	local iNum = self:NumObjects()
	local phys = ent:GetPhysicsObjectNum( trace.PhysicsBone )
	self:SetObject( iNum + 1, ent, trace.HitPos, phys, trace.PhysicsBone, trace.HitNormal )

	if CLIENT then
		if iNum > 0 then self:ClearObjects() end
		return true
	end

	if iNum == 0 then
		self:SetStage( 1 )
		return true
	end

	if iNum == 1 then

		local ply = self:GetOwner()
		if not ply:CheckLimit( "constraints" ) then
			self:ClearObjects()
			return false
		end

		local ent1, ent2 = self:GetEnt( 1 ), self:GetEnt( 2 )

		local foundConstrs, foundCount = FindConstraints( ent1, "AdvBallsocket", advBsKeyValues )

		for k, constr in pairs( foundConstrs ) do
			if constr.Ent1 == ent2 or constr.Ent2 == ent2 then
				ply:ChatPrint( "[ERROR] This entity already has " .. foundCount .. " such constraint" .. (foundCount > 1 and "s." or ".") )
				self:ClearObjects()
				return false
			end
		end

		local constr = constraint.AdvBallsocket(
			ent1, ent2,								-- entities
			self:GetBone( 1 ), self:GetBone( 2 ),	-- bones
			vector_origin, vector_origin,			-- local positions
			unpack(advBsValues)
		)

		if IsValid( constr ) then

			undo.Create( "AdvBallsocket" )
				undo.AddEntity( constr )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText( "Undone Advanced Ballsocket" )
			undo.Finish()

			ply:AddCount( "constraints", constr )
			ply:AddCleanup( "constraints", constr )

		end

		-- Clear the objects so we're ready to go again
		self:ClearObjects()

	end

	return true

end




function TOOL:Reload( trace )

	if CLIENT then return true end

	local ent = trace.Entity
	if not IsValid( ent ) or ent:IsPlayer() then return false end

	local constrsToRemove, removeCount, constrs = FindConstraints( ent, "AdvBallsocket", advBsKeyValues )

	for k, constr in pairs( constrsToRemove ) do
		constr:Remove()
		constrs[k] = nil
	end

	if removeCount > 0 then
		self:GetOwner():ChatPrint("Removed " .. removeCount .. " constraint" .. (removeCount > 1 and "s." or ".") )
		return true
	end
	return false

end




function TOOL:Holster()
	self:ClearObjects()
end




function TOOL.BuildCPanel( cPanel )

	local t = "tool." .. mode .. "."
	local function l( ... )
		local a = { ... }
		if #a == 1 then table.insert( a, 1, t )
		elseif #a < 1 then return end
		return language.GetPhrase( a[1] .. a[2] )
	end

	cPanel:Help( l( "desc" ) )

end