-- controller based on Di Ruso et al. (2023)

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------- INITIALIZATION FUNCTION ----------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function init( model , par )
    -- %%% DEFINE PARAMETERS %%%

    -- read Scone parameters
    num_syn = par:create_from_string( "number_synergies", scone.number_synergies )
    grf_threshold = par:create_from_string( "grf_threshold", scone.grf_threshold )  -- percentage of body mass
    std_init = par:create_from_string( "std_init", scone.std_init )
    steps_ignore_phase_locking = par:create_from_string( "steps_ignore_phase_locking", scone.steps_ignore_phase_locking )

    -- define global variables
    grf_threshold_N = grf_threshold * model:mass()                                  -- threshold in N (% BW)
    phase_right_offset = par:create_from_mean_std( "phase_right.offset", 0, 0.01, 0, 1 )
    phase_left_offset = par:create_from_mean_std( "phase_left.offset", 0, 0.01, 0, 1 )
    phase_right = 0 + phase_right_offset                                            -- right phase
    phase_left = math.pi + phase_left_offset                                        -- left phase

    omega = par:create_from_mean_std( "omega", 4.5, 0.1, 3, 7 )                     -- angular frequency of gait
    phase_lock_gain = 0.5 
    delta_omega = 0                                                                 -- dynamic changing angular frequency
    gamma = 1                                                                       -- phase coupling factor
    stance_left_prev = true
    stance_right_prev = false 
    t_left = 0                                                                      -- initial time left
    t_right = 0                                                                     -- initial time right
    period_prev = 2 * math.pi / omega                                               -- gait cycle period
    steps = 0                                                                       -- number of steps
    num_actuators = model:actuator_count()/2                                        -- number of muscles (per side)
    calcn_l = model:find_body( "calcn_l" )                                          -- retrieve GRF values
    calcn_r = model:find_body( "calcn_r" )                                          -- retrieve GRF values
    dt = 0

    -- define analysis lists
    synergies_list = prefill_matrix( num_actuators, 2 )                             -- store synergy signals for all muscles

    -- %%% DEFINE PULSE PARAMETERS %%%
    
    -- list of bellshape mean & std from di_ruso_investigation_2023
    pulse_mean = { 0.1, 0.3, 0.5, 0.7, 0.9 }
    pulse_std = { 0.2, 0.2, 0.2, 0.2, 0.2 }
    amplitudes_mean = { 1.00, 1.00, 1.00, 1.00, 1.00 }

    -- keep a list of pulse means and std's
	pulse_mean_list = {}
	pulse_std_list = {}
    amplitudes = {}

    -- define pulse parameters
	for i = 1, num_syn do
		-- create parameters for both slope and offset
		-- pulse_mean_list[ i ] = par:create_from_mean_std( "phi" .. i, onsets_mean[ i ], 0.01, 0, 2 * math.pi )
		-- pulse_std_list[ i ] = par:create_from_mean_std( "delta" .. i, durations_mean[ i ], 0.01, 0, 2 )
        -- amplitudes[ i ] = par:create_from_mean_std( "lambda" .. i, amplitudes_mean[ i ], 0.01, 0, 2)

        pulse_mean_list[ i ] = pulse_mean[ i ]
        pulse_std_list[ i ] = pulse_std[ i ]
        amplitudes[ i ] = amplitudes_mean[ i ]
	end

    -- %%% DEFINE MUSCLE WEIGHTS %%%
    -- order:   hamstrings_r, bifemsh_r, glut_max_r, iliopsoas_r, rect_fem_r, vasti_r, gastroc_r, soleus_r, tib_ant_r
    --          hamstrings_l, bifemsh_l, glut_max_l, iliopsoas_l, rect_fem_l, vasti_l, gastroc_l, soleus_l, tib_ant_l

    muscle_names = { "glut_max", "soleus", "iliopsoas", "bifemsh", "hamstrings", "gastroc", "tib_ant", "vasti", "rect_fem"}
    muscle_amplitudes_list = {}
    for i = 1, num_actuators do
        -- muscle_amplitudes_list[ i ] = par:create_from_mean_std( muscle_names[ i ] .. ".A", 0.5, 0.01, 0.01, 5)
        muscle_amplitudes_list[ i ] = 1
    end

    weights = initialize_weights( par, num_actuators, num_syn, 0.0, std_init, -1, 1, muscle_names )

    -- act_l, act_r = generate_init_activations( phase_left_init, phase_right_init )
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------- UPDATE FUNCTION --------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function update( model )
    local t_curr = model:time()

    if( t_curr == 0 ) then
        t_prev = 0
        dt = 0.001
    else
        dt = t_curr - t_prev
    end
    t_prev = t_curr

    excitation_left, excitation_right, phase_left, phase_right = generate_synergies( phase_left, phase_right, t_curr )

    -- set muscle excitations
    for i = 1, num_actuators do
        -- add excitation to muscles
        muscle_left = model:find_muscle( muscle_names[ i ] .. "_l" )
        muscle_left:add_input( excitation_left[ i ] )

        muscle_right = model:find_muscle( muscle_names[ i ] .. "_r" )
        muscle_right:add_input( excitation_right[ i ] )
    end

    return false;
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------- CPG FUNCTION ---------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- function to generate rectangular pulse signals
function generate_bellshape_pulses( phase , mu , sigma )
    -- create list to store pulses
    pulses = {}

    -- iterate over all synergies 
    for i = 1, num_syn do
        if phase >= mu[ i ] - sigma[ i ] and phase <= mu[ i ] + sigma[ i ] then
            pulses[ i ] = 1/2 * ( 1 + math.cos( ( phase - mu[ i ] ) / sigma[ i ] * math.pi ))
        else
            pulses[ i ] = 0
        end
    end

    return pulses;
