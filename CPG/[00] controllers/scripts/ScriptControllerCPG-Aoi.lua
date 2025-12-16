--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------- INITIALIZATION FUNCTION ----------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function init( model , par )
    -- %%% DEFINE PARAMETERS %%%

    -- read Scone parameters
    num_syn = par:create_from_string( "number_synergies", scone.number_synergies )
    des_speed = par:create_from_string( "desired_speed", scone.desired_speed )
    period_mean = par:create_from_string( "desired_period", scone.desired_period )
    max_weight = par:create_from_string( "maximum_weight", scone.maximum_weight )
    grf_threshold = par:create_from_string( "grf_threshold", scone.grf_threshold )
    std_init = par:create_from_string( "std_init", scone.std_init )

    -- define global variables
    cnt = 1                                                                         -- iteration counter
    period = par:create_from_mean_std( "period", period_mean, 0.01, 0.90, 1.30 )    -- period of gait cycle
    -- model:set_custom_value( "period_global", period )                               -- to share between scripts
    phase_right = 0                                                                 -- right phase
    phase_left = 0                                                                  -- left phase
    num_actuators = model:actuator_count()/2                                        -- number of muscles (per side)

    -- define analysis lists
    synergies_list = prefill_matrix( num_actuators, 2 )    -- store synergy signals for all muscles

    -- %%% DEFINE PULSE PARAMETERS %%%
    
    -- list of pulse durations and onsets from aoi_neuromusculoskeletal_2019
    onsets_mean = { 0.00 , 1.59 , 2.44 , 3.69 , 5.36 }
    durations_mean = { 0.75 , 1.10 , 1.20 , 1.07 , 0.94 }
    amplitudes_mean ={ 1.00, 1.00, 1.00, 1.00, 1.00 }

    -- keep a list of pulse durations and onsetss
	onsets = {}
	durations = {}
    amplitudes = {}

    -- define pulse parameters
	for i = 1, num_syn do
		-- create parameters for both slope and offset
		onsets[ i ] = par:create_from_mean_std( "phi" .. i, onsets_mean[ i ], 0.01, 0, 2 * math.pi )
		durations[ i ] = par:create_from_mean_std( "delta" .. i, durations_mean[ i ], 0.01, 0, 2 )
        -- amplitudes[ i ] = par:create_from_mean_std( "lambda" .. i, amplitudes_mean[ i ], 0.01, 0, 2)

        -- onsets[ i ] = onsets_mean[ i ]
        -- durations[ i ] = durations_mean[ i ]
        amplitudes[ i ] = amplitudes_mean[ i ]
	end

    -- %%% DEFINE MUSCLE WEIGHTS %%%
    -- order:   hamstrings_r, bifemsh_r, glut_max_r, iliopsoas_r, rect_fem_r, vasti_r, gastroc_r, soleus_r, tib_ant_r
    --          hamstrings_l, bifemsh_l, glut_max_l, iliopsoas_l, rect_fem_l, vasti_l, gastroc_l, soleus_l, tib_ant_l

    muscle_names = { "glut_max", "soleus", "iliopsoas", "bifemsh", "hamstrings", "gastroc", "tib_ant", "vasti", "rect_fem"}
    -- muscle_init_left = { 0.0653, 0.195, 0.441, 0.124, 0.105, 0.141, 0.285, 0.0113, 0.0157 }
    -- muscle_init_right = { 0.128, 0.182, 0.0546, 0.0898, 0.25, 0.187, 0.0567, 0.287, 0.069 }
    -- muscle_amplitudes_list = { 0.213093, 0.730082, 0.408004, 0.364457, 1.251464, 0.778398, 0.576325, 0.404151, 1.179993}
    muscle_amplitudes_list = {}
    -- muscle_init_left_list = {}
    -- muscle_init_right_list = {}
    for i = 1, num_actuators do
        -- muscle_amplitudes_list[ i ] = par:create_from_mean_std( muscle_names[ i ] .. ".A", 1, 0.01, 0.01, 5)
        -- muscle_init_left_list[ i ] = par:create_from_mean_std( muscle_names[ i ] .. "_l.init", muscle_init_left[ i ], 0.01, 0.01, 1)
        -- muscle_init_right_list[ i ] = par:create_from_mean_std( muscle_names[ i ] .. "_r.init", muscle_init_right[ i ], 0.01, 0.01, 1)
        muscle_amplitudes_list[ i ] = 1
    end

    -- weights = prefill_matrix( num_actuators, num_syn )                       -- create zero matrix

    -- weights[ 1 ][ 1 ] = 0.33    --  gluteus maximus
    -- weights[ 1 ][ 5 ] = 1.17    
    -- weights[ 2 ][ 2 ] = 1.09    -- soleus
    -- weights[ 3 ][ 3 ] = 0.99    -- iliopsoas
    -- weights[ 4 ][ 3 ] = 0.34    -- biceps femoris (short head)
    -- weights[ 4 ][ 5 ] = 0.76    
    -- weights[ 5 ][ 5 ] = 0.14    -- biceps femoris (long head)
    -- weights[ 6 ][ 2 ] = 0.84    -- gastrocnemius
    -- weights[ 6 ][ 3 ] = 0.65
    -- weights[ 7 ][ 1 ] = 0.27    -- tibialis anterior
    -- weights[ 7 ][ 3 ] = 0.97
    -- weights[ 7 ][ 4 ] = 0.15
    -- weights[ 8 ][ 1 ] = 1.02    -- vasti
    -- weights[ 8 ][ 4 ] = 0.23
    -- weights[ 9 ][ 3 ] = 0.02    -- rectus femoris
    -- weights[ 9 ][ 5 ] = 0.29

    -- weights[ 1 ][ 1 ] = par:create_from_mean_std( "GLM1", 0.33, std_init, 0, max_weight )   -- glutues maximus
    -- weights[ 1 ][ 5 ] = par:create_from_mean_std( "GLM5", 1.17, std_init, 0, max_weight )
    -- weights[ 2 ][ 2 ] = par:create_from_mean_std( "SOL2", 1.09, std_init, 0, max_weight )   -- soleus
    -- weights[ 3 ][ 3 ] = par:create_from_mean_std( "ILI3", 0.99, std_init, 0, max_weight )   -- iliopsoas
    -- weights[ 4 ][ 3 ] = par:create_from_mean_std( "BFs3", 0.34, std_init, 0, max_weight )   -- biceps femoris (short head), error need to fix
    -- weights[ 4 ][ 5 ] = par:create_from_mean_std( "BFs5", 0.76, std_init, 0, max_weight )   -- error need to fix
    -- weights[ 5 ][ 5 ] = par:create_from_mean_std( "BFl5", 0.14, std_init, 0, max_weight )   -- biceps femoris (long head)
    -- weights[ 6 ][ 2 ] = par:create_from_mean_std( "GAS2", 0.84, std_init, 0, max_weight )   -- gastrocnemius
    -- weights[ 6 ][ 3 ] = par:create_from_mean_std( "GAS3", 0.65, std_init, 0, max_weight )
    -- weights[ 7 ][ 1 ] = par:create_from_mean_std( "TIB1", 0.27, std_init, 0, max_weight )   -- tibialis anterior
    -- weights[ 7 ][ 3 ] = par:create_from_mean_std( "TIB3", 0.97, std_init, 0, max_weight )
    -- weights[ 7 ][ 4 ] = par:create_from_mean_std( "TIB4", 0.15, std_init, 0, max_weight )
    -- weights[ 8 ][ 1 ] = par:create_from_mean_std( "VAS1", 1.02, std_init, 0, max_weight )   -- vasti
    -- weights[ 8 ][ 4 ] = par:create_from_mean_std( "VAS4", 0.23, std_init, 0, max_weight )
    -- weights[ 9 ][ 3 ] = par:create_from_mean_std( "REF3", 0.02, std_init, 0, max_weight )   -- rectus femoris
    -- weights[ 9 ][ 5 ] = par:create_from_mean_std( "REF5", 0.29, std_init, 0, max_weight )

    weights = initialize_weights( par, num_actuators, num_syn, 0.0, std_init, 0, max_weight, muscle_names )

    act_l, act_r = generate_init_activations()
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------- UPDATE FUNCTION --------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function update( model )
    local t = model:time()

    if( t == 0 ) then 
        excitation_left, excitation_right = act_l, act_r
        -- excitation_left, excitation_right = generate_synergies( t )
    else
        excitation_left, excitation_right = generate_synergies( t )
    end

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
function generate_rectangular_pulses( phase , onsets , durations )
    -- create list to store pulses
    pulses = {}

    -- iterate over all synergies 
    for i = 1, num_syn do
        if phase > onsets[ i ] and phase <= onsets[ i ] + durations[ i ] then
            pulses[ i ] = 1
        else
            pulses[ i ] = 0
        end
    end

    return pulses;
