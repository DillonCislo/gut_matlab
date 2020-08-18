function measurePathlineMetricKinematics(QS, options)
% measurePathlineMetricKinematics(QS, options)
%   Query the metric Kinematics along lagrangian pathlines.
%   Plot results as kymographs and correlation plots.
%   Out-of-plane motion is v_n * 2H, where v_n is normal velocity and H is
%   mean curvature.
%   In-plane motion considered here is div(v_t) where v_t is tangential
%   velocity on the curved surface.
%   The difference div(v_t) - vn*2H = Tr[g^{-1} dot{g}], which is a measure
%   of isotropic metric change over time (dot is the partial derivative wrt
%   time). 
% 
% Parameters
% ----------
% QS : QuapSlap class instance
% options : struct with fields
%   plot_kymographs : bool
%   plot_kymographs_cumsum : bool
%   plot_correlations : bool
%   plot_gdot_correlations : bool
%   plot_gdot_decomp : bool
% 
% NPMitchell 2020

%% Default options 
overwrite = false ;
plot_kymographs = true ;
plot_kymographs_cumsum = true ;
plot_correlations = true ;
plot_gdot_correlations = false ;
plot_gdot_decomp = true ;

%% Parameter options
lambda_mesh = 0.002 ;
lambda = 0.01 ; 
lambda_err = 0.01 ;
climit = 0.2 ;
climit_err = 0.2 ;
climit_veln = climit * 10 ;
climit_H = climit * 2 ;
% Sampling resolution: whether to use a double-density mesh
samplingResolution = '1x'; 
averagingStyle = "Lagrangian" ;

%% Unpack options & assign defaults
if nargin < 2
    options = struct() ;
end
if isfield(options, 'overwrite')
    overwrite = options.overwrite ;
end
%% parameter options
if isfield(options, 'lambda')
    lambda = options.lambda ;
end
if isfield(options, 'lambda_err')
    lambda_err = options.lambda_err ;
end
if isfield(options, 'lambda_mesh')
    lambda_mesh = options.lambda_mesh ;
else
    % default lambda_mesh is equal to lambda 
    lambda_mesh = lambda ;
end
if isfield(options, 'climit')
    climit = options.climit ;
end
if isfield(options, 'climit_err')
    climit_err = options.climit_err ;
end
if isfield(options, 'climit_veln')
    climit_veln = options.climit_veln ;
end
if isfield(options, 'climit_H')
    climit_H = options.climit_H ;
end
if isfield(options, 'samplingResolution')
    samplingResolution = options.samplingResolution ;
end
if isfield(options, 'averagingStyle')
    averagingStyle = options.averagingStyle ;
end

%% Operational options
if isfield(options, 'plot_kymographs')
    plot_kymographs = options.plot_kymographs ;
end
if isfield(options, 'plot_kymographs_cumsum')
    plot_kymographs_cumsum = options.plot_kymographs_cumsum ;
end
if isfield(options, 'plot_correlations')
    plot_correlations = options.plot_correlations ;
end
if isfield(options, 'plot_gdot_correlations')
    plot_gdot_correlations = options.plot_gdot_correlations ;
end
if isfield(options, 'plot_gdot_decomp')
    plot_gdot_decomp = options.plot_gdot_decomp ;
end

%% Determine sampling Resolution from input -- either nUxnV or (2*nU-1)x(2*nV-1)
if strcmp(samplingResolution, '1x') || strcmp(samplingResolution, 'single')
    doubleResolution = false ;
    sresStr = '' ;
elseif strcmp(samplingResolution, '2x') || strcmp(samplingResolution, 'double')
    doubleResolution = true ;
    sresStr = 'doubleRes_' ;
else 
    error("Could not parse samplingResolution: set to '1x' or '2x'")
end

%% Unpack QS
QS.getXYZLims ;
xyzlim = QS.plotting.xyzlim_um ;
buff = 10 ;
xyzlim = xyzlim + buff * [-1, 1; -1, 1; -1, 1] ;
if strcmp(averagingStyle, 'Lagrangian')
    mKDir = fullfile(QS.dir.metricKinematics, ...
        strrep(sprintf([sresStr 'lambda%0.3f_lerr%0.3f_lmesh%0.3f'], ...
        lambda, lambda_err, lambda_mesh), '.', 'p'));
else
    mKDir = fullfile(QS.dir.metricKinematicsSimple, ...
        strrep(sprintf([sresStr 'lambda%0.3f_lerr%0.3f_lmesh%0.3f'], ...
        lambda, lambda_err, lambda_mesh), '.', 'p'));
end
folds = load(QS.fileName.fold) ;
fons = folds.fold_onset - QS.xp.fileMeta.timePoints(1) ;

