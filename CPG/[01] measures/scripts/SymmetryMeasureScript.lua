function init( model, par )
    -- This function is called at the start of the simulation
    -- 'model' can be used to initialize the measure parameters (see LuaModel)

    com_limit = par:create_from_string( "com_limit", scone.com_limit )
    failure_offset = par:create_from_string( "failure_offset", scone.failure_offset )
    muscle_act_weight = par:create_from_string( "muscle_act_weight", scone.muscle_act_weight )
    value_weight = par:create_from_string( "value_weight", scone.value_weight )
    speed_weight = par:create_from_string( "speed_weight", scone.speed_weight )

    tot_err = 0
    muscle_act_error = 0
    value_error = 0
    speed_error = 0

    num_actuators = model:actuator_count()
    num_dofs = model:dof_count()

    start = true
    failed = false

end

function update( model )
    -- This function is called at each simulation timestep
    -- Use it to update the internal variables of the measure (if needed)

    local t = model:time()

    -- saves values at start of gait cycle
    if( start ) then
        -- save muscle activations
        muscle_act_init = {}
        for i = 1, num_actuators do 
            muscle = model:muscle( i )
            muscle_act_init[ i ] = muscle:activation()
        end
        -- save joint angles
        value_init = {}
        speed_init = {}
        for i = 1, num_dofs do 
            dof = model:dof( i )
            value_init[ i ] = dof:position()
            speed_init[ i ] = dof:velocity()
        end
        -- end initial value capture
        start = false
    end

    -- compare values after 1 gait cycle with those at the start 
    if( math.fmod( t, model:get_custom_value( "period_global" ) ) < 1e-10 and not start ) then
        for i = 1, num_actuators do
            muscle = model:muscle( i )
            muscle_act_curr = muscle:activation()
            muscle_act_error = muscle_act_error + ( muscle_act_curr - muscle_act_init[ i ] )^2
        end

        for i = 1, num_dofs do 
            dof = model:dof( i )
            value_curr = dof:position()
            speed_curr = dof:velocity()

            value_error = value_error + ( value_curr - value_init[ i ] )^2
            speed_error = speed_error + ( speed_curr - speed_init[ i ] )^2
        end

        tot_err = tot_err + muscle_act_weight * muscle_act_error + value_weight * value_error + speed_weight * speed_error
    end

    com_height = model:com_pos().y

    if(com_height < com_limit) then
        tot_err = tot_err + failure_offset 
        failed = true
    end

    return failed  -- change to 'return true' to terminate the simulation early
end

function result( model )
    -- This function is called at the end of the simulation
    -- It should return the result of the measure
    return 10/(model:time()+0.1)
end

function store_data( current_frame )
    -- This function is called at each simulation timestep
    -- 'current_frame' can be used to store values for analysis (see LuaFrame)
end