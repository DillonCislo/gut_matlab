function writeTiff5D(im, name_out)
% Write a TIFF file to disk with order XYCZT
% 
% Parameters
% ----------
% im : (nX x nY x nC x nS x nT) 16-bit array 
% name_out : str
%   full path of output TIFF filename
%
% Returns
% -------
% none
%
% To Do
% -----
% allow for 8bit or other bit depth by changing max in fiji_descr
%
%
% NPMitchell 2020, adapted from https://www.mathworks.com/matlabcentral/answers/389765-how-can-i-save-an-image-with-four-channels-or-more-into-an-imagej-compatible-tiff-format#answer_438003

        fiji_descr = ['ImageJ=1.52p' newline ...
                'images=' num2str(size(im,3)*...
                                  size(im,4)*...
                                  size(im,5)) newline... 
                'channels=' num2str(size(im,3)) newline...
                'slices=' num2str(size(im,4)) newline...
                'frames=' num2str(size(im,5)) newline... 
                'hyperstack=true' newline...
                'mode=grayscale' newline...  
                'loop=false' newline...  
                'min=0.0' newline...      
                'max=65535.0'];  % change this to 256 if you use an 8bit image

        t = Tiff(name_out,'w') ;
        tagstruct.ImageLength = size(im,1);
        tagstruct.ImageWidth = size(im,2);
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 16;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.Compression = Tiff.Compression.LZW;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tagstruct.SampleFormat = Tiff.SampleFormat.UInt;
        tagstruct.ImageDescription = fiji_descr;
        for frame = 1:size(im,5)
            for slice = 1:size(im,4)
                for channel = 1:size(im,3)
                    % disp(['FSC = ', num2str(frame), '/', num2str(slice), '/', num2str(channel)])
                    t.setTag(tagstruct)
                    t.write(im(:,:,channel,slice,frame));
                    t.writeDirectory(); % saves a new page in the tiff file
                end
            end
        end
        t.close() 