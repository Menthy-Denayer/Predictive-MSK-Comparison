function init( model, par )
    -- This function is called at the start of the simulation
    -- 'model' can be used to initialize the measure parameters (see LuaModel)

    vel_threshold = par:create_from_string( "velocity_threshold", scone.velocity_threshold)
    com_threshold = par:create_from_string( "com_height_threshold", scone.com_height_threshold)

    calcn_l = model:find_body("calcn_l")
    calcn_r = model:find_body("calcn_r")
    loc_l = vec3:new(0.185, 0.015, 0)
    loc_r = vec3:new(0.185, 0.015, 0)

    penalty = 0

end

function update( model )
    -- This function is called at each simulation timestep
    -- Use it to update the internal variables of the measure (if needed)

    local t = model:time()

    com_y_l = calcn_l:com_pos().y
    com_y_r = calcn_r:com_pos().y

    vel_l = calcn_l:point_vel(loc_l).x
    vel_r = calcn_r:point_vel(loc_r).x

    grf_left = calcn_l:contact_force().y 
    grf_right = calcn_r:contact_force().y 

    if( math.abs( vel_l ) > vel_threshold and com_y_l > com_threshold ) then 
        penalty = penalty + math.abs( vel_l * grf_left )
    end 

    if( math.abs( vel_r ) > vel_threshold and com_y_r > com_threshold ) then 
        penalty = penalty + math.abs( vel_r * grf_right )
    end

    return false  -- change to 'return true' to terminate the simulation early
end

function result( model )
    -- This function is called at the end of the simulation
    -- It should return the result of the measure
    return penalty
end

function store_data( frame )
    -- This function is called at each simulation timestep
    -- 'current_frame' can be used to store values for analysis (see LuaFrame)

    frame:set_value( "com_y_l", com_y_l )
    frame:set_value( "com_y_r", com_y_r )
    frame:set_value( "toe_vel_l", vel_l )
    frame:set_value( "toe_vel_r", vel_r )
    frame:set_value( "grf_l", grf_left )
    frame:set_value( "grf_r", grf_right )
    frame:set_value( "sliding penalty", penalty )
end