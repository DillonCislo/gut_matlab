%% Extract the polar Writhe from a series of meshes (PLY files)
% Uses approach taken by Berger & Prior, J. Phys. A, 2006
% Run from meshDir, where msls_output is
%
% Prerequisites
% -------------
% extract_centerline.m
% compute_mesh_surfacearea_volume.m
%
% To run after
% ------------
% extract_crosssections....m
%
% NPMitchell 2019

%% Run from the msls_output directory
clear ;
compute_chirality = false ;
overwrite = false ;
cd /mnt/crunch/48Ygal4UASCAAXmCherry/201902072000_excellent/Time6views_60sec_1.4um_25x_obis1.5_2/data/deconvolved_16bit/msls_output_prnun5_prs1_nu0p00_s0p10_pn2_ps4_l1_l1_20190908


%% First, compile required c code
% mex ./FastMarching_version3b/shortestpath/rk4
close all ;
odir = pwd ;
codepath = '/mnt/data/code/gut_matlab/' ;
if ~exist(codepath, 'dir')
    codepath = [pwd filesep] ;
end
addpath(codepath)
addpath(fullfile(codepath, 'addpath_recurse')) ;
addpath(fullfile(codepath, 'mesh_handling'));
addpath(fullfile(codepath, 'inpolyhedron'));
addpath(fullfile(codepath, 'savgol')) ;
addpath_recurse(fullfile(codepath, 'gptoolbox')) ;
addpath_recurse(fullfile(codepath, 'curve_functions')) ;

% toolbox_path = [codepath 'toolbox_fast_marching/toolbox_fast_marching/'];
% compile_c_files

%% Parameters
res = 1 ;
resolution = 0.2619 ;
buffer = 5 ;
plot_buffer = 30;
ssfactor = 4; 
weight = 0.1;
normal_step = 0.5 ; 
preview = false ;
eps = 0.01 ;
meshorder = 'zyx' ;
exponent = 1;
% figure parameters
xwidth = 16 ; % cm
ywidth = 10 ; % cm

% Find all meshes to consider
meshdir = pwd ;
cd ../
rootdir = pwd ;
cd(meshdir)
% rootpath = '/mnt/crunch/48Ygal4UASCAAXmCherry/201902072000_excellent/' ;
% rootpath = [rootpath 'Time6views_60sec_1.4um_25x_obis1.5_2/data/deconvolved_16bit/'] ;
% if ~exist(rootpath, 'dir')
%     rootpath = '/Users/npmitchell/Dropbox/Soft_Matter/UCSB/gut_morphogenesis/' ;
%     rootpath = [rootpath 'data/48Ygal4UasCAAXmCherry/201902072000_excellent/'] ;
% end
% meshdir = [rootpath 'msls_output_prnun5_prs1_nu0p00_s0p10_pn2_ps4_l1_l1/'];
fns = dir(fullfile(meshdir, 'mesh_apical_stab_0*.ply')) ;
rotname = fullfile(meshdir, 'rotation_APDV') ;
transname = fullfile(meshdir, 'translation_APDV') ;
xyzlimname = fullfile(meshdir, 'xyzlim_APDV') ;
xyzlimname_skel = fullfile(meshdir, 'xyzlim_APDVcenterline') ;

% Name output directory
outdir = [fullfile(fns(1).folder, 'centerline') filesep ];
if ~exist(outdir, 'dir')
    mkdir(outdir) ;
end
% figure 1
choutdir = fullfile(outdir, ['chirality' filesep]);
if ~exist(choutdir, 'dir')
    mkdir(choutdir) ;
end
figoutdir = fullfile(choutdir, ['images' filesep]);
if ~exist(figoutdir, 'dir')
    mkdir(figoutdir) ;
end

fig_smoothoutdir = fullfile(figoutdir, ['smoothed' filesep]);
if ~exist(fig_smoothoutdir, 'dir')
    mkdir(fig_smoothoutdir) ;
end

% Writhe directories 
wroutdir = [outdir 'writhe' filesep];
if ~exist(wroutdir, 'dir')
    mkdir(wroutdir) ;
end
figwrdir = fullfile(wroutdir, ['images' filesep]);
if ~exist(figwrdir, 'dir')
    mkdir(figwrdir) ;
end

ii = 1 ;

