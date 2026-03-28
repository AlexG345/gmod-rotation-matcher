local mode = TOOL.Mode


if CLIENT then

	TOOL.Category	= "Constraints"
	TOOL.Name		= "Rotation Matcher"

	TOOL.Information = {
		{ name = "left_0", stage = 0 },
		{ name = "left_1", stage = 1 },
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
	l( "desc", "Make the rotation of two entities match each other." )
	l( "left_0", "Start by selecting the first entity to constrain.")
	l( "left_1", "Finish by selecting the second entity to constrain.")

end


function TOOL:LeftClick( trace )

	local ent = trace.Entity

	if IsValid( ent ) and ent:IsPlayer() then return false end

	-- If there's no physics object then we can't constraint it!
	if SERVER and !util.IsValidPhysicsObject( ent, trace.PhysicsBone ) then return false end

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

		local constr = constraint.AdvBallsocket(
			self:GetEnt( 1 ), self:GetEnt( 2 ),		-- entities
			self:GetBone( 1 ), self:GetBone( 2 ),	-- bones
			vector_origin, vector_origin,			-- local positions
			0, 0,									-- force/torque limits
			-0.01, -0.01, -0.01,					-- axis minimums
			0.01, 0.01, 0.01,						-- axis maximums
			0, 0, 0,								-- axis frictions
			1, 0									-- only rotation, no collide (0 for false, 1 for true)
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