end

function generate_synergies( curr_time )

    -- if( curr_time == 0 ) then
    --     -- initialize muscle activations to value at end of the gait cycle
    --     phase_right = math.fmod( 2 * math.pi * (period - 0.01) / period, 2 * math.pi )
    --     phase_left = math.fmod( phase_right + math.pi, 2 * math.pi )
    -- else 
    --     -- compute phase (assume start w/ left leg heel strike (0 phase))
    --     phase_right = math.fmod( 2 * math.pi * curr_time / period, 2 * math.pi ) -- start deltaT before to make sure activations are initialized well
    --     -- phase_right = math.fmod( 2 * math.pi * (t + period - 0.01) / period, 2 * math.pi ) -- start deltaT before to make sure activations are initialized well
    --     phase_left = math.fmod( phase_right + math.pi, 2 * math.pi )
    -- end

    -- compute phase (assume start w/ left leg heel strike (0 phase))
    phase_right = math.fmod( 2 * math.pi * curr_time / period, 2 * math.pi ) 
    phase_left = math.fmod( phase_right + math.pi, 2 * math.pi )

    -- compute rectangular pulses
    pulses_left = generate_rectangular_pulses( phase_left , onsets , durations )
    pulses_right = generate_rectangular_pulses( phase_right , onsets , durations )

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

    return synergies_left, synergies_right

