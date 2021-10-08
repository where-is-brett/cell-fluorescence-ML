function mask = restore(cropped, ID, target_shape)
    
    mask = zeros([target_shape(1),target_shape(2)]);
    
    % Get xref, yref for "imcrop" (refer to documentation)
    width = ID{1}(1);
    height = ID{1}(2);
    
    x_min = ID{2}(1);
    x_max = ID{2}(2);
    
    y_min = ID{3}(1);
    y_max = ID{3}(2);
    
    
    
    segment = imresize(cropped, [height+1, width+1], 'bilinear');
    
    mask(y_min:y_max, x_min:x_max) = segment;

end