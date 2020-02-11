function aux_generate_orbifold(cutMesh, a, IV, imfn, Options)
%AUX_GENERATE_ORBIFOLD(cutMesh, a, IV, imfn)
%
% Parameters
% ----------
% cutMesh : struct
%   mesh with fields f (faces), u (2d vertices), and v (3d vertices)
% a : float
%   aspect ratio of width/height of image pullback
% IV : 
%   3d intensity data
% imfn : str
%   path to filename for saving pullback
% Options:  struct
%   Structure containing the standard options for a
%   textured surface patch, such as EdgeColor, EdgeAlpha,
%   etc.  See MATLAB documentation for more information.
%   Additional options as fields are
%       - Options.imSize:       The size of the output image
%       - Options.baseSize:     The side length in pixels of the smallest
%                               side of the output image when using the
%                               tight mesh bounding box
%       - Options.xLim:         The x-bounds of the output image
%       - Options.yLim:         The y-bounds of the output image
%       - Options.pixelSearch:  The method of searching for the faces
%                               containing pixel centers
%                                   - 'AABB' (requires GPToolBox)
%                                   - 'Default' (MATLAB built-ins, faster than AABB)
%       - Options.numLayers:    The number of onion layers to create
%                               Format is [ (num +), (num -) ]
%       - Options.layerSpacing: The spacing between adjacent onion layers
%                               in units of pixels
%       - Options.smoothIter:   Number of iterations of Laplacian mesh
%                               smoothing to run on the mesh prior to
%                               vertex normal displacement (requires
%                               GPToolBox) (Default is 0)
%       - Options.vertexNormal: User supplied vertex unit normals to the
%                               texture triangulation
%       - Options.Interpolant:  A pre-made texture image volume interpolant
%
% NPMitchell 2020, based on Dillon Cislo's code



% Generate Tiled Orbifold Triangulation ------------------------------
tileCount = [1 1];  % how many above, how many below
[ TF, TV2D, TV3D ] = tileAnnularCutMesh( cutMesh, tileCount );

% View Results -------------------------------------------------------
% patch( 'Faces', TF, 'Vertices', TV2D, 'FaceVertexCData', ...
%     TV3D(:,3), 'FaceColor', 'interp', 'EdgeColor', 'k' );
% axis equal

if nargin < 5
    Options = struct ;
end

% Texture image options
if ~isfield(Options, 'PSize')
    Options.PSize = 5;
end
if ~isfield(Options, 'EdgeColor')
    Options.EdgeColor = 'none';
end
if ~isfield(Options, 'imSize')
    Options.imSize = ceil( 1000 .* [ 1 a ] );
end
if ~isfield(Options, 'yLim')
    Options.yLim = [0 1];
end

% profile on
% Create texture image
if any(isnan(TV2D))
    error('here -- check for NaNs case')
end
patchIm = texture_patch_to_image( TF, TV2D, TF, TV3D(:, [2 1 3]), ...
    IV, Options );
% profile viewer

fprintf('Done\n');

% View results --------------------------------------------
% imshow( patchIm );
% set( gca, 'YDir', 'Normal' );

% Write figure to file
disp(['Writing ' imfn]) 
imwrite( patchIm, imfn, 'TIFF' );            

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Save extended relaxed image
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
% disp('Generating relaxed, extended image...')          
% % Format axes
% xlim([0 ar]); ylim([-0.5 1.5]);
% 
% % Extract image from figure axes
% patchIm_e = getframe(gca);
% patchIm_e = rgb2gray(patchIm_e.cdata);
% 
% % Write figure to file
% imwrite( patchIm_e, ...
%     sprintf( fullfile([imFolder_re, '/', fileNameBase, '.tif']), t ), ...
%     'TIFF' );

% Close open figures
close all