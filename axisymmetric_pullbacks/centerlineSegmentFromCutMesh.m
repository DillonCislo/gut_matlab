function [cseg, acID, pcID, bdLeft, bdRight] = centerlineSegmentFromCutMesh(cline, TF, TV2D, TV3D, eps)
%CENTERLINESEGMENTFROMCUTMESH Calculate abbreviated centerline from cutMesh boundaries
%   Find the start and endpoints of a centerline closest to the 3D
%   positions of the boundaries corresponding to u=0 and u=1 of the 2D
%   mesh pullback representation.
% 
% Parameters
% ----------
% curv : M x D float array
%   The curve to resample such that each segment is equal Euclidean
%   length
% N : int
%   the number of points desired in the sampling
% closed : bool
%   whether the curve is closed (final point == starting point)
% 
% Returns
% -------
% curvout : N x D float array
%   the resampled curve with equally spaced segment sampling
%
% NPMitchell 2019

if nargin < 5
    eps = 1e-12;
end

meshTri = triangulation( TF, TV2D );
% The vertex IDs of vertices on the mesh boundary
bdyIDx = meshTri.freeBoundary;
% Consider all points on the left free boundary between y=(0, 1)
bdLeft = bdyIDx(TV2D(bdyIDx(:, 1), 1) < eps, 1) ;
bdLeft = bdLeft(TV2D(bdLeft, 2) < 1+eps & TV2D(bdLeft, 2) > -eps) ;
% Find matching endpoint on the right
rightmost = max(TV2D(:, 1));
bdRight = bdyIDx(TV2D(bdyIDx(:, 1), 1) > rightmost - eps) ;

% Find segment of centerline to use
% grab "front"/"start" of centerline nearest to bdLeft
% distance from each point in bdLeft to this point in cntrline
Adist = zeros(length(cline), 1) ;
for kk = 1:length(cline)
    Adist(kk) = mean(vecnorm(TV3D(bdLeft, :) - cline(kk, :), 2, 2)) ;
end
[~, acID] = min(Adist) ; 

% grab "back"/"end" of centerline nearest to bdRight
Pdist = zeros(length(cline), 1) ;
for kk = 1:length(cline)
    Pdist(kk) = mean(vecnorm(TV3D(bdRight, :) - cline(kk, :), 2, 2)) ;
end
[~, pcID] = min(Pdist) ;
cseg = cline(acID:pcID, :) ;

% Check it -- Visualizing 
% if preview
%     close all
%     fig = figure('visible', 'off') ;
%     plot(ss, Adist)
%     hold on
%     plot(ss, Pdist)
%     xlabel('pathlength of centerline')
%     ylabel('mean distance from anterior or posterior cuts')
%     title('Extracting relevant portion of centerline for twist')
%     legend({'anterior', 'posterior'}, 'location', 'best')
%     xlim([0 smax])
%     waitfor(fig)
%     close all
% end


return