%% Colormap
bwr256 = bluewhitered(256) ;

%% Load time offset for first fold, t0
QS.t0set() ;
tfold = QS.t0 ;

%% load from QS
if doubleResolution
    nU = QS.nU * 2 - 1 ;
    nV = QS.nV * 2 - 1 ;
else
    nU = QS.nU ;
    nV = QS.nV ;    
end

% We relate the normal velocities to the divergence / 2 * H.
tps = QS.xp.fileMeta.timePoints(1:end-1) - tfold;

%% Build timepoint list so that we first do every 10, then fill in details
lastIdx = length(QS.xp.fileMeta.timePoints) - 1 ;
coarseIdx = 1:10:lastIdx ;
fineIdx = setdiff(1:lastIdx, coarseIdx) ;
allIdx = [80, coarseIdx, fineIdx ] ;
tp2do = QS.xp.fileMeta.timePoints(allIdx) ;

% Unit definitions for axis labels
unitstr = [ '[1/' QS.timeUnits ']' ];
Hunitstr = [ '[1/' QS.spaceUnits ']' ];
vunitstr = [ '[' QS.spaceUnits '/' QS.timeUnits ']' ];

% DONE WITH PREPARATIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Load pathlines to build Kymographs along pathlines
t0 = QS.t0set() ;
QS.loadPullbackPathlines(t0, 'vertexPathlines')
vP = QS.pathlines.vertices ;

% Output directory is inside metricKinematics dir
mKPDir = fullfile(mKDir, sprintf('pathline_%04dt0', t0)) ;
outdir = fullfile(mKPDir, 'measurements') ;
if ~exist(outdir, 'dir')
    mkdir(outdir)
end
% Data for kinematics on meshes (defined on vertices)
mdatdir = fullfile(mKDir, 'measurements') ;

% Load Lx, Ly by loadingPIV
QS.loadPIV()

% Discern if piv measurements are done on a double covering or the meshes
if strcmp(QS.piv.imCoords(end), 'e')
    doubleCovered = true ;
end

