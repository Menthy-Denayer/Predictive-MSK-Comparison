--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------- INITIALIZATION FUNCTION ----------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function init( model , par )
    grf_threshold = par:create_from_string( "grf_threshold", scone.grf_threshold )
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------- UPDATE FUNCTION --------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

function update( model, time, controller)
    -- retrieve GRF values
    calcn_l = model:find_body( "calcn_l" )
    calcn_r = model:find_body( "calcn_r" )

    grf_left = calcn_l:contact_force(); grf_left_y = grf_left.y 
    grf_right = calcn_r:contact_force(); grf_right_y = grf_right.y 

    stance_left = update_stance( grf_left_y )
    stance_right = update_stance( grf_right_y )

    -- enable reflex controllers based on state
	controller:set_child_enabled( 1, stance_left )
	controller:set_child_enabled( 2, stance_right )
end



function update_stance( grf_y )
    if(grf_y > grf_threshold) then 
        return true;
    else
        return false;
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------ SAVE DATA FUNCTION ------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- function to store data in Scone

function store_data( frame )
    -- store some values for analysis
    frame:set_value( "stance_right", stance_right and 1 or 0)
    frame:set_value( "stance_left", stance_left and 1 or 0 )
end