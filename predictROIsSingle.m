function [positions, n] = predictROIsSingle(image, crop, crop_id, model, model_shape, probability_threshold)
            
            num_crops = 2;
            
            image_array = zeros([model_shape, num_crops]);
            % we generate an almost empty image as a placeholder in
            % image_array. This ensures the existence of a 4th dimension
            % even if one rectangle was drawn. 
            image_array(:,:,:,1) = zeros(model_shape, 'uint8');
            crop_shape = size(crop);
            % Our model takes in images with shape [height, width, 3]
            if numel(crop_shape) == 3 % there are colour channels
                % No pre-processing for RGB images
                image_array(:,:,:,2) = crop;
            elseif numel(crop_shape) == 2 % no colour channel
                % grey images need to be expanded into rgb for model
                % predictions
                RGB = cat(3, crop, crop, crop);
                image_array(:,:,:,2) = RGB;
            end
            

            % Batch predict
            binary_masks = batchpredict(image_array, model, probability_threshold); % last arg - regression map threshold
            
            % Now resize to get original image
            shape = size(image);
            mask = false(shape);
            for i=2:num_crops
                cropped = binary_masks(:,:,i);
                cropped = uint8(imclearborder(cropped));
                mask = logical(mask) | logical(restore(cropped, crop_id, shape));  
            end
            
            
            % Post-processing
            % Thresholding
            segmented_img = bsxfun(@times, image, cast(mask, class(image)));
            mask = im2uint8(segmented_img) > 20; % set global threshold
            
            % Post-processing & generate ROI coordinates
            [positions, n] = processmask(mask);
    end