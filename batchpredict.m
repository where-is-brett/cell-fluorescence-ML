function binary_masks = batchpredict(image_array, model, threshold)
    %%%%%%%%%%
    % This functions take in an image array [height, width, channels,
    % number of images], a preloaded Keras model and a prediction threshold
    % and returns a binary image array containing the predicted outcomes
    %%%%%%%%%%
    % Predict Using Imported Keras Model
    predictions = predict(model, image_array); % Here we're batch predicting 1000+ images
    
    shape = size(predictions);
    predictions = predictions>threshold;
    binary_masks = zeros(shape(1), shape(2), shape(end));
    for i=1:shape(end)
        binary_masks(:,:,i) = predictions(:,:,1,i);
    end
    
    
    
end