function init( model, par )
    -- This function is called at the start of the simulation
    -- 'model' can be used to initialize the measure parameters (see LuaModel)

    min_knee_flex = par:create_from_string( "min_knee_flex", scone.min_knee_flex )
    offset = par:create_from_string( "time_offset", scone.time_offset )

    -- find knee
    -- set max knee flexion to zero
    max_flexion_r = 0
    max_flexion_l = 0

end

function update( model )
    -- This function is called at each simulation timestep
    -- Use it to update the internal variables of the measure (if needed)

    -- measure time
    local t = model:time()

    -- measure left/right knee flexion angle
    knee_r = model:find_dof("knee_angle_r")
    knee_l = model:find_dof("knee_angle_l")
    angle_r = knee_r:position() * 180 / math.pi
    angle_l = knee_l:position() * 180 / math.pi

    -- scone.debug(angle_r)

    -- compare to current max & update if max is higher
    if(angle_r * -1 > max_flexion_r and t > offset ) then
        max_flexion_r = angle_r * -1
    end

    if(angle_l * -1 > max_flexion_l and t > offset) then
        max_flexion_l = angle_l * -1
    end

    return false  -- change to 'return true' to terminate the simulation early
end

function result( model )
    -- This function is called at the end of the simulation
    -- It should return the result of the measure

    -- compare difference to min knee flexion & add difference as penalty
    tot_penalty = (max_flexion_r - min_knee_flex)^2 + (max_flexion_l-min_knee_flex)^2

    return tot_penalty
end

function store_data( frame )
    -- This function is called at each simulation timestep
    -- 'current_frame' can be used to store values for analysis (see LuaFrame)

    frame:set_value( "knee_r.max_flex", max_flexion_r )
    frame:set_value( "knee_l.max_flex", max_flexion_l )
end