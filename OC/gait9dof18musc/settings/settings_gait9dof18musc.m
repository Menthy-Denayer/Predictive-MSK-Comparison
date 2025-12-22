% --------------------------------------------------------------------------
% Settings for gait9dof18musc with SmoothSphereHalfSpaceForce contact
% forces.
% Original author: Menthy Denayer
% Original date: 12/03/2025
% --------------------------------------------------------------------------

S.subject.name = 'gait9dof18musc';

% This model has no arms
S.subject.base_joints_arms = []; 

% Achilles tendon stiffness
S.subject.tendon_stiff_scale = {{'soleus','gastroc'},0.5};

% remove damping coefficient for joints
S.subject.damping_coefficient_all_dofs = 0;

% change bounds outside of default range 
% S.bounds.Qs = {{'knee_angle_r','knee_angle_l'},-120,10,{'hip_flexion_r','hip_flexion_l'},[],120};