%% Load transformations
% Load the rotation matrix
rot = importdata([rotname '.txt']) ;
% Load the translation to put anterior to origin
trans = importdata([transname '.txt']) ;
% Load plotting limits
xyzlim = importdata([xyzlimname '.txt']) ;
% xmin = xyzlim(1) * resolution * ssfactor ;
% ymin = xyzlim(2) * resolution * ssfactor ;
% zmin = xyzlim(3) * resolution * ssfactor ;
% xmax = xyzlim(4) * resolution * ssfactor ;
% ymax = xyzlim(5) * resolution * ssfactor ;
% zmax = xyzlim(6) * resolution * ssfactor ;

%% Get xyzlimits of the centerline
xyzlim_skel = dlmread([xyzlimname_skel '.txt']) ;
xsmin = xyzlim_skel(1) ;
ysmin = xyzlim_skel(2) ;
zsmin = xyzlim_skel(3) ;
xsmax = xyzlim_skel(5) ;
ysmax = xyzlim_skel(6) ;
zsmax = xyzlim_skel(7) ;
smax = xyzlim_skel(8) ;

% Load xyzlim_skel from file
try
    disp(['Attempting to load ' xyzlimname_skel '.txt'])
    tmp = dlmread([xyzlimname_skel '.txt'], ',', 1, 0) ;
    xsmin = tmp(1); xsmax = tmp(5); 
    ysmin = tmp(2); ysmax = tmp(6); 
    zsmin = tmp(3); zsmax = tmp(7); 
    smax = tmp(4) ; rmax = tmp(8) ;
