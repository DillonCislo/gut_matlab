function [ cutMesh, cp1Out, cp2Out, P ] = ...
    cylinderCutMesh(faceIn, vertexIn, normalIn, cp1, cp2, cutOptions)
%CYLINDERCUTMESH creates a cut mesh structure from a an input mesh.  
% Input mesh should be a topological cylinder.  
% Output mesh will be a topological disk.  
% The mesh is cut along an edge-based mesh geodesic between two input
% points.  Currently this method can only support a single cut path
%   INPUT PARAMETERS:
%       - faceIn:         #Fx3 face connectivity list
%       - vertexIn:       #VxD vertex coordinate list
%       - normalIn:       #VxD vertex normal list
%       - cp1:            Vertex ID of the cut path origin
%       - cp2:            Vertex ID of the cut path termination
%       - cutOptions:     optional struct with fields 'method' and 'cutP'
%   
%   OUTPUT PARAMETERS:
%       - cutMesh:      An ImSAnE-style mesh struct with additional fields
%                       to describe the cut mesh properties
%       - cp1Out:       Vertex ID of the final cut path origin
%       - cp2Out:       Vertex ID of the final cut path termination
%       - P:            shortest path, indices of original vertices
%

% testing
% faceIn = mesh.f ;
% vertexIn = mesh.v ;
% normalIn = mesh.vn ;
% cp1 = adIDx ;
% cp2 = pdIDx ;
%==========================================================================
% Calculate the Shortest Path Between Input Points Along Mesh Edges
%==========================================================================

% Ensure that the cutOptions are properly endowed with fields
% Use defaults if not
if nargin < 6
    cutOptions.method = 'fastest';
elseif strcmp(cutOptions.method, 'nearest')
    if ~isfield(cutOptions, 'path')
        error('cutOptions.path (path to match) must be supplied if cutOptions.method == nearest ')
    end
    if length(cutOptions.path) < 3
        error('cutOptions.path must be length>3 if cutOptions.method == nearest ')
    end
end

% MATLAB-style triangulation
meshTri = triangulation( faceIn, vertexIn );

% The vertex IDs of vertices on the mesh boundary
bdyIDx = meshTri.freeBoundary;
bdyIDx = unique(bdyIDx(:));

% The #Ex3 edge connectivity list of the mesh
edgeIn = edges( meshTri );

% Check that the input mesh is a topological cylinder
if ( length(vertexIn) - length(edgeIn) + length(faceIn) ) ~= 0
    error( 'Input mesh is NOT a topological cylinder!' );
end

% Check that the origin/terminal points lie on the mes
if ~ismember(cp1, bdyIDx) || ~ismember(cp2, bdyIDx)
    error('One or more input point does not lie on the mesh boundary!');
    % Show problem:
    trisurf(mesh.f, mesh.v(:, 1), mesh.v(:, 2), mesh.v(:, 3), 'EdgeColor', 'none', 'FaceAlpha', 0.2); 
    hold on;
    axis equal ;
    plot3(mesh.v(adIDx, 1), mesh.v(adIDx, 2), mesh.v(adIDx, 3), 'o') ;
    plot3(mesh.v(pdIDx, 1), mesh.v(pdIDx, 2), mesh.v(pdIDx, 3), 'o') ;
end

% Find edge lengths
L = vertexIn( edgeIn(:,2), : ) - vertexIn( edgeIn(:,1), : );
L = sqrt( sum( L.^2, 2 ) );

% Construct an #V x #V vertex adjacency matrix
A = sparse( [ edgeIn(:,1); edgeIn(:,2) ], ...
    [ edgeIn(:,2), edgeIn(:,1) ], ...
    [ L; L ], size(vertexIn, 1), size(vertexIn, 1) );

% A MATLAB-style weighted, undirected graph representation of the mesh
% triangulation.
G = graph(A);

% Find the path to cut, P. Note the method options
if strcmp(cutOptions.method, 'fastest') 
    % The shortest path
    P = shortestpath( G, cp1, cp2 )' ;
elseif strcmp(cutOptions.method, 'nearest')
    P = nearestpath( G, vertexIn, cp1, cp2, cutOptions.path) ;
else
    error(['Did not recognize cutOptions.method = ' cutOptions.method])
end

%--------------------------------------------------------------------------
% Truncate the path so that it does not include any boundary edges
%--------------------------------------------------------------------------

% Clip the head of the vector ---------------------------------------------
clipped = false;

while ~clipped
    if ismember(P(1), bdyIDx) && ismember(P(2), bdyIDx)
        P = P(2:end);
    else
        clipped = true;
    end
end

% Clip the tail of the vector ---------------------------------------------
clipped = false;

while ~clipped
    if ismember(P(end), bdyIDx) && ismember(P(end-1), bdyIDx)
        P = P(1:(end-1));
    else
        clipped = true;
    end
end

cp1Out = P(1);
cp2Out = P(end);

%==========================================================================
% Assemble the Basic Cut Mesh Structure
%==========================================================================

cutMesh = struct();

vertex = vertexIn; % The original vertex list
face = faceIn; % The original face list

% Add the duplicate vertices at the end of the vertex list
vertex = [ vertex; vertex(P, :) ];
cutMesh.v = vertex;
cutMesh.vn = [ normalIn; normalIn(P,:) ];