end

function update_phase( omega, gamma , phase_left_t, phase_right_t, t )

    -- dt = 0.001
    stance_left, stance_right = update_stance_left_right( calcn_l, calcn_r )

    d_phase_left_dt = omega + delta_omega - gamma * math.sin( phase_left_t - phase_right_t - math.pi )
    d_phase_right_dt = omega + delta_omega - gamma * math.sin( phase_right_t - phase_left_t - math.pi )

    if( stance_left and not stance_left_prev ) then
        phase_left_tp1 = 0
        -- delta_omega = update_delta_omega( t, "left" )
    else
        phase_left_tp1 = d_phase_left_dt * dt + phase_left_t
    end

    if( stance_right and not stance_right_prev ) then 
        phase_right_tp1 = 0
        -- delta_omega = update_delta_omega( t, "right" )
    else
        phase_right_tp1 = d_phase_right_dt * dt + phase_right_t
    end

    stance_left_prev = stance_left
    stance_right_prev = stance_right

    return phase_left_tp1, phase_right_tp1

end

function generate_synergies( phase_left, phase_right, t )

    -- compute rectangular pulses
    pulses_left = generate_bellshape_pulses( phase_left / ( 2 * math.pi ) , pulse_mean_list , pulse_std_list )
    pulses_right = generate_bellshape_pulses( phase_right / ( 2 * math.pi ) , pulse_mean_list , pulse_std_list )

    weight_pulses_left = {}     -- pulses * amplitude
    weight_pulses_right = {}
    for i = 1, num_syn do
        weight_pulses_left[ i ] = amplitudes[ i ] * pulses_left[ i ]
        weight_pulses_right[ i ] = amplitudes[ i ] * pulses_right[ i ]
    end

    -- compute synergies
    synergies_left = {}
    synergies_right = {}
    for i = 1, num_actuators do
        -- compute excitation
        synergies_left[ i ] = muscle_amplitudes_list[ i ] * scalar_product( weights[ i ] ,  pulses_left)
        synergies_right[ i ] = muscle_amplitudes_list[ i ] * scalar_product( weights[ i ] ,  pulses_right)
    end

    -- update phase
    phase_left, phase_right = update_phase( omega, gamma, phase_left, phase_right, t )

    return synergies_left, synergies_right, phase_left, phase_right

end