catch
    for ii=1:length(fns)
        %% Name the output centerline
        name_split = strsplit(fns(ii).name, '.ply') ;
        name = name_split{1} ; 
        expstr = ['exp' strrep(num2str(exponent, '%0.1f'), '.', 'p') ] ;
        resstr = ['res' strrep(num2str(res, '%0.1f'), '.', 'p') ] ;
        exten = [ '_' expstr '_' resstr] ;
        skel_rs_outfn = [fullfile(outdir, name) '_centerline_scaled' exten] ;
        skel_outfn = [fullfile(outdir, name) '_centerline' exten ] ;
        polaroutfn = [fullfile(outdir, name) '_polarcoords'] ;
        tmp = strsplit(name, '_') ;
        timestr = tmp{length(tmp)} ;

        % Load centerline 
        try
            disp(['Loading centerline from txt: ', skel_rs_outfn, '.txt'])
            sskelrs = importdata([skel_rs_outfn '.txt']) ;
            ss = sskelrs(:, 1) ;
            ds = diff(ss) ; 
            ds = [ds; ds(length(ds))] ;
            skelrs = sskelrs(:, 2:4) ;
        catch
            disp('Could not find skel: ')
            disp([skel_rs_outfn '.txt'])
            % Save the rotated, translated, scaled curve
            skel = importdata([skel_outfn '.txt']) ;
            skelr = (rot * skel')' + trans ; 

            % get distance increment
            ds = vecnorm(diff(skel), 2, 2) ;
            % get pathlength at each skeleton point
            ss = [0; cumsum(ds)] ;

            % Create rotated and scaled skeleton
            ss_s = ss * resolution * ssfactor ;
            skelr_s = skelr * resolution * ssfactor ;
            disp('Saving rotated & scaled skeleton to txt: ')
            disp([skel_rs_outfn, '.txt'])
            dlmwrite([skel_rs_outfn '.txt'], [ss_s, skelr_s])

            % Recompute ds        
            sskelrs = importdata([skel_rs_outfn '.txt']) ;
            ss = sskelrs(:, 1) ;
            ds = diff(ss) ; 
            ds = [ds; ds(length(ds))] ;
            skelrs = sskelrs(:, 2:4) ;
        end
        xsmin = min(xsmin, min(skelrs(:, 1))) ;
        ysmin = min(ysmin, min(skelrs(:, 2))) ;
        zsmin = min(zsmin, min(skelrs(:, 3))) ;
        xsmax = max(xsmax, max(skelrs(:, 1))) ;
        ysmax = max(ysmax, max(skelrs(:, 2))) ;
        zsmax = max(zsmax, max(skelrs(:, 3))) ;
        smax = max(max(ss), smax) ;

    end
    
    % make header
    fn = [xyzlimname_skel '.txt'] ;
    fid = fopen(fn, 'wt');
    header = 'centerline xyz limits in units of um:' ;
    header = [header '[xmin, xmax; ymin, ymax; zmin, zmax; smax, rmax]' ] ;
    fprintf(fid, header );  
    fclose(fid);
    dlmwrite(fn, [xsmin, xsmax; ysmin, ysmax; zsmin, zsmax; 0, smax])
end
disp('done loading xyzlimits for centerline')
ii = 1;

%% Check if the results have been saved already
wrfn = fullfile(wroutdir, 'writhe_polar.txt') ;
wdfn = fullfile(meshdir, 'writhe_polar_densities.mat') ;
lnfn = fullfile(meshdir, 'lengths_over_time.mat') ;
wre = exist(wrfn, 'file');
wde = exist(wdfn, 'file') ;
lne = exist(lnfn, 'file') ;
saved = wre && wde && lne ;

if saved && ~overwrite
    % Load the results
    wdat = dlmread(wrfn, ',', 1, 0);
    times = wdat(:, 1) ;
    Wrp = wdat(:, 2) ; 
    dwr = wdat(:, 3) ;
    load(wdfn) ;
    load(lnfn) ;
else
    %% Iterate through each mesh
    Wrp = zeros(length(fns), 1) ;
    wrp_densities = cell(length(fns), 1);
    times = zeros(length(fns), 1) ;

    for ii=1:length(fns)
        %% Name the output centerline
        name_split = strsplit(fns(ii).name, '.ply') ;
        name = name_split{1} ; 
        expstr = ['exp' strrep(num2str(exponent, '%0.1f'), '.', 'p') ] ;
        resstr = ['res' strrep(num2str(res, '%0.1f'), '.', 'p') ] ;
        exten = [ '_' expstr '_' resstr] ;
        skel_rs_outfn = [fullfile(outdir, name) '_centerline_scaled' exten] ;
        skel_outfn = [fullfile(outdir, name) '_centerline' exten ] ;
        figsmoutname = [fullfile(fig_smoothoutdir, name) '_centerline_smoothed' exten] ;
        tmp = strsplit(name, '_') ;
        timestr = tmp{length(tmp)} ;
        times(ii) = str2double(timestr) ;

        % Load centerline 
        disp(['Loading centerline from txt: ', skel_rs_outfn, '.txt'])
        sskelrs = importdata([skel_rs_outfn '.txt']) ;
        ss = sskelrs(:, 1) ;
        ds = diff(ss) ; 
        ds = [ds; ds(length(ds))] ;
        skelrs = sskelrs(:, 2:4) ;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Compute writhe of the centerline
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Filter the result
        % Smoothing parameters
        framelen = 17 ;  % must be odd
        polyorder = 2 ;
        [ssx, xp, yp, zp] = smooth_curve_via_fit_3d(ss, skelrs, polyorder, framelen) ;

        %% Check the smoothing
        if preview
            close all
            fig = figure;
            set(gcf, 'Visible', 'Off')
            hold on
            plot3(xskel, yskel, zskel, '-.')
            hold on 
            plot3(scx, scy, scz, 's')
            title('Smoothing')
            % save the figure
            xlim([xsmin xsmax])
            ylim([ysmin ysmax])
            zlim([zsmin zsmax])
            axis equal
            set(gcf, 'PaperUnits', 'centimeters');
            set(gcf, 'PaperPosition', [0 0 xwidth ywidth]);
            saveas(fig, [figsmoutname '.png'])
            if preview
                set(gcf, 'Visible', 'On')
            end

            % Save the difference
            close all
            fig = figure;
            set(fig, 'Visible', 'Off')
            plot(ss, scx - xskel)
            hold on
            plot(ss, scy - yskel)
            plot(ss, scz - zskel)
            title('\Delta = smoothing - original curve')
            ylabel(['\Delta [\mu' 'm]'])
            xlabel(['s [\mu' 'm]'])
            set(fig, 'PaperUnits', 'centimeters');
            set(fig, 'PaperPosition', [0 0 xwidth ywidth]);
            saveas(fig, [figsmoutname '_diff.png'])

            % Save the polynomial fit
            close all
            fig = figure;
            set(fig, 'Visible', 'Off')
            plot3(xskel, yskel, zskel, '-.')
            hold on 
            plot3(xp, yp, zp, 's')
            title('Polynomial fit to the centerline')
            xlabel('x')
            ylabel('y')
            % save the figure
            xlim([xsmin xsmax])
            ylim([ysmin ysmax])
            zlim([zsmin zsmax])
            axis equal
            set(fig, 'PaperUnits', 'centimeters');
            set(fig, 'PaperPosition', [0 0 xwidth ywidth]);
            saveas(fig, [figsmoutname '_fit.png'])
        end

        % %% Get tangent, normal, binormal
        % [tangent, normal, binormal] = frenetSeretFrame(ss, xp, yp, zp) ;
        % 
        % % Now compute how the normal changes along the AP axis    
        % v1 = normal(1:end-1, :) ;
        % v2 = normal(2:end, :) ;
        % dphi = acos(sum(v1 .* v2, 2)) ;
        % signphi = sign(sum(tangent(1:end-1, :) .* cross(v1, v2), 2)) ;
        % dphi = dphi .* signphi ;
        % chirality = dphi ./ dsx(1:end-1)' ;
        % 
        % % Check the angle change along AP axis
        % if preview
        %     close all
        %     fig = figure ;
        %     set(fig, 'Visible', 'Off')
        %     plot(ssx(1:end-1), dphi)
        %     title('$d\phi/ds$', 'Interpreter', 'Latex')
        %     ylabel('$d\phi/ds$', 'Interpreter', 'Latex')
        %     xlabel('$s$ [$\mu$m]', 'Interpreter', 'Latex')
        %     saveas(fig, [figsmoutname '_dphids.png'])
        % end

        %% Compute the writhe
        % Wr = 1/4pi \int \int T(s) xx T(s') \cdot [R(s) - R(s') / |R(s) - R(s')|^3]
        % Here use the polynomial fit to the curve to compute
        % xp, yp, zp
        % first compute vec from each point to every other point
        xyzp = [yp', zp', xp'] ;
        % traditional writhe:
        % wr = zeros(length(ssx), 1) ;
        % for jj=1:length(ssx)
        %     oind = setdiff(1:length(ssx), jj) ;
        %     rmr = xyzp(jj, :) - xyzp(oind, :) ;
        %     rmrmag = vecnorm(rmr')' ;
        %     txt = cross(tangent(jj,:) .* ones(length(oind), 3), tangent(oind, :));
        %     % Take row-wise inner product
        %     integrand = sum(sum(txt .* rmr, 2) ./ (rmrmag.^3 .* ones(size(txt))), 2) ;
        %     % Writhe per unit length is wr
        %     wr(jj) = sum(integrand) ;
        % end
        [wrp, wrp_local, wrp_nl, turns] = polarWrithe(xyzp, ssx(:)) ;
        if length(turns) < 1
            Wrp(ii) = sum(wrp(isfinite(wrp))) ;
            wrp_densities{ii} = wrp ;
        end
        lengths(ii) = max(ss) ;
        if preview
            % Plot the writhe 
            fig = figure('Visible', 'Off');
            plot(ssx, wr)
            xlim([0, smax])
            ylim([-0.05, 0.05])
            title('Writhe density')
            xlabel('pathlength, $s$ [$\mu$m]', 'Interpreter', 'Latex') ;
            ylabel('writhe density, $wr$ [$\mu$m$^{-1}$]', 'Interpreter', 'Latex') ;
            close all
        end
    end

    %% Save Wr(t) and Ch(t)
    % Save the chirality -- todo
    % dlmwrite(fullfile(choutdir, 'chirality.txt'), [times, Chirality]);
    % save(fullfile(meshdir, 'chirality_densities.mat'), 'chirality_densities') ;

    % Save the writhe
    windowSize = 7; 
    b = (1/windowSize)*ones(1,windowSize);
    a = 1;
    Wrsm = smoothdata(Wrp, 'rlowess', 5) ;
    wsmooth = filter(b, a, Wrsm) ;
    dwr = gradient(wsmooth) ;
    write_txt_with_header(wrfn, ...
        [times, Wrp, dwr], 'timestamp, polar Writhe, d(Wr)/dt');
    save(wdfn, 'wrp_densities') ;

    % Save length vs time and dlength 
    % Filter the data for derivative
    windowSize = 7; 
    b = (1/windowSize)*ones(1,windowSize);
    a = 1;
    lsm = smoothdata(lengths, 'rlowess', 5) ;
    lsmooth = filter(b, a, lsm) ;
    dl = gradient(lsmooth) ;
    save(fullfile(meshdir, 'lengths_over_time.mat'), 'lengths', 'dl') ;
end
disp('Done loading/computing chirality/writhe')

%% Save simple figures
% Save chirality as a figure -- todo
% close all
% fig = figure('Visible', 'Off') ;
% plot(times, Chirality) ;
% xlabel('time [min]', 'Interpreter', 'Latex')
% ylabel('Chirality, $\Delta \phi$', 'Interpreter', 'Latex')
% title('Chirality over time', 'Interpreter', 'Latex')
% set(gcf, 'PaperUnits', 'centimeters');
% set(gcf, 'PaperPosition', [0 0 xwidth ywidth]);        
% saveas(fig, fullfile(figoutdir, 'chirality_vs_time.pdf'))
% saveas(fig, fullfile(figoutdir, 'chirality_vs_time.png'))

% Save writhe as a figure
close all
fig = figure('Visible', 'Off') ;
plot(times, mod(Wrp, 1)) ;
xlabel('time [min]', 'Interpreter', 'Latex')
ylabel('Polar Writhe')
title('Polar Writhe over time', 'Interpreter', 'Latex')
set(gcf, 'PaperUnits', 'centimeters');
set(gcf, 'PaperPosition', [0 0 xwidth ywidth]);        
disp(['Saving figure to: ' fullfile(figwrdir, 'writhe_polar_vs_time.pdf')])
saveas(fig, fullfile(figwrdir, 'writhe_polar_vs_time.pdf'))
saveas(fig, fullfile(figwrdir, 'writhe_polar_vs_time.png'))


%% Save writhe as a figure with length, surfarea, volume
% load 'aas', 'vvs', 'dt'
load('surfacearea_volume_stab.mat')
% load the folding times
fold_times = dlmread('fold_times.txt') ;
t0 = fold_times(1) ;
ind = find(times == t0) ;
ylims_derivs = [-0.045, 0.045];
close all
fig = figure('Visible', 'On') ;
s1 = subplot(2, 1, 1) ;
hold on;
yyaxis left
vh = plot(times - t0, vvs / vvs(ind)) ;
ah = plot(times - t0, aas / aas(ind)) ;
lh = plot(times - t0, lengths / lengths(ind)) ;
ylabel('$V$, $A$, $L$', 'Interpreter', 'Latex')
% writhe on right
yyaxis right
wh = plot(times - t0, Wrp ) ;
xlims = get(gca, 'xlim') ; 
ylabel('Writhe, $Wr$', 'Interpreter', 'Latex')
legend({'volume', 'area', 'length'}, ...
    'location', 'northwest', 'AutoUpdate', 'off')
title('Gut dynamics', 'Interpreter', 'Latex')
% Plot folding events
plot(fold_times(2) - t0, Wrp(fold_times(2)-t0+ind), 'ks') ;
plot(fold_times(3) - t0, Wrp(fold_times(3)-t0+ind), 'k^') ;
plot(0, Wrp(ind), 'ko') ;
yyaxis left
plot(fold_times(2) - t0, aas(fold_times(2)-t0+ind)/aas(ind), 'ks') ;
plot(fold_times(3) - t0, aas(fold_times(3)-t0+ind)/aas(ind), 'k^') ;
plot(0, 1, 'ko') ;
plot(fold_times(2) - t0, vvs(fold_times(2)-t0+ind)/vvs(ind), 'ks') ;
plot(fold_times(3) - t0, vvs(fold_times(3)-t0+ind)/vvs(ind), 'k^') ;
plot(0, 1, 'ko') ;
plot(fold_times(2) - t0, lengths(fold_times(2)-t0+ind)/lengths(ind), 'ks') ;
plot(fold_times(3) - t0, lengths(fold_times(3)-t0+ind)/lengths(ind), 'k^') ;
plot(0, 1, 'ko') ;

% Second plot below
s2 = subplot(2, 1, 2) ;
hold on;
% Plot derivatives
di = (windowSize:length(dwr)-windowSize) ;
% vcolor = get(vh, 'color') ;
% acolor = get(ah, 'color') ;
% lcolor = get(lh, 'color') ;
% wcolor = get(wh, 'color') ;
yyaxis left
plot(times(di) - t0, dv(di) / vvs(ind)) ; %, 'Color', vcolor) ;
plot(times(di) - t0, da(di) / aas(ind)) ; %, 'Color', acolor) ;
plot(times(di) - t0, dl(di) / lengths(ind)) ; %, 'Color', lcolor) ;
set(gca, 'ylim', ylims_derivs) ;
ylabel('$\partial_t V / V_0$, $\partial_t A / A_0$, $\partial_t L/ L_0$',...
    'Interpreter', 'Latex')

yyaxis right
plot(times(di) - t0, dwr(di)) ; %, 'Color', wcolor) ;
ylabel('$\partial_t Wr$', 'Interpreter', 'Latex')
set(gca, 'ylim', ylims_derivs) ;

