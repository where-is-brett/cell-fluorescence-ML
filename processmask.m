function [positions, n] = processmask(mask)

    % Post Processing
    % the input masks should be a 4D array of binary masks after
    % probability thresholding
    
    % Clear border elements:
    % We do so because we wish to avoid delineating incomplete objects (due to ROI window selection)
    
    save('/Users/zeyiyang/MATLAB-Drive/Labeller/mask.mat','mask');
    
%     % DEPRECATED - implemented in "bwboundaries": Get connectedd components:
%     mask = imfill(mask, 'holes');
%     imshow(mask)
    
    % Remove small features:
    % Set pixel number limit
    small_feature = 50; % any feature < this no. of pxls deemed small
    mask = bwareaopen(mask, small_feature);
    
    % Draw boundaries on single masks
    [positions,~,n,~] = bwboundaries(mask,'noholes');
    
    % Process coordinates for ROI handles
    for i=1:numel(positions)
        % The output (x,y) coordinates are fliped relative to the labeller's interpretation 
        positions{i} = flip(positions{i},2);
    end
    
end