end

function generate_activations( u_t, a_t )
    tau_act = 0.01
    tau_deact = 0.04
    dt = 0.001

    a_t1 = {}
    for i = 1, num_actuators do 
        if( u_t[ i ] > a_t[ i ] ) then 
            tau = tau_act * ( 0.5 + 1.5 * a_t[ i ] )
        else
            tau = tau_deact / ( 0.5 + 1.5 * a_t[ i ] )
        end

        dadt = ( u_t[ i ] - a_t[ i ] ) / tau  
        a_t1[ i ] = a_t[ i ] + dadt * dt
    end

    return a_t1

end

function generate_init_activations( )

    t_vir = 0
    t_step = 0.001

    act_l, act_r = generate_synergies( 0 )

    while( t_vir < period ) do 
        
        syn_l, syn_r = generate_synergies( t_vir )
        act_l = generate_activations( syn_l, act_l )
        act_r = generate_activations( syn_r, act_r )

        t_vir = t_vir + t_step
    end
    return act_l, act_r
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------ SAVE DATA FUNCTION ------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- function to store data in Scone
function store_data( frame )
    -- store some values for analysis
    frame:set_value( "phase_right", phase_right )
    frame:set_value( "phase_left", phase_left )

    for i = 1,num_syn do
        frame:set_value( "pulse_left" .. i, pulses_left[ i ])
        frame:set_value( "pulse_right" .. i, pulses_right[ i ])
    end

    -- set muscle excitations
    for i = 1, num_actuators do
        frame:set_value( muscle_names[ i ] .. "_l.synergy", synergies_left[ i ] )
        frame:set_value( muscle_names[ i ] .. "_r.synergy", synergies_right[ i ] )
    end
    -- frame:set_value( "synergies", synergies )
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