% Set limits
set(s1, 'xlim', xlims)
set(s2, 'xlim', xlims)
xlabel('time [min]', 'Interpreter', 'Latex')
set(gcf, 'PaperUnits', 'centimeters');
set(gcf, 'PaperPosition', [0 0 xwidth 2*ywidth]);        
saveas(fig, fullfile(meshdir, 'writhe_dynamics.pdf'))
saveas(fig, fullfile(meshdir, 'writhe_dynamics.png'))

%% Do it again in stages --> the last build isn't finished right now
% load 'aas', 'vvs', 'dt'
load('surfacearea_volume_stab.mat')
% load the folding times
fold_times = dlmread('fold_times.txt') ;
t0 = fold_times(1) ;
ind = find(times == t0) ;
okinds = 1:148 ;
addpath('/mnt/data/code/gut_matlab/plotting')
[colors, colornames] = define_colors ;
color1 = colors(1, :) ;
color2 = colors(2, :) ;
color3 = colors(3, :) ;
for ii = 1:5
    disp(['ii = ' num2str(ii)])
    close all
    fig = figure('units', 'centimeters', ...
            'outerposition', [0 0 30 30], 'Visible', 'Off') ;
    axis square
    pbaspect([1.5 1 1])
    yyaxis left
    
    % fill in boxes
    if ii == 5
        % To make fills, get xlimits from a handle that we clear
        vh = plot(times(okinds) - t0, vvs(okinds) / vvs(ind)) ;
        xlims = xlim ;
        cla

        % Get the limits to shade in the background
        ymax = 3.2 ;
        twrithe = 40 ;
        tend = 70 ;
        xx1 = [xlims(1) 0, 0, xlims(1)] ;
        xx2 = [0, twrithe, twrithe, 0] ;
        xx3 = [twrithe, tend, tend, twrithe] ;
        yfill = [0, ymax, 0, ymax ] ;
        hf1 = fill(xx1, yfill, color1, 'facealpha', 0.5);
        hold on;
        hf2 = fill(xx2, yfill, color2, 'facealpha', 0.5);
        hf3 = fill(xx3, yfill, color3, 'facealpha', 0.5);
    end
    
    vh = plot(times(okinds) - t0, vvs(okinds) / vvs(ind)) ;
    ylabel('$V$', 'Interpreter', 'Latex')
    hold on ;
    if ii > 1
        ah = plot(times(okinds) - t0, aas(okinds) / aas(ind)) ;
        ylabel('$V$, $A$', 'Interpreter', 'Latex')
    end
    if ii > 2
        lh = plot(times(okinds) - t0, lengths(okinds) / lengths(ind)) ;
        ylabel('$V$, $A$, $L$', 'Interpreter', 'Latex')
    end
    
    if ii == 1
        % writhe on right
        h2 = plot([1], [1])
        h3 = plot([1], [1])
        legend({'volume', ' ', ' '}, ...
            'location', 'northwest', 'AutoUpdate', 'off')
    elseif ii == 2
        h3 = plot([1], [1])
        legend({'volume', 'area', ''}, ...
            'location', 'northwest', 'AutoUpdate', 'off')
    elseif ii == 3
        legend({'volume', 'area', 'length'}, ...
            'location', 'northwest', 'AutoUpdate', 'off')
    elseif ii > 3
        % writhe on right
        yyaxis right
        wh = plot(times(okinds) - t0, Wrp(okinds) ) ;
        xlims = get(gca, 'xlim') ;
        ylabel('Writhe, $Wr$', 'Interpreter', 'Latex')
        legend({'volume', 'area', 'length'}, ...
            'location', 'northwest', 'AutoUpdate', 'off')
    end
    % title('Gut dynamics', 'Interpreter', 'Latex')
    % Plot folding events
    if ii > 3
        plot(fold_times(2) - t0, Wrp(fold_times(2)-t0+ind), 'ks') ;
        plot(fold_times(3) - t0, Wrp(fold_times(3)-t0+ind), 'k^') ;
        plot(0, Wrp(ind), 'ko') ;
    end
    
    yyaxis left
    plot(fold_times(2) - t0, vvs(fold_times(2)-t0+ind)/vvs(ind), 'ks') ;
    plot(fold_times(3) - t0, vvs(fold_times(3)-t0+ind)/vvs(ind), 'k^') ;
    plot(0, 1, 'ko') ;
    if ii > 1
        plot(fold_times(2) - t0, aas(fold_times(2)-t0+ind)/aas(ind), 'ks') ;
        plot(fold_times(3) - t0, aas(fold_times(3)-t0+ind)/aas(ind), 'k^') ;
        plot(0, 1, 'ko') ;
    end
    if ii > 2
        plot(fold_times(2) - t0, lengths(fold_times(2)-t0+ind)/lengths(ind), 'ks') ;
        plot(fold_times(3) - t0, lengths(fold_times(3)-t0+ind)/lengths(ind), 'k^') ;
        plot(0, 1, 'ko') ;
    end
    
    if ii < 4
        yyaxis right
        yticks([])
    end
    
    yyaxis left
    ylimits = ylim ;
    if ii < 3
        ymax = 1.8 ;
    else
        ymax = 3.2 ;
    end
    if ylimits(2) < ymax
        ylimits(2) = ymax ;
    end
    ylim([0 ylimits(2)])
    
    % Set limits
    xlabel('time [min]', 'Interpreter', 'Latex')
    set(gcf, 'PaperUnits', 'centimeters');
    set(gcf, 'PaperPosition', [0 0 xwidth 2*ywidth]);    
    fn = fullfile(meshdir, ['writhe_dynamics_build' num2str(ii) '.png']) ;
    disp(['Saving figure ' fn])
    saveas(fig, fn)
