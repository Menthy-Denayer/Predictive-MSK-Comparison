function init( model, par )
    -- This function is called at the start of the simulation
    -- 'model' can be used to initialize the measure parameters (see LuaModel)

    t_end = model:max_duration()
    init_com_y = model:com_pos().y 
    init_com_x = model:com_pos().x
    termination_height = par:create_from_string( "termination_height", scone.termination_height )

end

function update( model )
    -- This function is called at each simulation timestep
    -- Use it to update the internal variables of the measure (if needed)

    local t = model:time()

    if( model:com_pos().y < termination_height * init_com_y ) then
        staying_alive_reward = math.abs( t - t_end )
        forward_movement_reward = math.max( 1 / t_end, 1 / (math.abs( model:com_pos().x - init_com_x ) ) ) 
        penalty = staying_alive_reward + forward_movement_reward
    end
    return false  -- change to 'return true' to terminate the simulation early
end

function result( model )
    -- This function is called at the end of the simulation
    -- It should return the result of the measure
    return penalty
end

-- function store_data( frame )
--     -- This function is called at each simulation timestep
--     -- 'current_frame' can be used to store values for analysis (see LuaFrame)

--     frame:set_value( "alive reward", penalty ) 
-- end