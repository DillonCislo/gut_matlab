function [h1, h2] = scalarFieldOnImage(im, xy_or_fxy, sf, alphaVal, ...
    scale, labelOptions, varargin)
%SCALARFIELDONIMAGE(im, xx, yy, field, alphaVal, scale, label)
% Plot a scalar field over an image, colored by magnitude, with const alpha
% The heatmap style may be diverging, phasemap, positive, or negative.
%
% Example Usage
% -------------
% scalarFieldOnImage(im, xx, yy, reshape(vecnorm(vsm_ii, 2, 2), gridsz),...
%     alphaVal, vtscale, '$|v|$ [$\mu$m/min]', 'Style', 'Positive')
%
% Parameters
% ----------
% im : 
% xy_or_fxy : N x 2 float array, or struct with fields (faces/f, xy/v) 
%   xy coordinates of the field evaluation locations, or struct with faces
%   and vertex locations for drawing patches if field is defined on faces
%   The name of the fields are a bit flexible: faces can be faces or f,
%   vertices can be xy or v or pts or vertices
% sf : NxM float array
%   the scalar field to plot as heatmap
% alphaVal : float
%   the opacity of the heatmap
% scale : float
%   maximum absolute value for the field to be saturated in colormap
% labelOptions: struct with fields
%   label : str
%       colorbar label, interpreted through Latex by default
%   title : str
%       optional title, interpreted through Latex by default
%   xlabel : str
%       optional title, interpreted through Latex by default
%   ylabel : str
%       optional title, interpreted through Latex by default
% varargin : keyword arguments (optional, default='diverging') 
%   options for the plot, with names
%   'style' : 'diverging' or 'positive' or 'negative'
%   'interpreter' : 'Latex', 'default'/'none'
% 
%
% Returns
% -------
% h1 : handle for imshow
% h2 : handle for imagesc
%
%
% NPMitchell 2020

%% Default label Options
xlabelstr = '' ;
ylabelstr = '' ;
titlestr = '' ;
label = '' ;

%% Unpack labelOptions
if isfield(labelOptions, 'xlabel')
    xlabelstr = labelOptions.xlabel ;
end
if isfield(labelOptions, 'ylabel')
    ylabelstr = labelOptions.ylabel ;
end
if isfield(labelOptions, 'title')
    titlestr = labelOptions.title ;
end
if isfield(labelOptions, 'label')
    label = labelOptions.label ;
end

%% Unpack options for style (diverging, positive, negative) and cmap
style = 'diverging' ;     % default is diverging
label_interpreter = 'latex' ; % for colorbar label
if ~isempty(varargin)
    for i = 1:length(varargin)
        if isa(varargin{i},'double') 
            continue;
        end
        if isa(varargin{i},'logical')
            continue;
        end
        if ~isempty(regexp(varargin{i},'^[Ss]tyle','match'))
            stylestr = varargin{i+1} ;
        elseif ~isempty(regexp(varargin{i},'^[Ii]nterpreter','match'))
            label_interpreter = varargin{i+1} ;
        end
    end
    if ~isempty(regexp(stylestr,'^[Pp]hasemap','match'))
        style = 'phasemap' ;
    elseif ~isempty(regexp(stylestr,'^[Dd]iverging','match'))
        style = 'diverging' ;
    elseif ~isempty(regexp(stylestr,'^[Pp]ositive','match'))
        style = 'positive' ;
    elseif ~isempty(regexp(stylestr,'^[Nn]egative','match'))
        style = 'negative' ;
    end
    
end

% Show the image
h1 = imshow(im) ; hold on;
if isnumeric(xy_or_fxy)
    % Overlay the scalar field defined on vertices/xy points
    h2 = imagesc(xy_or_fxy(:, 1), xy_or_fxy(:, 2), sf) ;
    if strcmp(style, 'phasemap')
        caxis(gca, [0, 2*pi]) ;
        colormap(bwr) ;
    elseif strcmp(style, 'diverging')
        if scale > 0
            caxis(gca, [-scale, scale]) ;
        else
            caxis(gca, [min(sf(:)), max(sf(:))])
        end
        colormap(bwr) ;
    elseif strcmp(style, 'positive')
        if scale > 0
            caxis(gca, [0, scale]) ;
        else
            caxis(gca, [0, max(sf(:))])
        end
    elseif strcmp(style, 'negative')
        if scale > 0
            caxis(gca, [-scale, 0]) ;
        else
            caxis(gca, [min(sf(:)), 0]) ;
        end
    end