end
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% similar figure  but one panel for everything %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all
fig = figure('Visible', 'Off') ;
hold on;
vh = plot(times - t0, vvs / vvs(ind)) ;
ah = plot(times - t0, aas / aas(ind)) ;
lh = plot(times - t0, lengths / lengths(ind)) ;
wh = plot(times - t0, Wrp ) ;
vcolor = get(vh, 'color') ;
acolor = get(ah, 'color') ;
xlims = get(gca, 'xlim') ; 
ylims = get(gca, 'ylim') ; 
plot(times - t0, dv / vvs(ind) * 100, '--', 'Color', vcolor) ;
plot(times - t0, da / aas(ind) * 100, '--', 'Color', acolor) ;
plot(t0, Wrp(t0), 'k.') ;
plot(fold_times(2) - t0, Wrp(fold_times(2) - t0), 'ko') ;
plot(fold_times(3) - t0, Wrp(fold_times(3) - t0), 'ks') ;
set(gca, 'xlim', xlims)
set(gca, 'ylim', ylims)
xlabel('time [min]', 'Interpreter', 'Latex')
ylabel('Volume, Area, Length, \& Writhe', 'Interpreter', 'Latex')
title('Gut dynamics', 'Interpreter', 'Latex')
legend({'volume', 'area', 'length'}, 'location', 'northwest')
set(gcf, 'PaperUnits', 'centimeters');
set(gcf, 'PaperPosition', [0 0 xwidth ywidth]);        
saveas(fig, fullfile(meshdir, 'writhe_dynamics2.pdf'))
saveas(fig, fullfile(meshdir, 'writhe_dynamics2.png'))

%% Save figures of writhe density
fig = figure('Visible', 'Off') ;
for ii=1:length(wrp_densities)
    timestr = sprintf('%06d', times(ii));
    scatter3(xp, yp, zp, 10, wr)
    xlim([xsmin, xsmax])
    xlim([ysmin, ysmax])
    xlim([zsmin, zsmax])
    title('Writhe density')
    xlabel('x [\mum]') ;
    ylabel('y [\mum]') ;
    zlabel('z [\mum]') ;
    set(gcf, 'PaperUnits', 'centimeters');
    set(gcf, 'PaperPosition', [0 0 xwidth ywidth]);        
    saveas(fig, fullfile(figwrdir, ['writhe_densities_' timestr '.png']))
end


disp('done')