% A list of the shortest path vertex IDs and their duplicates
cutMesh.pathPairs = [ P, ((size(vertexIn,1)+1):size(vertex,1))' ];

% The IDs of the cut vertices in the original uncut mesh
cutMesh.cutIndsToUncutInds = [ (1:size(vertexIn,1))'; P ];

% IDs of the uncut vertices in the modified cut mesh
cutMesh.uncutIndsToCutInds = cell( size(vertexIn,1), 1 );
for v = 1:size(vertexIn,1)
    cutMesh.uncutIndsToCutInds{v} = ...
        find( cutMesh.cutIndsToUncutInds == v );
end

clear v

%==========================================================================
% Modify the Face List
%==========================================================================

% The cut path edge list
PP = [ P(1:end-1), P(2:end) ]; 

% Face attachments to cut cut edges
try
    PPE = cell2mat(meshTri.edgeAttachments( PP ));
catch
    % There are perhaps only one face attached to some edges. This must be
    % because the geodesic wanders along the sliced edge
    % Find where the problem starts and ends
    eattach = meshTri.edgeAttachments( PP ) ;
    ids = [] ;
    for dmyk = 1:length(eattach)
        fk = eattach{dmyk} ;
        if length(fk) < 2
            ids = [ids dmyk];
        end
    end
    
    if length(find(diff(ids) > 1))
        % Isolate contiguous regions of the problem area of the curve
        error('Todo: identify contiguous regions of the curve, use those to trim it')
    else
        disp('cylinderCutMesh: curve has one region living on the edge')
        if mean(ids) < length(eattach) * 0.5    
            % Begin the curve from the last edge point reached
            disp('--> trimming from the beginning')
            PP = PP(ids(end):end, :) ;
            P = P(ids(end):end) ;
        else
            % Terminate the curve at first edge point reached
            disp('--> terminating the curve early (trimming from end)')
            PP = PP(1:ids(1), :) ;
            P = P(1:ids(1)) ;
        end
    end
    
    % Inspect it
    if false
        for dmyk = 1:length(eattach)
            fk = eattach{dmyk} ;
            if length(fk) < 2
                ids = meshTri.ConnectivityList(fk, :) ;
                plot3(meshTri.Points(ids, 1), meshTri.Points(ids, 2), ...
                    meshTri.Points(ids, 3), '.');
                hold on;
            end
        end
        trisurf(meshTri, 'FaceAlpha', 0.2, 'EdgeColor', 'none')
        hold on;
        plot3(meshTri.Points(P, 1), meshTri.Points(P, 2), ...
                    meshTri.Points(P, 3), '-');
        axis equal
    end
    
end

% A list of face attachments in the original uncut mesh
fA = meshTri.neighbors;

% A list of positively oriented faces that share an edge with the path cut
left = false( size(face,1), 1);

% A list of negatively oriented faces that share an edge with the path cut
right = false( size(face,1), 1 );

%--------------------------------------------------------------------------
% Find faces that share an edge with the cut path and check their
% orientation
%--------------------------------------------------------------------------

for e = 1:size(PP,1)

    v1 = PP(e,1); % The first uncut vertex in the current edge
    v2 = PP(e,2); % The second uncut vertex in the current edge
    
    f1 = face(PPE(e,1), :); % The first face attached to the current edge
    f2 = face(PPE(e,2), :); % The second face attached to the current edge
    
    % Check the orientation of the attached faces
    if mod( find(f1==v2)-find(f1==v1), 3 ) == 1
        
        left( PPE(e,1), : ) = true;
        right( PPE(e,2), :) = true;
        
    elseif mod( find(f2==v2)-find(f2==v1), 3 ) == 1
    
        left( PPE(e,2), : ) = true;
        right( PPE(e,1), : ) = true;
        
    else
        
        error('Invalid face ordering!'); 
        
    end
    
end

%--------------------------------------------------------------------------
% Find all faces that share ANY vertex with the cut path
%--------------------------------------------------------------------------

pathFace = any( ismember( face, P ), 2 );

% Remove from this list all faces that share a full edge with the cut path
pathFace( left ) = false;
pathFace( right ) = false;

%--------------------------------------------------------------------------
% Associate the remaining faces with a particular side of the cut
%--------------------------------------------------------------------------

maxIter = 1000;

for i = 1:maxIter
    
    % Find all remaining faces adjacent to a face on the right hand side
    r = pathFace & any( ismember( fA, find(right) ), 2 );
    
    % Add the faces to the right hand side list
    right = right | r;
    
    % Find all remaining faces adjacent to a face on the left hand side
    l = pathFace & any( ismember( fA, find(left) ), 2 );
    
    % Add the faces to the left hand side list
    left = left | l;
    
    % Make sure that the left and right hand sides are adjoint
    right(left) = false;
    
    % Remove the faces found during this iteration from the list of
    % remaining faces
    pathFace( left ) = false;
    pathFace( right ) = false;
    
    % Terminate the classification if no faces remain
    if ~any( pathFace ), break; end
    
    % Check the maximum iteration count
    if i == maxIter
        error('Cutting process exceeds maximum iteration count!');
    end

end

%--------------------------------------------------------------------------
% Modify the face list on the right hand side
%--------------------------------------------------------------------------

% Iterate over cut path vertices
for i = 1:numel(P)
    
    % The vertex ID of the current cut path vertex
    v = P(i);
    
    % The duplicate ID of the current vertex
    vP = size(vertexIn,1) + i;
    
    % The faces on the right hand side of the seam
    tRight = face( right, : );
    
    % Replace the vertex ID in these faces
    tRight( tRight == v ) = vP;
    
    % Insert the modified faces back into the face list
    face( right, : ) = tRight;
    
    
end

cutMesh.f = face;

% Check that the cut mesh is a topological disk (Euler characteristic) ----

% The updated edge list
edge = edges( triangulation( face, vertex ) );

eulerChi = size(vertex, 1) - size(edge,1) + size(face,1);

if eulerChi ~= 1
    error('Output mesh is NOT a topological disk!');
end


end