elseif isa(xy_or_fxy, 'struct')
    % Add the scalar field defined on faces
    % Unpack xy_or_fxy
    if isfield(xy_or_fxy, 'faces')
        FF = xy_or_fxy.faces ;
    elseif isfield(xy_or_fxy, 'f')
        FF = xy_or_fxy.faces ;
    else
        error('Face list for patches must be supplied as f or faces')
    end
    if isfield(xy_or_fxy, 'xy')
        V2D = xy_or_fxy.xy ;
    elseif isfield(xy_or_fxy, 'vertices')
        V2D = xy_or_fxy.vertices ;
    elseif isfield(xy_or_fxy, 'vertex')
        V2D = xy_or_fxy.vertex ;
    elseif isfield(xy_or_fxy, 'v')
        V2D = xy_or_fxy.v ;
    elseif isfield(xy_or_fxy, 'pts')
        V2D = xy_or_fxy.pts ;
    else
        error(['2d vertices of patches must be supplied as ', 
                'xy, v, vertex, vertices, or pts'])
    end
    
    % Create colors to paint patches
    if strcmp(style, 'phasemap')
        % Phasemap style
        cmap = phasemap ;
        colormap phasemap
        colors = mapValueToColor(sf, [0, 2*pi], cmap) ;
    elseif strcmp(style, 'diverging')
        % Diverging style
        cmap = bwr ;
        colormap bwr
        if scale > 0
            colors = mapValueToColor(sf, [-scale, scale], cmap) ;
            caxis(gca, [-scale, scale])
        else
            colors = mapValueToColor(sf, [min(sf(:)), max(sf(:))], cmap) ;
            caxis(gca, [min(sf(:)), max(sf(:))])
        end
    elseif strcmp(style, 'positive')
        % positive only
        cmap = parula ;
        colormap parula
        if scale < 0
            scale = max(sf(:)) ; 
        end
        colors = mapValueToColor(sf, [0, scale], cmap) ;
        caxis(gca, [0, scale])
    elseif strcmp(style, 'negative')
        % negative only
        cmap = parula ;
        colormap parula
        if scale < 0
            scale = min(sf(:)) ; 
        end
        colors = mapValueToColor(sf, [-scale, 0], cmap) ;
        caxis(gca, [-scale, 0])
    end
    h1 = patch( 'Faces', FF, 'Vertices', V2D, ...
        'FaceVertexCData', colors, 'FaceColor', 'flat', ...
        'EdgeColor', 'none') ;
end
alpha(alphaVal) ;

%% Labels
if ~isempty(titlestr)
    if ~strcmp(label_interpreter, 'default') && ~strcmp(label_interpreter, 'none')
        title(titlestr, 'Interpreter', label_interpreter) ;
    end
    title(titlestr) ;
end
if ~isempty(xlabelstr)
    if ~strcmp(label_interpreter, 'default') && ~strcmp(label_interpreter, 'none')
        xlabel(xlabelstr, 'Interpreter', label_interpreter) ;
    end
    xlabel(xlabelstr) ;
end
if ~isempty(ylabelstr)
    if ~strcmp(label_interpreter, 'default') && ~strcmp(label_interpreter, 'none')
        ylabel(ylabelstr, 'Interpreter', label_interpreter) ;
    end
    ylabel(ylabelstr) ;
end

%% Colorbar settings
c = colorbar();
% Manually flush the event queue and force MATLAB to render the colorbar
% necessary on some versions
drawnow
% Get the color data of the object that correponds to the colorbar
cdata = c.Face.Texture.CData;
% Change the 4th channel (alpha channel) to 10% of it's initial value (255)
cdata(end,:) = uint8(alphaVal * cdata(end,:));
% Ensure that the display respects the alpha channel
c.Face.Texture.ColorType = 'truecoloralpha';
% Update the color data with the new transparency information
c.Face.Texture.CData = cdata;
c.Label.String = label ;
if ~strcmp(label_interpreter, 'default') && ~strcmp(label_interpreter, 'none')
    c.Label.Interpreter = label_interpreter ;
end