% Compute or load all timepoints
for tp = tp2do
    close all
    disp(['t = ' num2str(tp)])
    tidx = QS.xp.tIdx(tp) ;
    QS.setTime(tp) ;
    
    % Check for timepoint measurement on disk
    Hfn = fullfile(outdir, sprintf('HH_series_%06d.mat', tp))   ;
    efn = fullfile(outdir, sprintf('gdot_series_%06d.mat', tp)) ;
    dfn = fullfile(outdir, sprintf('divv_series_%06d.mat', tp)) ;
    nfn = fullfile(outdir, sprintf('veln_series_%06d.mat', tp)) ;
    H2vnfn = fullfile(outdir, sprintf('H2vn_series_%06d.mat', tp)) ;
    files_missing = ~exist(Hfn, 'file') || ~exist(efn, 'file') || ...
         ~exist(dfn, 'file') || ~exist(nfn, 'file') || ...
          ~exist(H2vnfn, 'file') ;
    
    if overwrite || files_missing
        % Load timeseries measurements defined on mesh vertices
        HfnMesh = fullfile(mdatdir, sprintf('HH_series_%06d.mat', tp))   ;
        efnMesh = fullfile(mdatdir, sprintf('gdot_series_%06d.mat', tp)) ;
        dfnMesh = fullfile(mdatdir, sprintf('divv_series_%06d.mat', tp)) ;
        nfnMesh = fullfile(mdatdir, sprintf('veln_series_%06d.mat', tp)) ;
        H2vnfnMesh = fullfile(mdatdir, sprintf('H2vn_series_%06d.mat', tp)) ;

        try
            load(HfnMesh, 'HH')
            load(efnMesh, 'gdot')
            load(dfnMesh, 'divv')
            load(nfnMesh, 'veln') 
            load(H2vnfnMesh, 'H2vn') 
        catch
            msg = 'Run QS.measureMetricKinematics() ' ;
            msg = [msg 'with lambdas=(mesh,lambda,err)=('] ;
            msg = [msg num2str(lambda_mesh) ','] ;
            msg = [msg num2str(lambda) ','] ;
            msg = [msg num2str(lambda_err) ')'] ;
            msg = [msg ' before running ', ...
                    'QS.measurePathlineMetricKinematics()'] ;
            error(msg)
        end
        % Interpolate from vertices onto pathlines
        xx = vP.vX(tidx, :, :) ;
        yy = vP.vY(tidx, :, :) ;
        XY = [xx(:), yy(:)] ;
        Lx = vP.Lx(tidx) ;
        Ly = vP.Ly(tidx) ;
        options.Lx = Lx ;
        options.Ly = Ly ;
        XY = QS.doubleToSingleCover(XY, Ly) ;
        HH = QS.interpolateOntoPullbackXY(XY, HH, options) ;
        gdot = QS.interpolateOntoPullbackXY(XY, gdot, options) ;
        divv = QS.interpolateOntoPullbackXY(XY, divv, options) ;
        veln = QS.interpolateOntoPullbackXY(XY, veln, options) ;
        H2vn = QS.interpolateOntoPullbackXY(XY, H2vn, options) ;
                
        % OPTION 1: simply reshape, tracing each XY dot to its t0
        % grid coordinate
        HH = reshape(HH, [nU, nV]) ;
        gdot = reshape(gdot, [nU, nV]) ;
        divv = reshape(divv, [nU, nV]) ;
        veln = reshape(veln, [nU, nV]) ;
        H2vn = reshape(H2vn, [nU, nV]) ;
        
        %% OPTION 2: the following regrids onto original XY coordinates,
        % rendering the process of following pathlines moot. 
        % Average into AP bins and take mean along 1/4 DV hoop arcs
        % if doubleCovered
        %     vminmax = [0.25 * Ly, 0.75 * Ly] ;
        % else
        %     vminmax = [1, Ly] ;
        % end
        %
        % Note the transposition: to plot as APDV, imshow(m')
        % HH = binData2dGrid([XY, HH], [1,Lx], vminmax, nU, nV) ;
        % gdot = binData2dGrid([XY, gdot], [1,Lx], vminmax, nU, nV) ;
        % divv = binData2dGrid([XY, divv], [1,Lx], vminmax, nU, nV) ;
        % veln = binData2dGrid([XY, veln], [1,Lx], vminmax, nU, nV) ;
        % H2vn = binData2dGrid([XY, H2vn], [1,Lx], vminmax, nU, nV) ;
           
        % Average along DV -- do not ignore last row at nV since not quite
        % redundant in this version of the algorithm
        HH_ap = nanmean(HH, 2) ;
        gdot_ap = nanmean(gdot, 2) ;
        divv_ap = nanmean(divv, 2) ;
        veln_ap = nanmean(veln, 2) ;
        H2vn_ap = nanmean(H2vn, 2) ;
        
        % quarter bounds
        q0 = round(nV * 0.125) ;
        q1 = round(nV * 0.375) ;
        q2 = round(nV * 0.625) ;
        q3 = round(nV * 0.875) ;
        left = q0:q1 ;
        ventral = q1:q2 ;
        right = q2:q3 ;
        dorsal = [q3:nV, 1:q1] ;
        
        % left quarter
        HH_l = nanmean(HH(:, left), 2) ;
        gdot_l = nanmean(gdot(:, left), 2) ;
        divv_l = nanmean(divv(:, left), 2) ;
        veln_l = nanmean(veln(:, left), 2) ;
        H2vn_l = nanmean(H2vn(:, left), 2) ;
        
        % right quarter
        HH_r = nanmean(HH(:, right), 2) ;
        gdot_r = nanmean(gdot(:, right), 2) ;
        divv_r = nanmean(divv(:, right), 2) ;
        veln_r = nanmean(veln(:, right), 2) ;
        H2vn_r = nanmean(H2vn(:, right), 2) ;
        
        % dorsal quarter
        HH_d = nanmean(HH(:, dorsal), 2) ;
        gdot_d = nanmean(gdot(:, dorsal), 2) ;
        divv_d = nanmean(divv(:, dorsal), 2) ;
        veln_d = nanmean(veln(:, dorsal), 2) ;
        H2vn_d = nanmean(H2vn(:, dorsal), 2) ;
        
        % ventral quarter
        HH_v = nanmean(HH(:, ventral), 2) ;
        gdot_v = nanmean(gdot(:, ventral), 2) ;
        divv_v = nanmean(divv(:, ventral), 2) ;
        veln_v = nanmean(veln(:, ventral), 2) ;
        H2vn_v = nanmean(H2vn(:, ventral), 2) ;
        
        % Save results
        save(Hfn, 'HH', 'HH_ap', 'HH_l', 'HH_r', 'HH_d', 'HH_v')
        save(efn, 'gdot', 'gdot_ap', 'gdot_l', 'gdot_r', 'gdot_d', 'gdot_v')
        save(dfn, 'divv', 'divv_ap', 'divv_l', 'divv_r', 'divv_d', 'divv_v')
        save(nfn, 'veln', 'veln_ap', 'veln_l', 'veln_r', 'veln_d', 'veln_v') 
        save(H2vnfn, 'H2vn', 'H2vn_ap', 'H2vn_l', 'H2vn_r', 'H2vn_d', 'H2vn_v')
    end
end
disp('done with measuring pathline metric kinematics')

% Query each pathline position in relevant mesh and interpolate divv