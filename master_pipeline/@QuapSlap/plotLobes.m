function plotLobes(QS, options)
%PLOTLOBES(QS, options)
%   plot the lobe dynamics
%
% Parameters
% ----------
% QS : QuapSlap class instance
%   The current QuapSlap object whose lobes to plot
% options : struct with fields
%   overwrite : bool
%   
% Returns
% -------
% <none>
%
% NPMitchell 2020

%% Unpack 
foldfn = QS.fileName.fold ;
lobeDir = QS.dir.lobe ;
timePoints = QS.xp.fileMeta.timePoints ;

%% Unpack options
if isfield(options, 'overwrite')
    overwrite = options.overwrite ;
else
    overwrite = true ;
end

%% Now plot the lobe dynamics
dvexten = sprintf('_nU%04d_nV%04d', QS.nU, QS.nV) ;
lobedyn_figfn = fullfile(lobeDir, ['lobe_dynamics' dvexten '.png']) ;
fig1exist = exist(lobedyn_figfn, 'file') ;
% scaled version of same plot
lobedyn_figfn_scaled = fullfile(lobeDir, ['lobe_dynamics' dvexten '_scaled.png']) ;
fig2exist = exist(lobedyn_figfn_scaled, 'file') ;
if ~fig1exist || ~fig2exist || overwrite
    % load it
    disp('Loading lobe dynamics from disk')
    load(QS.fileName.lobeDynamics, ...
        'length_lobes', 'area_lobes', 'volume_lobes')
    t0 = QS.t0set() ;
    load(QS.fileName.fold, 'fold_onset')
    colors = QS.plotting.colors ;
    
    % Plot it
    disp('Plotting lobe dynamics...')
    aux_plot_lobe_dynamics(length_lobes, area_lobes, volume_lobes, ...
            timePoints, fold_onset, colors, lobedyn_figfn, ...
            lobedyn_figfn_scaled, t0)
else
    disp('Skipping lobe dynamics plot since it exists...')
end
