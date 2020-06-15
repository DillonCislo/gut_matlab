classdef QuapSlap < handle
    % Quasi-Axisymmetric Pipeline for Surface Lagrangian Pullbacks class
    %
    % flipy         % APDC coord system is mirrored XZ wrt raw data
    % xyzlim        % mesh limits in full resolution pixels, in data space
	% xyzlim_um     % mesh limits in lab APDV frame in microns
    % resolution    % resolution of pixels in um
    % rot           % APDV rotation matrix
    % trans         % APDV translation 
    properties
        xp
        timeinterval
        timeunits
        dir
        dirBase
        fileName
        fileBase
        fullFileBase
        APDV = struct('resolution', [], ...
            'rot', [], ...
            'trans', [])
        flipy 
        nV 
        nU
        t0                      % reference time in the experiment
        normalShift
        axisOrderIV2Mesh
        a_fixed
        phiMethod = '3dcurves'  % must be '3dcurves' or 'texture'
        endcapOptions
        plotting = struct('preview', false, ...
            'save_ims', true, ...
            'xyzlim', [], ...
            'xyzlim_raw', [], ...
            'xyzlim_um', [] )
        apdvCOM = struct('acom', [], ...
            'pcom', [], ... 
            'acom_sm', [], ...
            'pcom_sm', [], ... 
            'dcom', [], ... 
            'acom_rs', [], ... 
            'pcom_rs', [], ... 
            'dcom_rs', [])
        apdvCOMOptions
        currentTime
        currentMesh = struct('cylinderMesh', [], ...
            'cylinderMeshClean', [], ...
            'cutMesh', [], ...
            'cutPath', [], ...
            'spcutMesh', []) 
        data = struct('adjustlow', 0, ...
            'adjusthigh', 0, ...
            'axisOrder', [1 2 3]) 
        currentData = struct('IV', [], ...
            'adjustlow', 0, ...
            'adjusthigh', 0 ) 
        cleanCntrlines
        
    end
    
    methods
        function QS = QuapSlap(xp, opts)
            QS.xp = xp ;
            QS.flipy = opts.flipy ;
            meshDir = opts.meshDir ;
            QS.timeinterval = opts.timeinterval ;
            QS.timeunits = opts.timeunits ;
            QS.fileBase.fn = xp.fileMeta.filenameFormat ;
            QS.nV = opts.nV ;
            QS.nU = opts.nU ;
            
            QS.normalShift = opts.normalShift ;
            QS.a_fixed = opts.a_fixed ;
            if isfield(opts, 'adjustlow')
                QS.data.adjustlow = opts.adjustlow ;
            end
            if isfield(opts, 'adjusthigh')
                QS.data.adjusthigh = opts.adjusthigh ;
            end
            if isfield(opts, 'axisOrder')
                QS.data.axisOrder = opts.axisOrder ;
            end
            uvexten = sprintf('_nU%04d_nV%04d', QS.nU, QS.nV) ;
            
            % APDV coordinate system
            QS.APDV.resolution = min(xp.fileMeta.stackResolution) ;
            QS.APDV.rot = [] ;
            QS.APDV.trans = [] ;
            
            % dirs
            QS.dir.dataDir = xp.fileMeta.dataDir ;
            QS.dir.mesh = meshDir ;
            QS.dir.alignedMesh = fullfile(meshDir, 'aligned_meshes') ;
            QS.dir.cntrline = fullfile(meshDir, 'centerline') ;
            QS.dir.cylinderMesh = fullfile(meshDir, 'cylinder_meshes') ;
            QS.dir.cutMesh = fullfile(meshDir, 'cutMesh') ;
            QS.dir.cylinderMeshClean = fullfile(QS.dir.cylinderMesh, 'cleaned') ;
            
            % Metric strain dirs
            QS.dir.gstrain = fullfile(meshDir, 'metric_strain') ;
            QS.dir.gstrainRate = fullfile(QS.dir.gstrain, 'rateMetric') ;
            QS.dir.gstrainRateIm = fullfile(QS.dir.gstrainRate, 'images') ;
            QS.dir.gstrainVel = fullfile(QS.dir.gstrain, 'velMetric') ;
            QS.dir.gstrainVelIm = fullfile(QS.dir.gstrainVel, 'images') ;
            QS.dir.gstrainMesh = fullfile(QS.dir.gstrain, 'meshMetric') ;
            QS.dir.gstrainMeshIm = fullfile(QS.dir.gstrainMesh, 'images') ;
            QS.fileBase.gstrainVel = 'gstrainVel_%06d.mat' ;
            QS.fileBase.gstrainMesh = 'gstrainMesh_%06d.mat' ;
            QS.fileBase.gstrainRate = 'gstrainRate_%06d.mat' ;
            QS.fullFileBase.gstrainVel = fullfile(QS.dir.gstrainVel, ...
                QS.fileBase.gstrainVel) ;
            QS.fullFileBase.gstrainMesh = fullfile(QS.dir.gstrainMesh, ...
                QS.fileBase.gstrainMesh) ; 
            QS.fullFileBase.gstrainRate = fullfile(QS.dir.gstrainRate, ...
                QS.fileBase.gstrainRate) ; 
            QS.dir.compressibility = fullfile(QS.dir.mesh, 'compressibility') ;
            QS.dir.compressibility2d = ...
                fullfile(QS.dir.compressibility, 'images_2d') ;
            QS.dir.compressibility3d = ...
                fullfile(QS.dir.compressibility, 'images_3d') ;
            QS.fullFileBase.compressibility2d = ...
                fullfile(QS.dir.compressibility2d, 'compr_2d_%06d.png') ;
            QS.fullFileBase.compressibility3d = ...
                fullfile(QS.dir.compressibility3d, 'compr_3d_%06d.png') ;
            
            % shorten variable names for brevity
            clineDir = QS.dir.cntrline ;
            
            % fileBases
            QS.fileBase.name = xp.fileMeta.filenameFormat(1:end-4) ;
            QS.fileBase.mesh = ...
                [xp.detector.options.ofn_smoothply '%06d'] ;
            QS.fileBase.alignedMesh = ...
                [QS.fileBase.mesh '_APDV_um'] ;
            QS.fileBase.centerlineXYZ = ...
                [QS.fileBase.mesh '_centerline_exp1p0_res*.txt' ] ;
            QS.fileBase.centerlineAPDV = ...
                [QS.fileBase.mesh '_centerline_scaled_exp1p0_res*.txt' ] ;
            QS.fileBase.cylinderMesh = ...
                [QS.fileBase.mesh '_cylindercut.ply'] ;
            QS.fileBase.apBoundary = 'ap_boundary_indices_%06d.mat';
            QS.fileBase.cylinderKeep = 'cylinderMesh_keep_indx_%06.mat' ;
            QS.fileName.apBoundaryDorsalPts = 'ap_boundary_dorsalpts.h5' ;
            
            % Clean Cylinder Mesh
            QS.fileName.aBoundaryDorsalPtsClean = ...
                fullfile(QS.dir.cylinderMeshClean, 'adIDx.h5') ;
            QS.fileName.pBoundaryDorsalPtsClean = ...
                fullfile(QS.dir.cylinderMeshClean, 'pdIDx.h5') ;
            
            % cutMesh
            QS.fullFileBase.cutPath = fullfile(QS.dir.cutMesh, 'cutPaths_%06d.txt') ;
            
            % fileNames
            QS.fileName.rot = fullfile(meshDir, 'rotation_APDV.txt') ;
            QS.fileName.trans = fullfile(meshDir, 'translation_APDV.txt') ;
            QS.fileName.xyzlim_raw = fullfile(meshDir, 'xyzlim.txt') ;
            QS.fileName.xyzlim = fullfile(meshDir, 'xyzlim.txt') ;
            QS.fileName.xyzlim_um = fullfile(meshDir, 'xyzlim_APDV_um.txt') ;
            % fileNames for APDV and cylinderMesh
            QS.fileName.apdv = ...
                fullfile(clineDir, 'apdv_coms_from_training.h5') ;
            QS.fileName.startendPt = fullfile(clineDir, 'startendpt.h5') ;
            QS.fileName.cleanCntrlines = ...
                fullfile(clineDir, 'centerlines_anomalies_fixed.mat') ;
            QS.fileName.apBoundaryDorsalPts = ...
                fullfile(QS.dir.cylinderMesh, 'ap_boundary_dorsalpts.h5') ;
            QS.fileName.endcapOptions = ...
                fullfile(QS.dir.cylinderMesh, 'endcapOptions.mat') ;
            QS.fileName.apdBoundary = ...
                fullfile(QS.dir.cylinderMesh, 'ap_boundary_dorsalpts.h5') ;
            
            % FileNamePatterns
            QS.fullFileBase.mesh = ...
                fullfile(QS.dir.mesh, [QS.fileBase.mesh '.ply']) ;
            QS.fullFileBase.alignedMesh = ...
                fullfile(QS.dir.alignedMesh, [QS.fileBase.alignedMesh '.ply']) ;
            % fileNames for centerlines
            QS.fullFileBase.centerlineXYZ = ...
                fullfile(clineDir, QS.fileBase.centerlineXYZ) ;
            QS.fullFileBase.centerlineAPDV = ...
                fullfile(clineDir, QS.fileBase.centerlineAPDV) ;
            QS.fullFileBase.cylinderMesh = ...
                fullfile(QS.dir.cylinderMesh, QS.fileBase.cylinderMesh) ;
            QS.fullFileBase.apBoundary = ...
                fullfile(QS.dir.cylinderMesh, QS.fileBase.apBoundary) ;
            QS.fullFileBase.apBoundaryDorsalPts = ...
                fullfile(QS.dir.cylinderMesh, QS.fileName.apBoundaryDorsalPts) ;
            QS.fullFileBase.cylinderKeep = ...
                fullfile(QS.dir.cylinderMesh, QS.fileBase.cylinderKeep) ;
            QS.fullFileBase.cylinderMeshClean = ...
                fullfile(QS.dir.cylinderMesh, 'cleaned',...
                [QS.fileBase.mesh '_cylindercut_clean.ply']) ;            
            
            % Define cutMesh directories
            nshift = strrep(sprintf('%03d', QS.normalShift), '-', 'n') ;
            shiftstr = ['_' nshift 'step'] ;
            % cutFolder = fullfile(meshDir, 'cutMesh') ;
            % cutMeshBase = fullfile(cutFolder, [QS.fileBase.name, '_cutMesh.mat']) ;
            imFolderBase = fullfile(meshDir, ['PullbackImages' shiftstr uvexten] ) ;
            sphiDir = fullfile(meshDir, ['sphi_cutMesh' shiftstr uvexten]) ;
            sphiSmDir = fullfile(sphiDir, 'smoothed') ;
            sphiSmRSDir = fullfile(sphiDir, 'smoothed_rs') ;
            % sphiSmRSImDir = fullfile(sphiSmRSDir, 'images') ;
            % sphiSmRSPhiImDir = fullfile(sphiSmRSImDir, 'phicolor') ;
            sphiSmRSCDir = fullfile(sphiDir, 'smoothed_rs_closed') ;
            imFolder_sp = [imFolderBase '_sphi'] ;
            imFolder_spe = fullfile(imFolder_sp, 'extended') ;
            imFolder_up = [imFolderBase '_uphi'] ;
            imFolder_upe = fullfile(imFolder_up, 'extended') ;
            % time-averaged meshes
            imFolder_spsm = fullfile(imFolder_sp, 'smoothed') ;
            imFolder_spsme = fullfile(imFolder_sp, 'extended_smoothed') ;  % raw LUT, no histeq
            imFolder_spsme2 = fullfile(imFolder_sp, 'extended_LUT_smoothed') ;  % with histeq?
            imFolder_rsm = fullfile([imFolderBase, '_sphi_relaxed'], 'smoothed');
            imFolder_rsme = fullfile([imFolderBase, '_sphi_relaxed'], 'smoothed_extended') ;
            % Lobe/fold identification paths
            lobeDir = fullfile(meshDir, 'lobes') ;
            foldHoopImDir = fullfile(lobeDir, 'constriction_hoops') ;
            % Folder for curvature measurements
            KHSmDir = fullfile(sphiSmRSCDir, 'curvature') ;
            KSmDir = fullfile(KHSmDir, 'gauss') ;
            HSmDir = fullfile(KHSmDir, 'mean') ;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Port into QS
            QS.dir.cutFolder = fullfile(meshDir, 'cutMesh') ;
            QS.dir.spcutMesh = sphiDir ;
            QS.dir.spcutMeshSm = sphiSmDir ;
            QS.dir.spcutMeshSm = sphiSmRSDir ;
            QS.dir.spcutMeshSmRS = sphiSmRSCDir ;
            QS.dir.clineDVhoop = ...
                fullfile(QS.dir.cntrline, ...
                ['centerline_from_DVhoops' shiftstr uvexten]) ;
            QS.dir.writhe =  fullfile(QS.dir.clineDVhoop, 'writhe') ;
            QS.dir.im_uv = [imFolderBase '_uv'] ;
            QS.dir.im_uve = [imFolderBase '_uv_extended'] ;
            QS.dir.im_r = [imFolderBase '_sphi_relaxed'] ;
            QS.dir.im_re = [imFolderBase '_sphi_relaxed_extended'] ;
            QS.dir.im_sp = imFolder_sp ;
            QS.dir.im_spe = imFolder_spe ;
            QS.dir.im_up = imFolder_up ;
            QS.dir.im_upe = imFolder_upe ;
            QS.dir.im_sp_sm = imFolder_spsm ;
            QS.dir.im_sp_sme = imFolder_spsme ;
            QS.dir.im_sp_sme2 = imFolder_spsme2 ;
            QS.dir.im_r_sm = imFolder_rsm ;
            QS.dir.im_r_sme = imFolder_rsme ;
            QS.dir.piv = fullfile(meshDir, 'piv') ;
            QS.dir.lobe = lobeDir ;
            QS.dir.foldHoopIm = foldHoopImDir ;
            QS.fullFileBase.cutMesh = ...
                fullfile(QS.dir.cutMesh, [QS.fileBase.name, '_cutMesh.mat']) ;
            QS.fullFileBase.phi0fit = ...
                fullfile(QS.dir.spcutMesh, 'phi0s_%06d_%02d.png') ; 
            QS.fullFileBase.clineDVhoop = ...
                fullfile(QS.dir.clineDVhoop,...
                'centerline_from_DVhoops_%06d.mat');
            % filenames for lobe dynamics
            QS.fileName.fold = fullfile(lobeDir, ...
                ['fold_locations_sphi' uvexten '_avgpts.mat']) ;
            QS.fileName.lobeDynamics = ...
                fullfile(lobeDir, ['lobe_dynamics' uvexten '.mat']) ;
            
            %  spcutMesh and pullbacks
            QS.fullFileBase.spcutMesh = ...
                fullfile(sphiDir, 'mesh_apical_stab_%06d_spcutMesh.mat') ;
            QS.fileBase.spcutMesh = 'mesh_apical_stab_%06d_spcutMesh' ;
            QS.fullFileBase.spcutMeshSm = ...
                fullfile(sphiSmDir, '%06d_spcutMeshSm.mat') ;
            QS.fileBase.spcutMeshSm = '%06d_spcMeshSm' ;
            QS.fullFileBase.spcutMeshSmRS = ...
                fullfile(sphiSmRSDir, '%06d_spcutMeshSmRS.mat') ;
            QS.fileBase.spcutMeshSmRS = '%06d_spcMeshSmRS' ;
            QS.fullFileBase.spcutMeshSmRSC = ...
                fullfile(sphiSmRSCDir, '%06d_spcMSmRSC.mat') ;
            QS.fullFileBase.spcutMeshSmRSCPLY = ...
                fullfile(sphiSmRSCDir, '%06d_spcMSmRSC.ply') ;
            QS.fileBase.spcutMeshSmRSC = '%06d_spcMSmRSC' ;
            QS.fileBase.im_uv = [QS.fileBase.name, '_pbuv.tif'] ;
            QS.fullFileBase.im_uv = ...
                fullfile(QS.dir.im_uv, QS.fileBase.im_uv) ;
            QS.fileBase.im_r = [QS.fileBase.name, '_pr.tif'] ;
            QS.fullFileBase.im_r = ...
                fullfile(QS.dir.im_r, QS.fileBase.im_r) ;
            QS.fileBase.im_re = [QS.fileBase.name, '_pre.tif'] ;
            QS.fullFileBase.im_re =  ...
                fullfile(QS.dir.im_re, QS.fileBase.im_re) ;
            QS.fileBase.im_sp = [QS.fileBase.name, '_pbsp.tif'] ;
            QS.fullFileBase.im_sp = ...
                fullfile(QS.dir.im_sp, QS.fileBase.im_sp);
            QS.fileBase.im_up = [QS.fileBase.name, '_pbup.tif'] ;
            QS.fullFileBase.im_up = ...
                 fullfile(QS.dir.im_up, QS.fileBase.im_up) ;
            QS.fullFileBase.im_r_cells = ...
                 fullfile(QS.fullFileBase.im_r, ...
                 'cell_ID_Probabilities', ...
                 [QS.fileBase.name, '_Probabilities_pr.h5']) ;
            
            % PIV
            QS.dir.piv = fullfile(meshDir, 'piv') ;
            QS.dir.pivSimAvg = fullfile(QS.dir.piv, 'simpleAvg') ;
             
            % Ensure directories
            dirs2make = struct2cell(QS.dir) ;
            for ii=1:length(dirs2make)
                dir2make = dirs2make{ii} ;
                if ~exist(dir2make, 'dir')
                    mkdir(dir2make)
                end
            end
        end
        
        function setTime(QS, tt)
            if tt ~= QS.currentTime
                QS.currentMesh.cylinderMesh = [] ;
                QS.currentMesh.cylinderMeshClean = [] ;
                QS.currentMesh.cutMesh = [] ;
                QS.currentMesh.cutPath = [] ;
                QS.currentMesh.spcutMesh = [] ;
                QS.currentMesh.cutMesh = [] ;
                QS.currentMesh.spcutMesh = [] ;
                QS.currentData.IV = [] ;
                QS.currentData.adjustlow = 0 ;
                QS.currentData.adjusthigh = 0 ;
            end
            QS.currentTime = tt ;
            QS.xp.setTime(tt) ;
        end
        
        function t0 = t0set(QS, t0)
            % t0set(QS, t0) Set time offset to 1st fold onset or manually 
            if nargin < 2
                try
                    % Note that fold_onset is in units of timepoints, not 
                    % indices into timepoints
                    load(QS.fileName.fold, 'fold_onset') ;
                    QS.t0 = min(fold_onset) ;
                catch
                    error('No folding times saved to disk')
                end
            else
                QS.t0 = t0 ;
            end
            t0 = QS.t0 ;
        end
        
        function [acom_sm, pcom_sm] = getAPCOMSm(QS) 
            acom_sm = h5read(QS.fileName.apdv, '/acom') ;
            pcom_sm = h5read(QS.fileName.apdv, '/pcom') ;
        end
        
        function [rot, trans] = getRotTrans(QS)
            % Load the translation to put anterior to origin
            if ~isempty(QS.APDV.trans)
                % return from self
                trans = QS.APDV.trans ;
            else
                % load from disk
                trans = importdata(QS.fileName.trans) ;
                QS.APDV.trans = trans ;
            end
            % Load the rotation from XYZ to APDV coordinates
            if ~isempty(QS.APDV.rot)
                rot = QS.APDV.rot ;
            else
                % Load the rotation matrix
                rot = importdata(QS.fileName.rot) ;
                QS.APDV.rot = rot ;
            end
        end
        
        function [xyzlim_raw, xyzlim, xyzlim_um] = getXYZLims(QS)
            % Grab each xyzlim from self, otherwise load from disk
            if ~isempty(QS.plotting.xyzlim_raw)
                xyzlim_raw = QS.plotting.xyzlim_raw ;
            else
                xyzlim_raw = dlmread(QS.fileName.xyzlim_raw, ',', 1, 0) ; 
                QS.plotting.xyzlim_raw = xyzlim_raw ;
            end
            if ~isempty(QS.plotting.xyzlim)
                xyzlim = QS.plotting.xyzlim ;
            else
                xyzlim = dlmread(QS.fileName.xyzlim, ',', 1, 0) ;
                QS.plotting.xyzlim = xyzlim ;
            end
            if ~isempty(QS.plotting.xyzlim_um)
                xyzlim_um = QS.plotting.xyzlim_um ;
            else
                xyzlim_um = dlmread(QS.fileName.xyzlim_um, ',', 1, 0) ;
                QS.plotting.xyzlim_um = xyzlim_um ;
            end
        end
        
        function data = loadBioFormats(QS, fullFileName)
            r = bfGetReader(fullFileName);
            r.setSeries(QS.xp.fileMeta.series-1);
            nChannelsUsed = numel(QS.xp.expMeta.channelsUsed);
            if QS.xp.fileMeta.swapZT == 0
                stackSize = [r.getSizeX(), r.getSizeY(), r.getSizeZ(), r.getSizeT()];
            else
                stackSize = [r.getSizeX(), r.getSizeY(), r.getSizeT(), r.getSizeZ()];
            end
            debugMsg(2, ['stack size (xyzt) ' num2str(stackSize) '\n']);

            xSize = stackSize(1);
            ySize = stackSize(2);
            zSize = stackSize(3);
            
            % number of channels
            nTimePts = stackSize(4);
            
            data = zeros([ySize xSize zSize nChannelsUsed], 'uint16');
            for i = 1:r.getImageCount()

                ZCTidx = r.getZCTCoords(i-1) + 1;
                
                % in the fused embryo data coming out of the python script,
                % Z and T are swaped. In general this isn't the case, thus
                % introduce a file metaField swapZT
                if QS.xp.fileMeta.swapZT == 0
                    zidx = ZCTidx(1);
                    tidx = ZCTidx(3);
                else 
                    zidx = ZCTidx(3);
                    tidx = ZCTidx(1);
                end
                cidx = ZCTidx(2);

                % see above: if there is only one timepoint all the planes
                % should be read, if there are multiple timepoints, only
                % the correct time should be read
                if nTimePts == 1 || (nTimePts > 1 && this.currentTime == tidx-1)
                    
                    debugMsg(1,'.');
                    if rem(i,80) == 0
                        debugMsg(1,'\n');
                    end

                    dataCidx = find(QS.xp.expMeta.channelsUsed == cidx);
                    if ~isempty(dataCidx)
                        data(:,:, zidx, dataCidx) = bfGetPlane(r, i);
                    else
                        disp('skipping channel and z plane')
                    end
                end
            end
        end
        
        function getCurrentData(QS)
            if isempty(QS.currentTime)
                error('No currentTime set. Use QuapSlap.setTime()')
            end
            if isempty(QS.currentData.IV)
                % Load 3D data for coloring mesh pullback
                QS.xp.loadTime(QS.currentTime);
                QS.xp.rescaleStackToUnitAspect();
                IV = QS.xp.stack.image.apply() ;
                adjustlow = QS.data.adjustlow ;
                adjusthigh = QS.data.adjusthigh ;
                QS.currentData.IV = QS.adjustIV(IV, adjustlow, adjusthigh) ;
            end
        end
        
        function IV = adjustIV(QS, IV, adjustlow, adjusthigh)
            if nargin > 2 
                adjustlow = QS.data.adjustlow ;
                adjusthigh = QS.data.adjusthigh ;
            end
            if nargin < 2 
                if ~isempty(QS.currentData.IV) 
                    IV = QS.currentData.IV ;
                end
            end
            % custom image intensity adjustment
            if adjustlow == 0 && adjusthigh == 0
                disp('Using default limits for imadjustn')
                for ii = 1:length(IV)
                    IV{ii} = imadjustn(IV{ii});
                end
            else
                disp('Taking custom limits for imadjustn')
                for ii = 1:length(IV)
                    IVii = IV{ii} ;
                    vlo = double(prctile( IVii(:) , adjustlow )) / double(max(IVii(:))) ;
                    vhi = double(prctile( IVii(:) , adjusthigh)) / double(max(IVii(:))) ;
                    disp(['--> ' num2str(vlo) ', ' num2str(vhi)])
                    IV{ii} = imadjustn(IVii, [double(vlo); double(vhi)]) ;
                end
            end
            if nargout > 0
                disp('Attributing to self.currentData.IV')
                QS.currentData.IV = IV ;
                QS.currentData.adjustlow = adjustlow ;
                QS.currentData.adjustlow = adjusthigh ;
            else
                disp('WARNING: returning IV instead of attributing to self')
            end
        end
        
        % APDV methods
        function getAPDCOMs(QS, apdvCOMOptions)
            computeAPDCOMs(QS, apdvCOMOptions)
        end
        
        function ars = xyz2APDV(QS, a)
            % transform 3d coords from XYZ data space to APDV coord sys
            [ro, tr] = QS.getRotTrans() ;
            ars = ((ro * a')' + tr) * QS.APDV.resolution ;
            if QS.flipy
                ars(:, 2) = - ars(:, 2) ;
            end
        end
        function setAPDVCOMOptions(QS, apdvCOMOpts)
            QS.apdvCOMOptions = apdvCOMOpts ;
        end        
        function apdvCOMOptions = loadAPDVCOMOptions(QS)
            load(QS.fileName.apdvCOMOptions, 'apdvCOMOptions')
            QS.apdvCOMOptions = apdvCOMOptions ;
        end        
        function apdvCOMOptions = saveAPDVCOMOptions(QS)
            apdvCOMOptions = QS.APDVCOMs.apdvCOMOptions ;
            save(QS.fileName.apdvCOMOptions, 'apdvCOMOptions')
        end
        
        % Surface Area and Volume over time
        measureSurfaceAreaVolume(QS, options)
        
        % Centerlines & cylinderMesh
        extractCenterlineSeries(QS, cntrlineOpts)
        function setEndcapOptions(QS, endcapOpts)
            QS.endcapOptions = endcapOpts ;
        end        
        function loadEndcapOptions(QS)
            QS.endcapOptions = ...
                load(QS.fileName.endcapOptions, 'endcapOptions');
        end        
        function saveEndcapOptions(QS)
            endcapOptions = QS.endcapOptions ;
            save(QS.fileName.endcapOptions, 'endcapOptions')
        end
        sliceMeshEndcaps(QS, endcapOpts, methodOpts)
        generateCleanCntrlines(QS, idOptions)
        function getCleanCntrlines(QS)
            if isempty(QS.cleanCntrlines)
                try
                    tmp = load(QS.fileName.cleanCntrlines, 'cntrlines') ;
                    QS.cleanCntrlines = tmp.cntrlines ;
                    disp('Loaded clean centerlines from disk')
                catch
                    disp('No clean centerlines on disk, generating...')
                    QS.cleanCntrlines = generateCleanCntrlines(QS, idOptions) ;
                end
            end
        end
        function loadCurrentCylinderMeshlean(QS)
            cylmeshfn = ...
                sprintf( QS.fullFileBase.cylinderMesh, QS.currentTime ) ;
            QS.currentMesh.cylinderMesh = read_ply_mod( cylmeshfn );
        end
        function loadCurrentCylinderMeshClean(QS)
            cylmeshfn = ...
                sprintf( QS.fullFileBase.cylinderMeshClean, QS.currentTime ) ;
            disp(['Loading cylinderMeshClean ' cylmeshfn])
            QS.currentMesh.cylinderMeshClean = read_ply_mod( cylmeshfn );
        end
        
        % cutMesh
        generateCurrentCutMesh(QS)
        plotCutPath(QS, cutMesh, cutPath)
        function loadCurrentCutMesh(QS)
            if isempty(QS.currentTime)
                error('No currentTime set. Use QuapSlap.setTime()')
            end
            cutMeshfn = sprintf(QS.fullFileBase.cutMesh, QS.currentTime) ;
            cutPfn = sprintf(QS.fullFileBase.cutPath, QS.currentTime) ;
            tmp = load(cutMeshfn, 'cutMesh') ;
            tmp.cutMesh.v = tmp.cutMesh.v + tmp.cutMesh.vn * QS.normalShift ;
            QS.currentMesh.cutMesh = tmp.cutMesh ;
            QS.currentMesh.cutPath = dlmread(cutPfn, ',', 1, 0) ;
        end
        
        % spcutMesh
        generateCurrentSPCutMesh(QS, cutMesh, overwrite)
        function loadCurrentSPCutMesh(QS)
            spcutMeshfn = sprintf(QS.fullFileBase.spcutMesh, QS.currentTime) ;
            tmp = load(spcutMeshfn, 'spcutMesh') ;
            QS.currentMesh.spcutMesh = tmp.spcutMesh ;
        end
        
        % Pullback handling
        function doubleCoverPullbackImages(QS, options)
            % options : struct with fields
            %   coordsys : ('sp', 'uv', 'up')
            %       coordinate system to make double cover 
            %   overwrite : bool, default=false
            %       whether to overwrite current images on disk
            %   histeq : bool, default=true
            %       perform histogram equilization during pullback
            %       extension
            %   ntiles : int, default=50 
            %       The number of bins in each dimension for histogram equilization for a
            %       square original image. That is, the extended image will have (a_fixed *
            %       ntiles, 2 * ntiles) bins in (x,y).
            %   a_fixed : float, default=QS.a_fixed
            %       The aspect ratio of the pullback image: Lx / Ly          
            %   fnsearch : str, default=
            
            if nargin > 1
                % unpack options
                if isfield(options, 'coordsys')
                    coordsys = options.coordsys ;
                    options = rmfield(options, 'coordsys') ;
                    if strcmp(coordsys, 'sp')
                        imDir = QS.dir.im_sp ;
                        imDir_e = QS.dir.im_spe ;
                        fn0 = QS.fileBase.im_sp ;
                    elseif strcmp(coordsys, 'uv')
                        imDir = QS.dir.im_uv ;
                        imDir_e = QS.dir.im_uve ;
                        fn0 = QS.fileBase.im_uv ;
                    elseif strcmp(coordsys, 'up')
                        imDir = QS.dir.im_up ;
                        imDir_e = QS.dir.im_upe ;
                        fn0 = QS.fileBase.im_up ;
                    end
                else
                    % Default value of coordsys = 'sp' ;
                    imDir = QS.dir.im_sp ;
                    imDir_e = QS.dir.im_spe ;
                    fn0 = QS.fileBase.im_sp ;
                end
                
                % pack options if missing fields
                if ~isfield(options, 'histeq')
                    % equalize the histogram in patches of the image
                    options.histeq = true ;
                end
                if ~isfield(options, 'a_fixed')
                    % Assign the aspect ratio for histogram equilization
                    options.a_fixed = QS.a_fixed ;
                end
                if ~isfield(options, 'ntiles')
                    % Number of tiles per circumference and per unit ap
                    % length, so that if aspect ratio is two, there will be
                    % 2*ntiles samplings for histogram equilization along
                    % the ap axis
                    options.ntiles = 50 ;
                end
                if ~isfield(options, 'overwrite')
                    options.overwrite = false ;
                end
                if ~isfield(options, 'fnsearch')
                    % Attempt to guess what the filename of the images are
                    split_string = strsplit(fn0, '%0') ;
                    cont2 = strsplit(split_string{2}, 'd') ;
                    cont2 = strjoin(cont2(2:end), '') ;
                    fnsearch = strjoin({split_string{1}, '*', cont2, ...
                        strjoin(split_string(3:end))}, '') ;
                    disp(['Guessing fnsearch: ', fnsearch])
                end
            else
                % Default options
                % Default value of coordsys = 'sp' ;
                options = struct() ;
                imDir = QS.dir.im_sp ;
                imDir_e = QS.dir.im_spe ;
                options.histeq = true ;
                options.a_fixed = QS.a_fixed ;
                options.ntiles = ntiles ;
            end
            extendImages(imDir, imDir_e, fnsearch, options)
            disp(['done ensuring extended tiffs for ' imDir ' in ' imDir_e])
        end
        
        % identify folds
        identifyFolds(QS, options)
        
        % measure writhe
        measureWrithe(QS, options)
        
        % measure Lobe dynamics
        [lengths, areas, volumes] = measureLobeDynamics(QS, options)
        
        % density of cells -- nuclei or membrane based
        measureCellDensity(QS, nuclei_or_membrane)
        function loadCurrentNuclearDensity(QS)
            if QS.currentData
                disp('Loading from self')
            else
                disp('Loading from disk')
            end
        end
        
        % spcutMeshSmStack
        generateSPCutMeshSmStack(QS, spcutMeshSmStackOptions)
        measureThickness(QS, thicknessOptions)
        phi0_fit = fitPhiOffsetsViaTexture(QS, uspace_ds_umax, vspace,...
            phi0_init, phi0TextureOpts)
       
        % spcutMeshSm coordinate system demo
        coordinateSystemDemo(QS)
        
        % flow measurements
        
        % compressible/incompressible flow on evolving surface
        [cumerr, HHs, divvs, velns] = measureCompressibility(QS, lambda, lambda_err)
        
    end
    
    methods (Static)
    end
    
end