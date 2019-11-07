function [wr, wr_local, wr_nonlocal, turns, segs, segpairs] = polarWrithe(xyz, ss)
%POLARWRITHE Compute the polar writhe, its local and nonlocal components
%   Compute as defined by "The writhe of open and closed curves, by 
%   Mitchell A Berger and Chris Prior, 2006.
%
% Parameters
% ----------
% ss : optional, pathlength parameterization
% xyz :
%
% Returns
% -------
% wr : 
% wr_local :
% wr_global :
% turns : list of ints
%   indices of curve where ds/dz changes sign
% segs : cell array of lists of ints
%   the segment indices
%
% Example Usage
% -------------
% t = 0:0.01:1 ;
% xx = sin(2*pi*t) ;
% yy = cos(2*pi*t) ;
% zz = 2 * pi * (t - 0.5) ;
% xx = [xx xx(1:end) ];
% yy = [yy fliplr(yy(1:end)) ];
% zz = [zz fliplr(zz(1:end)) ];
% xyz = [xx ; yy; zz]';
% [wr, wr_local, wr_nonlocal] = polarWrithe(xyz) ;
% 
% NPMitchell 2019

if length(ss) < 1
    % get distance increment
    ds = vecnorm(diff(xyz), 2, 2) ;
    % get pathlength at each skeleton point
    ss = [0; cumsum(ds)] ;
end

% Divide the curve into segments
dz = gradient(xyz(:, 3)) ;
ds = gradient(ss) ;
dzds = dz ./ ds ;
% where does this change sign?
sgnz = sign(dzds) ;
% Handle the case where there is a stagnation point, ex sgnz=[..1, 0, -1..]
% by setting all negative signs to zero, so that now sgnz=[..1, 0, 0...]
sgnz(sgnz < 0) = 0 ;
turns = find(abs(diff(sgnz)) > 0) + 1;

if isempty(turns)
    disp('One single segment detected')
    % Compute the local writhe for each segment
    wr_local = local_writhe(ss, xyz) ;
    wr_nonlocal = [] ;
    segs{1} = 1:size(xyz, 1) ;
else
    disp([ num2str(length(turns) + 1) ' segments detected'])
    % Compute the local writhe for each segment
    wr_local = local_writhe(ss, xyz) ;
    segs = cell(length(turns) + 1, 1) ;
    wr_nonlocal = [] ;
    segpairs = {} ;
    % Compute the nonlocal contribution of the polar writhe 
    % add contribution from zmin to zmax
    
    % Segments are defined 1:turns(1)-1, turns(1):turns(2)-1, etc
    % Compute sigmas, which tell which direction curve is trending
    sigma = zeros(length(turns) + 1, 1) ;
    for ii = 1:length(turns)+1
        if ii == 1
            segii = 1:turns(ii) - 1 ;
        elseif ii < length(turns) + 1
            segii = turns(ii - 1):turns(ii) - 1 ;
        else
            segii = turns(ii - 1):size(xyz, 1) ;
        end
        [~, minID] = min(xyz(segii, 3)) ;
        [~, maxID] = max(xyz(segii, 3)) ;
        sigma(ii) = (minID < maxID) * 2 - 1 ;
        segs{ii} = segii ;
    end
    
    % Now compute the twisting rate of the vector joining each segment to
    % every other
    for ii = 1:length(turns) + 1
        disp(['considering segment ' num2str(ii)])
        
        % obtain segment indices of ii 
        segii = segs{ii} ;        
        [zmini, minIDi] = min(xyz(segii, 3)) ;
        [zmaxi, maxIDi] = max(xyz(segii, 3)) ;
        for jj = 1:length(turns) + 1
            disp(['comparing segment ' num2str(ii) ' to segment ' num2str(jj)])
            % skip self-energy terms
            if ii ~= jj
                % obtain segment indices of jj
                segjj = segs{jj} ;
                
                % find the z range over which to interpolate
                [zminj, minIDj] = min(xyz(segjj, 3)) ;
                [zmaxj, maxIDj] = max(xyz(segjj, 3)) ;

                % Only consider this pair if there is overlap between the
                % segments, which means one enpt is in range of the other
                % segment.
                imin_jrange = zmini >= zminj && zmini <= zmaxj ;
                imax_jrange = zmaxi >= zminj && zmaxi <= zmaxj ;
                jmin_irange = zminj >= zmini && zminj <= zmaxi ;
                jmax_irange = zmaxj >= zmini && zmaxj <= zmaxi ;
                overlap = imin_jrange || imax_jrange || jmin_irange || jmax_irange ;
                
                if overlap
                    zmin = max(zmini, zminj) ;
                    zmax = min(zmaxi, zmaxj) ;

                    % draw rvec pointing from ii to jj curve along (zmin, zmax)
                    % Interpolate segment i
                    dzz = (zmax - zmin) / 100 ;
                    tt = zmin:dzz:zmax ;
                    segi_x = interp1(xyz(segii, 3), xyz(segii, 1), tt)';
                    segi_y = interp1(xyz(segii, 3), xyz(segii, 2), tt)';

                    % Interpolate segment j
                    segj_x = interp1(xyz(segjj, 3), xyz(segjj, 1), tt)';
                    segj_y = interp1(xyz(segjj, 3), xyz(segjj, 2), tt)';

                    % Compute the twisting of i around j
                    rij = [segj_x - segi_x, segj_y - segi_y, zeros(size(segj_x))] ;
                    rijprime = [gradient(rij(:, 1), dzz), gradient(rij(:, 2), dzz), gradient(rij(:, 3), dzz)] ;
                    numprod = cross(rij, rijprime)  ;
                    dTheta_dz = numprod(:, 3) ./ vecnorm(rij, 2, 2).^2;

                    contrib = sigma(ii) * sigma(jj) * nansum(dTheta_dz .* dzz) ;
                    wr_nonlocal = [wr_nonlocal, contrib] ;
                    segpairs{end + 1} = [ii, jj] ;
                else
                    disp(['no overlap between ' num2str(ii) ' and ' num2str(jj)])
                end
            end
        end 
    end
    for ii = 1:length(wr_nonlocal)
        % normalize the nonlocal contribs by 2pi
        wr_nonlocal(ii) = wr_nonlocal(ii) / (2 * pi) ;
    end
end

disp('wr_nonlocal = ')
disp(wr_nonlocal)
wr = nansum(wr_local) + nansum(wr_nonlocal) ;

end

