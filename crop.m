function [cropped, ID] = crop(image, position, target_shape)
    % 
    % 
    % Get xref, yref for "imcrop" (refer to documentation)
    x_max = round(max(position(:,1)));
    x_min = 1 + round(min(position(:,1)));
    save('pos.mat', 'position');
    
    y_max = round(max(position(:,2)));
    y_min = 1 + round(min(position(:,2)));
    
    % If rounding exceeds the image size, round down to the image dimension
    if y_max > size(image, 1)
        y_max = size(image, 1);
    end
    if x_max > size(image, 2)
        x_max = size(image, 2);
    end
    
    width = x_max - x_min;
    height = y_max - y_min;
    
    cropped = image(y_min:y_max, x_min:x_max);
    cropped = imresize(cropped, [target_shape(1),target_shape(2)], 'bilinear');
    
    
    ID = {[width, height], [x_min, x_max], [y_min, y_max]};
    
   
end