-- function to update whether we are in stance based on the vertical GRF
function update_stance( grf_y )
    if( grf_y > grf_threshold_N ) then 
        return true;
    else
        return false;
    end
end

-- computes whether we are in stance for the left & right leg
function update_stance_left_right( calcn_l_body, calcn_r_body )
    grf_left = calcn_l:contact_force(); grf_left_y = grf_left.y 
    grf_right = calcn_r:contact_force(); grf_right_y = grf_right.y 

    return update_stance( grf_left_y ), update_stance( grf_right_y )
end

-- updates period/angular frequency
function update_delta_omega( t, side )
    steps = steps + 1
    if( side == "left" ) then 
        period = t - t_left 
        t_left = t
        if( t > period_prev ) then 
            period_prev = period_prev + phase_lock_gain * ( period - period_prev )
        end
        if( steps > steps_ignore_phase_locking ) then
            return 2 * math.pi / period_prev - omega
        end
    else
        period = t - t_right 
        t_right = t 
        if( t > period_prev ) then 
            period_prev = period_prev + phase_lock_gain * ( period - period_prev )
        end
        if( steps > steps_ignore_phase_locking ) then
            return 2 * math.pi / period_prev - omega
        end
    end
    return 0 -- return zero if steps > steps_ignore_phase_locking
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------ SAVE DATA FUNCTION ------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- function to store data in Scone
function store_data( frame )
    -- store some values for analysis
    frame:set_value( "phase_right", phase_right )
    frame:set_value( "phase_left", phase_left )
    frame:set_value( "delta_omega", delta_omega )

    frame:set_value( "t_left", t_left )
    frame:set_value( "t_right", t_right )
    frame:set_value( "period", period_prev )
    frame:set_value( "dt", dt )

    frame:set_value( "stance_right", stance_right and 1 or 0)
    frame:set_value( "stance_left", stance_left and 1 or 0 )

    for i = 1,num_syn do
        frame:set_value( "pulse_left" .. i, pulses_left[ i ])
        frame:set_value( "pulse_right" .. i, pulses_right[ i ])
    end

    -- set muscle excitations
    for i = 1, num_actuators do
        frame:set_value( muscle_names[ i ] .. "_l.synergy", synergies_left[ i ] )
        frame:set_value( muscle_names[ i ] .. "_r.synergy", synergies_right[ i ] )
    end

end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------- DEBUG FUNCTION --------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- function to report matrix
function debug_matrix( matrix )

    for i = 1, #matrix do
        rowString = "|\t"
        for j = 1, #matrix[ 1 ] do
            rowString = rowString .. tostring(matrix[ i ][ j ]) .. "\t"
        end
        rowString = rowString .. "|"
        scone.debug(rowString)
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------- MATHS FUNCTION --------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function scalar_product(v1 , v2)

    N1 = #v1
    N2 = #v2

    if N1 ~= N2 then
        error("Check matrix dimensions!")
    end

    result = 0
    for i = 1, N1 do
        result = result + v1[ i ] * v2[ i ]
    end

    return result;
end

function prefill_matrix( size1, size2 )

    if size2 == 1 then
        matrix = {} 
        for i = 1, size1 do
            matrix[ i ] = 0
        end
    else
        matrix = {}                            -- create the matrix
        for i = 1, size1 do
            matrix[ i ] = {}
            for j = 1, size2 do
                matrix[ i ][ j ] = 0
            end
        end
    end

    return matrix;
end

function initialize_weights( par, size1, size2, mean, std, min, max, muscle_names )

    weights = {}                            -- create the matrix
    for i = 1, size1 do
        weights[ i ] = {}
        for j = 1, size2 do
            weights[ i ][ j ] = par:create_from_mean_std( muscle_names[ i ] .. ".w" .. j, mean, std, min, max )
        end
    end

    return weights;
end


function sum_vectors( v1, v2 )
    N1 = #v1
    N2 = #v2

    if N1 ~= N2 then
        error("Check matrix dimensions!")
    end

    result = {}
    for i = 1, N1 do
        result[ i ] = v1[ i ] + v2[ i ]
    end

    return result;
end