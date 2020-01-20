%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% script to read 16 bit images and output the mips 
% NPMitchell 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; close all;
%%
mipoutdir = 'mips_stab' ;
if ~exist(mipoutdir, 'dir')
    mkdir(mipoutdir)
end

addpath('/mnt/data/code');
addpath('/mnt/data/code/imsaneV1/external/bfmatlab/');
scale = 1.; % 0.02
% Offset for setting what timestep is t=0
t_off = 0;
dataDir    = cd;
cd(dataDir)

filenameFormat  = 'deconvolved_16bit/Time_%06d_c1_stab.tif';
msgLevel = 1;
setpref('ImSAnE', 'msgLevel', msgLevel);
%%
timePoints      = [10:169];

% Make the subdirectories for the mips if not already existing
mipdirs = {fullfile(mipoutdir, 'view1/'), ...
    fullfile(mipoutdir, 'view2/'), ...
    fullfile(mipoutdir, 'view11/'), ...
    fullfile(mipoutdir, 'view12/'),...
    fullfile(mipoutdir, 'view21/'),...
    fullfile(mipoutdir, 'view22/')} ;
for i = 1:length(mipdirs)
    if ~exist(mipdirs{i},'dir')
        mkdir(mipdirs{i})
    end
end

for time = timePoints
    disp(['Considering time=' num2str(time)])
    fileName = sprintf(filenameFormat, time);
    fullFileName = fullfile(dataDir, fileName);
    
    if exist(fullFileName, 'file')
        disp([ 'reading ' fullFileName]) 
        % data = readSingleTiff(fullFileName);
        data = bfopen(fullFileName) ;
        tmp = data{1} ;
        dstack = zeros([size(tmp{1}), length(data{1})]) ;
        for i = 1:length(data{1})
            dstack(:, :, i) = tmp{i};  
        end
        
        % Convert to grayscale at 16 bit depth
        im2 = mat2gray(dstack,[0 max(dstack(:))]);
        im2 = uint16(2^16*im2);
        imSize = size(im2);

        % Creat MIPs (maximum intensity projections)
        disp(['creating mips for timepoint=' num2str(time)])
        disp(fullFileName)
        mip_1 = max(im2(:,:,1:round(imSize(end)/2)),[],3);
        mip_2 = max(im2(:,:,round(imSize(end)/2):end),[],3);
        mip_11 = squeeze(max(im2(1:round(imSize(1)/2),:,:),[],1));
        mip_21 = squeeze(max(im2(round(imSize(1)/2):end,:,:),[],1));
        mip_12 = squeeze(max(im2(:,1:round(imSize(2)/2),:),[],2));
        mip_22 = squeeze(max(im2(:,round(imSize(2)/2):end,:),[],2));

        imwrite(mip_1, fullfile(mipoutdir, sprintf('view1/mip_1_%03d_c1.tif',  time-t_off)),'tiff','Compression','none');
        imwrite(mip_2, fullfile(mipoutdir, sprintf('view2/mip_2_%03d_c1.tif',  time-t_off)),'tiff','Compression','none');
        imwrite(mip_11,fullfile(mipoutdir, sprintf('view11/mip_11_%03d_c1.tif',time-t_off)),'tiff','Compression','none');
        imwrite(mip_21,fullfile(mipoutdir, sprintf('view21/mip_21_%03d_c1.tif',time-t_off)),'tiff','Compression','none');
        imwrite(mip_12,fullfile(mipoutdir, sprintf('view12/mip_12_%03d_c1.tif',time-t_off)),'tiff','Compression','none');
        imwrite(mip_22,fullfile(mipoutdir, sprintf('view22/mip_22_%03d_c1.tif',time-t_off)),'tiff','Compression','none');
    else
        disp(['WARNING: file does not exist, skipping: ', fullFileName])
    end
end
disp('done')