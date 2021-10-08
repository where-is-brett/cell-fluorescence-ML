classdef LabellerDistributionFull_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        FileMenu                    matlab.ui.container.Menu
        OpenMenu                    matlab.ui.container.Menu
        ImageMenu                   matlab.ui.container.Menu
        SaveMenu                    matlab.ui.container.Menu
        SaveCellROIsMenu            matlab.ui.container.Menu
        SaveBackgroundROIsMenu      matlab.ui.container.Menu
        SaveCellAsMenu              matlab.ui.container.Menu
        BinaryMaskMenu              matlab.ui.container.Menu
        InstanceMaskMenu            matlab.ui.container.Menu
        SaveBackgroundAsMenu        matlab.ui.container.Menu
        BinaryMaskMenu_2            matlab.ui.container.Menu
        InstanceMaskMenu_2          matlab.ui.container.Menu
        LoadMenu                    matlab.ui.container.Menu
        CellROIsMenu                matlab.ui.container.Menu
        BackgroundROIsMenu          matlab.ui.container.Menu
        EditMenu                    matlab.ui.container.Menu
        ResetMenu                   matlab.ui.container.Menu
        MeasureMenu                 matlab.ui.container.Menu
        CTCFMenu                    matlab.ui.container.Menu
        HelpMenu                    matlab.ui.container.Menu
        DemonstrationMenu           matlab.ui.container.Menu
        ContactMenu                 matlab.ui.container.Menu
        DeepLearningModulePanel     matlab.ui.container.Panel
        ThresholdKnobLabel          matlab.ui.control.Label
        ThresholdKnob               matlab.ui.control.Knob
        ModelDropDownLabel          matlab.ui.control.Label
        ModelDropDown               matlab.ui.control.DropDown
        DrawBoundingBoxButton       matlab.ui.control.StateButton
        LoadModelButton             matlab.ui.control.Button
        LabelSelectionButtonGroup   matlab.ui.container.ButtonGroup
        LabelVisibilitySwitchLabel  matlab.ui.control.Label
        LabelVisibilitySwitch       matlab.ui.control.Switch
        BackgroundButton            matlab.ui.control.ToggleButton
        CellButton                  matlab.ui.control.ToggleButton
        FreehandButton              matlab.ui.control.StateButton
        CircleButton                matlab.ui.control.StateButton
        PolygonButton               matlab.ui.control.StateButton
        v011Label                   matlab.ui.control.Label
        BrettYangLabel_2            matlab.ui.control.Label
        ImageAxes                   matlab.ui.control.UIAxes
    end


    properties (Access = public)
        image = ones(256,256);   % image to work on, obj.image = theImageToWorkOn
        masks = {{}, {}}; % list of all masks

    end

    properties(Access=private)

        % UI stuff
        imag    % image to work on

        % Store
        BinaryMasks
        ROIs
        BoundingBoxes

        % load/save information
        pathname
        c_filename = 'Cell'
        b_filename = 'Background'
        % Colour
        ROIColourCell
        ROIColourBackground
        ROIColourSelected
        BoundingBoxColour

        % Label/Sequence identifiers
        current
        ID

        % Buttons
        DrawButtons

        % DCNN model
        model
        model_shape
        probabilityThreshold = 0.5
    end





    methods (Access=public)

        % Public method to retrieve ROI data
        function [masks, binarymask, numberofrois] = getROIData(app,varargin)
            masks = app.masks;
            binarymask = false(size(masks{1}));
            for i=1:numel(masks)
                % Write binary mask
                binarymask = binarymask | masks{i};
            end
            numberofrois = numel(masks);
        end

    end


    %% private methods
    methods(Access=private)

        % Function to compute CTCF from region masks
        function [means, areas, IntDens,CTCFs] = measure(app)
            % Delcarte arrays (or whatever name it has) to store numberical data
            means = zeros(1,numel(app.ROIs{1}));
            IntDens = zeros(1,numel(app.ROIs{1}));
            areas = zeros(1,numel(app.ROIs{1}));
            for i=1:2*numel(app.ROIs{1})
                % create region segments


                %roi_data = double(GreyImage(mask));
                % Distinguish between foreground and background by checking whether
                % the index is even or not.
                % We calculate IntDen and cell area for foreground objects
                if rem(i,2) % ODD
                    odd_index = 1 + (i-1)/2; % Convert index back to natural number sequence
                    mask = createMask(app.ROIs{1}{odd_index}, app.image);
                    roi_data = uint8(app.image(mask));

                    IntDen_of_roi_i = sum(roi_data);
                    area_of_roi_i = numel(roi_data);
                    % Store data to array
                    IntDens(odd_index) = IntDen_of_roi_i;
                    areas(odd_index) = area_of_roi_i;
                    % Otherwise for background noise we take the mean value
                else % EVEN

                    even_index = i/2; % Convert index back to natural number sequence
                    mask = createMask(app.ROIs{2}{even_index}, app.image);
                    roi_data = uint8(app.image(mask));
                    mean_of_roi_i = mean(roi_data);
                    % Store data to array
                    means(even_index) = mean_of_roi_i;
                end
            end
            % We calculate CTCF according to the following equation:
            % CTCF = Integrated Density – (Area of selected cell * Mean background)
            % in the context of array operations this translate to:
            CTCFs = IntDens - (areas.*means);
        end

        % Function to label and add listener to any 'shape' (ROI) when the
        % shape.Tag property is known
        function shapeCreated(app, numtag)

            %%%% Set properties
            set(app.ROIs{app.current}{numtag}, 'Tag', string(numtag)); % Set tag
            % Set label and colour
            if app.current==1 % cell
                set(app.ROIs{app.current}{numtag}, 'Label', sprintf('Cell %d', numtag));
                set(app.ROIs{app.current}{numtag}, 'Color', app.ROIColourCell);
            elseif app.current==2 % background
                set(app.ROIs{app.current}{numtag}, 'Label', sprintf('Background %d', numtag));
                set(app.ROIs{app.current}{numtag}, 'Color', app.ROIColourBackground);
            end
            set(app.ROIs{app.current}{numtag}, 'LabelAlpha', 0.7);
            % Set label visibility
            switch(app.LabelVisibilitySwitch.Value)
                case{'Hover'}
                    set(app.ROIs{app.current}{numtag}, 'LabelVisible', 'hover');
                otherwise
                    set(app.ROIs{app.current}{numtag}, 'LabelVisible', 'on');
            end
            set(app.ROIs{app.current}{numtag}, 'FaceAlpha', 0.1); % Set opacity
            %%%% POST CREATION LISTENERS
            addlistener(app.ROIs{app.current}{numtag}, 'ROIMoved', @app.allevents);
            addlistener(app.ROIs{app.current}{numtag}, 'DeletingROI', @app.allevents);
            addlistener(app.ROIs{app.current}{numtag}, 'ROIClicked', @app.allevents);
            if isa(app.ROIs{app.current}{numtag},'Freehand')
                addlistener(app.ROIs{app.current}{numtag}, 'WaypointAdded', @app.allevents);
                addlistener(app.ROIs{app.current}{numtag}, 'WaypointRemoved', @app.allevents);
            elseif isa(app.ROIs{app.current}{numtag},'Polygon')
                addlistener(app.ROIs{app.current}{numtag}, 'VertexAdded', @app.allevents);
                addlistener(app.ROIs{app.current}{numtag}, 'VertexRemoved', @app.allevents);
            end

        end

        % Function to label and add listener to each new ROI
        function newShapeCreated(app)
            set(app.ROIs{app.current}{end}, 'Tag', num2str(numel(app.ROIs{app.current}))); % Set tag
            numtag = str2double(app.ROIs{app.current}{end}.Tag); % convert to double for convenience
            shapeCreated(app, numtag);  % Call shapeCreated
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%% Event Handles %%%%%%%%%%%%%%%%%%%%%%%%%

        % Function handle for all events
        function allevents(app,src,evt)
            evname = evt.EventName;
            switch(evname)
                case{'DrawingStarted'}
                    % No two buttons can occupy the same state
                    %                     set(app.DrawButtons, 'Enable', 'off');
                case{'DrawingFinished'}
                    % Renable draing tools
                    %                     set(app.DrawButtons, 'Enable', 'on');
                case{'ROIMoved'}
                    %app.updateROI;
                case{'DeletingROI'}
                    % Get meta data from source
                    tag = str2double(src.Tag);
                    srcType = split(src.Label, ' ');
                    srcType = srcType{1};
                    if strcmp(srcType, 'Cell')
                        curr = 1;
                    else
                        curr = 2;
                    end
                    % Rest labels and tags for subsequent ROIs
                    for i=tag+1:numel(app.ROIs{curr})
                        set(app.ROIs{curr}{i}, 'Tag', string(i-1));
                        set(app.ROIs{curr}{i}, 'Label', sprintf('%s %d', srcType, i-1));
                    end
                    % Delete data linked to the user-deleted ROI
                    app.ROIs{curr}(tag) = []; % delete ROI data
                    %app.updateROI; % Update ROI preview

                case{'ROIClicked'}
                    %                     % Deleted previously selected data
                    %                     set(app.ROIs{1}, 'Selected', false);
                    %                     set(app.ROIs{2}, 'Selected', false);
                    %                     % Assigne new selection upon click
                    %                     src.Selected = true;
                    % Specific cases
                case{'WaypointAdded','VertexAdded'}
                    %app.updateROI;
                case{'WaypointRemoved', 'VertexRemoved'}
                    if numel(src.Position)==0
                        % if there was only one point

                    end
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%% CALLBACK FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%

        function closefig(app,h,e) % Close figure
            delete(app);
        end


        %%%%% Button helpers
        function DrawROI(app, Toggle, Object)
            % No two buttons can occupy the same state
            set(app.DrawButtons, 'Enable', 'off');
            set(app.LabelSelectionButtonGroup, 'Enable', 'off');

            app.ROIs{app.current}{end+1} = Object;
            %             % Before commencing, add listener to monitor drawing
            %             addlistener(app.ROIs{app.current}{end},'DrawingStarted',@allevents);
            %             addlistener(app.ROIs{app.current}{end},'DrawingFinished',@allevents);
            set(app.ROIs{app.current}{end}, 'LineWidth', 1);
            % Draw
            draw(app.ROIs{app.current}{end});
            % Reset current toggle state
            Toggle.Value = 0;
            if isempty(app.ROIs{app.current}{end}.Position)
                % If the ROI Position is empty then the drawing was either
                % cancelled by user or invalid. Delete the ROI.
                delete(app.ROIs{app.current}{end});
            else
                app.newShapeCreated; % add tag, and callback to new shape
            end
            % No two buttons can occupy the same state
            set(app.DrawButtons, 'Enable', 'on');
            set(app.LabelSelectionButtonGroup, 'Enable', 'on');
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)

            disableDefaultInteractivity(app.ImageAxes);

            % predefine class variables
            app.ROIs = {{},{}};
            app.BoundingBoxes = {};
            app.pathname = pwd;      % current directory
            app.ROIColourCell = [144 238 144]./256;
            app.ROIColourBackground = [32 178 170]./256;
            app.ROIColourSelected = [0.8203, 0.1758, 0.1758];
            app.BoundingBoxColour = [0.4, 1, 1];
            app.current = 1; % Initialise button group with cell selected

            % Categorise buttons
            app.DrawButtons = [app.PolygonButton,app.CircleButton,app.FreehandButton];
            % Disable ROI buttons until an image is loaded
            set(app.DrawButtons, 'Enable', 'off');
            % Disable bounding box button until a model is loaded
            if isempty(app.model)
                set(app.DrawBoundingBoxButton, 'Enable', 'off');
            end

            app.ImageAxes.Colormap = gray(256);
            app.imag = imshow(app.image, 'Parent', app.ImageAxes);

            % Display image and stretch to fill axes
            %             I = imshow(app.image, 'Parent', app.ImageAxes, ...
            %                 'XData', [1 app.ImageAxes.Position(3)], ...
            %                 'YData', [1 app.ImageAxes.Position(4)]);
            %             % Remove tick labels
            %             app.ImageAxes.XAxis.TickLabels = {};
            %             app.ImageAxes.YAxis.TickLabels = {};
            %             % Set limits of axes
            %             app.ImageAxes.XLim = [0 I.XData(2)];
            %             app.ImageAxes.YLim = [0 I.YData(2)];

        end

        % Value changed function: FreehandButton
        function FreehandButtonValueChanged(app, event)

            app.DrawROI(app.FreehandButton, images.roi.Freehand(app.ImageAxes));

        end

        % Value changed function: CircleButton
        function CircleButtonValueChanged(app, event)

            app.DrawROI(app.CircleButton, images.roi.Circle(app.ImageAxes));

        end

        % Value changed function: PolygonButton
        function PolygonButtonValueChanged(app, event)

            app.DrawROI(app.PolygonButton, images.roi.Polygon(app.ImageAxes));

        end

        % Value changed function: LabelVisibilitySwitch
        function LabelVisibilitySwitchValueChanged(app, event)
            value = app.LabelVisibilitySwitch.Value;
            if strcmp(value,'Always')
                for i=1:numel(app.ROIs)
                    for j=1:numel(app.ROIs{i})
                        if isvalid(app.ROIs{i}{j})
                            set(app.ROIs{i}{j}, 'LabelVisible', 'on');
                        end
                    end
                end
            else
                for i=1:numel(app.ROIs)
                    for j=1:numel(app.ROIs{i})
                        if isvalid(app.ROIs{i}{j})
                            set(app.ROIs{i}{j}, 'LabelVisible', 'hover');
                        end
                    end
                end
            end

        end

        % Value changed function: DrawBoundingBoxButton
        function DrawBoundingBoxButtonValueChanged(app, event)

            % No two buttons can occupy the same state
            set(app.DrawButtons, 'Enable', 'off');
            set(app.LabelSelectionButtonGroup, 'Enable', 'off');


            % Draw bounding boxes
            app.BoundingBoxes{end+1} = images.roi.Rectangle(app.ImageAxes);
            app.BoundingBoxes{end}.FixedAspectRatio = true; % set aspect ratio
            app.BoundingBoxes{end}.DrawingArea = [1, 1, size(app.image,2)-1, size(app.image,1)-1];
            draw(app.BoundingBoxes{end});



            % Check bounding box integrity
            if isempty(app.BoundingBoxes{end}.Position)
                % If the ROI Position is empty then the drawing was either
                % cancelled by user or invalid. Delete the ROI.
                delete(app.BoundingBoxes{end});
            else
                numtag = 1;
                %%%% Set properties
                set(app.BoundingBoxes{numtag}, 'Tag', string(numtag)); % Set tag
                % Set label and colour
                set(app.BoundingBoxes{numtag}, 'Label', sprintf('Bounding box %d', numtag));
                %                 set(app.BoundingBoxes{numtag}, 'Color', app.BoundingBoxColour);
                %                 set(app.BoundingBoxes{numtag}, 'LabelVisible', 'hover') % Set label visibility
                %                 set(app.BoundingBoxes{numtag}, 'FaceAlpha', 0.1); % Set opacity
                %                 %%%% POST CREATION LISTENERS
                %                 addlistener(app.BoundingBoxes{numtag}, 'ROIMoved', @app.allevents);
                %                 addlistener(app.BoundingBoxes{numtag}, 'DeletingROI', @app.allevents);
                %                 addlistener(app.BoundingBoxes{numtag}, 'ROIClicked', @app.allevents);
            end


            % Reset current toggle state
            app.DrawBoundingBoxButton.Value = 0;

            %%%%% Model Prediction

            position = app.BoundingBoxes{end}.Vertices;
            [cropped, crop_ids] = crop(app.image, position, app.model_shape);
            [positions, ~] = predictROIsSingle(app.image, cropped, crop_ids, app.model, app.model_shape, app.probabilityThreshold);

            % Draw ROIs
            tag = numel(app.ROIs{1});
            for i=1:numel(positions)
                roiCoordinates = positions{i};
                app.ROIs{1}{tag+i} = drawfreehand(app.ImageAxes, 'Position', roiCoordinates, 'LineWidth', 1);
                app.newShapeCreated;
            end

            %%%%%

            % Finish up
            % Delete bounding boxes
            for i=1:numel(app.BoundingBoxes)
                delete(app.BoundingBoxes{i});
            end
            app.BoundingBoxes = {};
            % Enbale ROI buttons
            set(app.DrawButtons, 'Enable', 'on');
            set(app.LabelSelectionButtonGroup, 'Enable', 'on');
            set(app.DrawBoundingBoxButton, 'Enable', 'on');
        end

        % Button pushed function: LoadModelButton
        function LoadModelButtonPushed(app, event)
            % Disable load model button untill model is ready
            set(app.DeepLearningModulePanel.Children, 'Enable', 'off');

            % Confirm dialog in case user clicked 'Load model' by mistake
            if ~isempty(app.model)
                selection = uiconfirm(app.UIFigure, 'Are you sure you want to load a different model?', 'Load model', 'Options', {'Yes','No'},...
                    'DefaultOption',2);
                if strcmp(selection, 'No')
                    % Re-enable load model button
                    set(app.DeepLearningModulePanel.Children, 'Enable', 'on');
                    % Enable bounding box button if currently selecting cells
                    if strcmp(app.LabelSelectionButtonGroup.SelectedObject.Text,'Cell')
                        set(app.DrawBoundingBoxButton, 'Enable', 'on');
                    end
                    return
                end
            end

            %             %%%%%%%%%%%%%% File exchange distributino only
            %             set(app.UIFigure, 'Visible', 'off');
            %             % Display uigetfile dialog
            %             filterspec = {'*.h5;*.hdf5;','Keras HDF5 file'};
            %             [f, p] = uigetfile(filterspec, 'Select Image for CTCF Measurements');
            %             modelfile = [p f];
            %             app.model_shape = [96,96,3];
            %             set(app.UIFigure, 'Visible', 'on');
            %             %%%%%%%%%%%%%%

            app.model_shape = [96,96,3];
            set(app.UIFigure, 'Visible', 'off');
            dialog = msgbox('Loading model... Please wait.', 'Load Model', 'modal');
            % Load model
            lgraph = importKerasLayers('model-96.h5','ImportWeights',true);
            lgraph.Layers
            rgLayer = lgraph.Layers(end);
            % Now specify the classes. In the case of nuclei segmentation, the two classes
            % are 'foreground' and 'background', here assigned the value of 1 and 0, respectively.
            rgLayer.ResponseNames = {'background','foreground'};
            % Assemble Network
            app.model = assembleNetwork(lgraph);
            delete(dialog);

            set(app.UIFigure, 'Visible', 'on');

            % Re-enable load model button
            set(app.DeepLearningModulePanel.Children, 'Enable', 'on');
            % Enable bounding box button if currently selecting cells
            if strcmp(app.LabelSelectionButtonGroup.SelectedObject.Text,'Cell')
                set(app.DrawBoundingBoxButton, 'Enable', 'on');
            end
        end

        % Selection changed function: LabelSelectionButtonGroup
        function LabelSelectionButtonGroupSelectionChanged(app, event)
            selectedButton = app.LabelSelectionButtonGroup.SelectedObject.Text;

            % Benefit of mutually exclusiveness of states
            % every time there is a change of event, then...
            if strcmp(selectedButton, 'Cell')
                app.current = 1;
                if ~isempty(app.model_shape)
                    % DCNN only works for cellular objects
                    % Enable if the model has been initiated
                    set(app.DrawBoundingBoxButton, 'Enable', 'on');
                end
                %set(app.LoadModelButton, 'Enable', 'on');
            else
                app.current = 2;
                set(app.DrawBoundingBoxButton, 'Enable', 'off');
                %set(app.LoadModelButton, 'Enable', 'off');
            end
        end

        % Menu selected function: ResetMenu
        function ResetMenuSelected(app, event)
            app.startupFcn;
            if size(app.image)
                set(app.DrawButtons, 'Enable', 'on');
            end
            %             app.BinaryMasks = {{},{}};
            %             app.ROIs = {{},{}};
            %             app.BoundingBoxes = {};

        end

        % Menu selected function: DemonstrationMenu
        function DemonstrationMenuSelected(app, event)
            URL = 'https://brettyang.info/neuroscience/computation/2021/08/21/CTCF-ML/';
            web(URL);
        end

        % Menu selected function: ContactMenu
        function ContactMenuSelected(app, event)
            URL = 'https://brettyang.info/contact';
            web(URL);
        end

        % Menu selected function: ImageMenu
        function ImageMenuSelected(app, event)
            set(app.UIFigure, 'Visible', 'off');
            % Display uigetfile dialog
            filterspec = {'*.jpg;*.tif;*.png;*.gif','All Image Files'};
            [f, p] = uigetfile(filterspec, 'Select Image for CTCF Measurements');
            set(app.UIFigure, 'Visible', 'on');
            % Make sure user didn't cancel uigetfile dialog
            if (ischar(p))
                fname = [p f];
                app.image = imread(fname);
                if numel(size(app.image)) == 3
                    msg = 'Only greyscale images are currently supported. Please select a colour channel.';
                    title = 'Confirm Image Channel';
                    selection = uiconfirm(app.UIFigure, msg, title, ...
                        'Options', {'Red','Green', 'Blue','Cancel'}, ...
                        'DefaultOption',2);
                    switch(selection)
                        case{'Red'}
                            app.image = app.image(:,:,1);
                        case{'Green'}
                            app.image = app.image(:,:,2);
                        case{'Blue'}
                            app.image = app.image(:,:,3);
                        otherwise
                            return
                    end
                end
            else
                return
            end

            % Reset
            app.startupFcn;
            set(app.DrawButtons, 'Enable', 'on');
            set(app.UIFigure, 'Visible', 'on');
        end

        % Menu selected function: SaveCellROIsMenu
        function SaveCellROIsMenuSelected(app, event)

            % save ROIs to File
            try
                [app.c_filename, app.pathname] = uiputfile('*.ROI','Save foreground ROIs as',app.c_filename);
                rois = app.ROIs{1};
                save([app.pathname, app.c_filename],'rois','-mat');
                uialert(app.UIFigure, 'Background ROIs saved!', '', 'Icon', 'success');
            catch
                % aborted
            end

        end

        % Menu selected function: BinaryMaskMenu
        function BinaryMaskMenuSelected(app, event)
            binarymask = false(size(app.image));
            for i=1:numel(app.ROIs{1})
                mask = createMask(app.ROIs{1}{i}, app.image);
                % Write binary mask
                binarymask = binarymask | mask;
            end
            % Ask user to choose file dir and name
            filter = {'*.tif;*.png;','All Image Files'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                uialert(app.UIFigure, 'Operation cancelled.', 'Cancelled', "Icon", 'warning');
                return
            end
            fname = fullfile(path, file);
            % write mask to file
            imwrite(im2uint8(binarymask), fname);
            uialert('Binary mask (cell) saved!', 'Icon', 'success');
        end

        % Menu selected function: InstanceMaskMenu
        function InstanceMaskMenuSelected(app, event)
            instancemask = zeros(size(app.image));
            for i=1:numel(app.ROIs{1})
                mask = uint8(createMask(app.ROIs{1}{i}, app.image));
                instancemask = uint8(instancemask) + (uint8(mask)*i);
                instancemask(instancemask>i) = i;
            end
            % Ask user to choose file dir and name
            filter = {'*.tif;*.png;','All Image Files'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                uialert(app.UIFigure, 'Operation cancelled.', 'Cancelled', "Icon", 'warning');
                return
            end
            fname = fullfile(path, file);
            % write mask to file
            imwrite(instancemask, fname);
            uialert(app.UIFigure, 'Instance mask (cell) saved!', '', 'Icon', 'success');
        end

        % Menu selected function: SaveBackgroundROIsMenu
        function SaveBackgroundROIsMenuSelected(app, event)
            % save ROIs to File
            try
                [app.b_filename, app.pathname] = uiputfile('*.ROI','Save background ROIs as', app.b_filename);
                rois = app.ROIs{2};
                save([app.pathname, app.b_filename],'rois','-mat');
                uialert(app.UIFigure, 'Background ROIs saved!', '', 'Icon', 'success');
            catch
                % aborted
            end
        end

        % Menu selected function: BinaryMaskMenu_2
        function BinaryMaskMenu_2Selected(app, event)
            binarymask = false(size(app.image));
            for i=1:numel(app.ROIs{2})
                mask = createMask(app.ROIs{2}{i}, app.image);
                % Write binary mask
                binarymask = binarymask | mask;
            end
            % Ask user to choose file dir and name
            filter = {'*.tif;*.png;','All Image Files'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                uialert(app.UIFigure, 'Operation cancelled.', 'Cancelled', "Icon", 'warning');
                return
            end
            fname = fullfile(path, file);
            % write mask to file
            imwrite(im2uint8(binarymask), fname);
            uialert(app.UIFigure, 'Binary mask (background) saved!', '', 'Icon', 'success');
        end

        % Menu selected function: InstanceMaskMenu_2
        function InstanceMaskMenu_2Selected(app, event)
            instancemask = zeros(size(app.image));
            for i=1:numel(app.ROIs{2})
                mask = uint8(createMask(app.ROIs{2}{i}, app.image));
                instancemask = uint8(instancemask) + (uint8(mask)*i);
                instancemask(instancemask>i) = i;
            end
            % Ask user to choose file dir and name
            filter = {'*.tif;*.png;','All Image Files'};
            [file, path] = uiputfile(filter);
            if ~file % User clicked the Cancel button.
                uialert(app.UIFigure, 'Operation cancelled.', 'Cancelled', "Icon", 'warning');
                return
            end
            fname = fullfile(path, file);
            % write mask to file
            imwrite(instancemask, fname);
            uialert(app.UIFigure, 'Instance mask (background) saved!', '', 'Icon', 'success');
        end

        % Menu selected function: CellROIsMenu
        function CellROIsMenuSelected(app, event)

            % Reset ROIs?
            fig = app.UIFigure;
            if ~isempty(app.ROIs{1})
                msg = 'Delete current ROIs before loading?';
                title = 'Confirm';
                selection = uiconfirm(fig,msg,title,...
                    'Options',{'Delete','Keep Exisitng ROIs','Cancel'},...
                    'DefaultOption',2,'CancelOption',3);
                if strcmp(selection, 'Delete')
                    app.startupFcn; % delete whatever is on the screen
                    if size(app.image)
                        set(app.DrawButtons, 'Enable', 'on');
                    end
                end
            end
            % Load ROIs
            [filename, app.pathname,~] = uigetfile('*.ROI');
            try
                b = load([app.pathname, filename],'-mat');
                rois = b.rois;
                for i=1:numel(rois)
                    roiType = class(rois{i});

                    % Draw new ROI of different types, according to given coordinates
                    switch(roiType)
                        case{'images.roi.Polygon'}
                            roiCoordinates = rois{i}.Position;
                            app.ROIs{1}{end+1} = drawpolygon(app.ImageAxes, 'Position',roiCoordinates, 'LineWidth', 1);
                        case{'images.roi.Circle'}
                            centre = rois{i}.Center;
                            radius = rois{i}.Radius;
                            app.ROIs{1}{end+1} = drawcircle(app.ImageAxes, 'Center', centre, 'Radius', radius, 'LineWidth', 1);
                        case{'images.roi.Freehand'}
                            roiCoordinates = rois{i}.Position;
                            app.ROIs{1}{end+1} = drawfreehand(app.ImageAxes, 'Position',roiCoordinates, 'LineWidth', 1);
                    end
                    % follow up using pre-defined method 'newShapeCreated'
                    if strcmp(app.LabelSelectionButtonGroup.SelectedObject.Text, 'Cell')
                        app.newShapeCreated;
                    else
                        app.current = 1;
                        app.newShapeCreated;
                        app.current = 2;
                    end
                end
                uialert(fig, sprintf('Successfully imported %d ROIs!',numel(rois)), 'Import Complete', 'Icon', 'success');
            catch
                % aborted
            end
        end

        % Menu selected function: BackgroundROIsMenu
        function BackgroundROIsMenuSelected(app, event)
            % Reset ROIs?
            fig = app.UIFigure;
            if ~isempty(app.ROIs{2})
                msg = 'Delete current ROIs before loading?';
                title = 'Confirm';
                selection = uiconfirm(fig,msg,title,...
                    'Options',{'Delete','Keep Exisitng ROIs','Cancel'},...
                    'DefaultOption',2,'CancelOption',3);
                if strcmp(selection, 'Delete')
                    app.startupFcn; % delete whatever is on the screen
                    if size(app.image)
                        set(app.DrawButtons, 'Enable', 'on');
                    end
                end
            end
            % load ROI objects from File
            [filename, app.pathname,~] = uigetfile('*.ROI');
            try
                b = load([app.pathname, filename],'-mat');
                rois = b.rois;
                for i=1:numel(rois)
                    roiType = class(rois{i});

                    % Draw new ROI of different types, according to given coordinates
                    switch(roiType)
                        case{'images.roi.Polygon'}
                            roiCoordinates = rois{i}.Position;
                            app.ROIs{2}{end+1} = drawpolygon(app.ImageAxes, 'Position',roiCoordinates, 'LineWidth', 1);
                        case{'images.roi.Circle'}
                            centre = rois{i}.Center;
                            radius = rois{i}.Radius;
                            app.ROIs{2}{end+1} = drawcircle(app.ImageAxes, 'Center', centre, 'Radius', radius, 'LineWidth', 1);
                        case{'images.roi.Freehand'}
                            roiCoordinates = rois{i}.Position;
                            app.ROIs{2}{end+1} = drawfreehand(app.ImageAxes, 'Position',roiCoordinates, 'LineWidth', 1);
                    end
                    % follow up using pre-defined method 'newShapeCreated'
                    if strcmp(app.LabelSelectionButtonGroup.SelectedObject.Text, 'Background')
                        app.newShapeCreated;
                    else
                        app.current = 2;
                        app.newShapeCreated;
                        app.current = 1;
                    end
                end
                uialert(fig, sprintf('Successfully imported %d ROIs!',numel(rois)), 'Import Complete', 'Icon', 'success');
            catch
                % aborted
            end
        end

        % Menu selected function: CTCFMenu
        function CTCFMenuSelected(app, event)
            % First check if there are equal numbers of cell and
            % background ROIs
            if numel(app.ROIs{1})==0 && numel(app.ROIs{2})==0
                uialert(app.UIFigure, 'Please define ROIs.', 'Warning', 'Icon', 'warning')
                return
            elseif numel(app.ROIs{1})~=numel(app.ROIs{2})
                uialert(app.UIFigure, 'Please ensure each cellular ROI has a corresponding background ROI and vice versa.', 'Warning', 'Icon', 'warning')
                return
            else
                [means, areas, IntDens, CTCFs] = app.measure;
                %% Display CTCF and Integrated Density
                T = table(transpose(means), transpose(IntDens./areas), transpose(areas), transpose(IntDens), ...
                    transpose(CTCFs), 'VariableNames', ...
                    {'Mean Background', 'Mean Foreground','Cellular Area','Integrated Density','CTCF'});
                fig = figure('NumberTitle','off', 'Name','Results');
                % Create UI table
                T = uitable(fig, 'Data',T{:,:},'ColumnName',T.Properties.VariableNames,...
                    'RowName',T.Properties.RowNames,'Units', 'Normalized', 'Position',[0, 0, 1, 1]);
                % Display table
                disp(T);
            end
        end

        % Value changed function: ThresholdKnob
        function ThresholdKnobValueChanged(app, event)
            value = app.ThresholdKnob.Value;
            app.probabilityThreshold = double(value)/100;
        end

        % Callback function
        function SegmentationModelMenuSelected(app, event)
            URL = 'https://github.com/where-is-brett/cell-fluorescence-ml/raw/main/model-96.h5';
            web(URL);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 783 612];
            app.UIFigure.Name = 'MATLAB App';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create OpenMenu
            app.OpenMenu = uimenu(app.FileMenu);
            app.OpenMenu.Text = 'Open...';

            % Create ImageMenu
            app.ImageMenu = uimenu(app.OpenMenu);
            app.ImageMenu.MenuSelectedFcn = createCallbackFcn(app, @ImageMenuSelected, true);
            app.ImageMenu.Text = 'Image';

            % Create SaveMenu
            app.SaveMenu = uimenu(app.FileMenu);
            app.SaveMenu.Text = 'Save';

            % Create SaveCellROIsMenu
            app.SaveCellROIsMenu = uimenu(app.SaveMenu);
            app.SaveCellROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveCellROIsMenuSelected, true);
            app.SaveCellROIsMenu.Text = 'Save Cell ROIs';

            % Create SaveBackgroundROIsMenu
            app.SaveBackgroundROIsMenu = uimenu(app.SaveMenu);
            app.SaveBackgroundROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveBackgroundROIsMenuSelected, true);
            app.SaveBackgroundROIsMenu.Text = 'Save Background ROIs';

            % Create SaveCellAsMenu
            app.SaveCellAsMenu = uimenu(app.SaveMenu);
            app.SaveCellAsMenu.Text = 'Save Cell As...';

            % Create BinaryMaskMenu
            app.BinaryMaskMenu = uimenu(app.SaveCellAsMenu);
            app.BinaryMaskMenu.MenuSelectedFcn = createCallbackFcn(app, @BinaryMaskMenuSelected, true);
            app.BinaryMaskMenu.Text = 'Binary Mask';

            % Create InstanceMaskMenu
            app.InstanceMaskMenu = uimenu(app.SaveCellAsMenu);
            app.InstanceMaskMenu.MenuSelectedFcn = createCallbackFcn(app, @InstanceMaskMenuSelected, true);
            app.InstanceMaskMenu.Text = 'Instance Mask';

            % Create SaveBackgroundAsMenu
            app.SaveBackgroundAsMenu = uimenu(app.SaveMenu);
            app.SaveBackgroundAsMenu.Text = 'Save Background As...';

            % Create BinaryMaskMenu_2
            app.BinaryMaskMenu_2 = uimenu(app.SaveBackgroundAsMenu);
            app.BinaryMaskMenu_2.MenuSelectedFcn = createCallbackFcn(app, @BinaryMaskMenu_2Selected, true);
            app.BinaryMaskMenu_2.Text = 'Binary Mask';

            % Create InstanceMaskMenu_2
            app.InstanceMaskMenu_2 = uimenu(app.SaveBackgroundAsMenu);
            app.InstanceMaskMenu_2.MenuSelectedFcn = createCallbackFcn(app, @InstanceMaskMenu_2Selected, true);
            app.InstanceMaskMenu_2.Text = 'Instance Mask';

            % Create LoadMenu
            app.LoadMenu = uimenu(app.FileMenu);
            app.LoadMenu.Text = 'Load...';

            % Create CellROIsMenu
            app.CellROIsMenu = uimenu(app.LoadMenu);
            app.CellROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @CellROIsMenuSelected, true);
            app.CellROIsMenu.Text = 'Cell ROIs';

            % Create BackgroundROIsMenu
            app.BackgroundROIsMenu = uimenu(app.LoadMenu);
            app.BackgroundROIsMenu.MenuSelectedFcn = createCallbackFcn(app, @BackgroundROIsMenuSelected, true);
            app.BackgroundROIsMenu.Text = 'Background ROIs';

            % Create EditMenu
            app.EditMenu = uimenu(app.UIFigure);
            app.EditMenu.Text = 'Edit';

            % Create ResetMenu
            app.ResetMenu = uimenu(app.EditMenu);
            app.ResetMenu.MenuSelectedFcn = createCallbackFcn(app, @ResetMenuSelected, true);
            app.ResetMenu.Text = 'Reset';

            % Create MeasureMenu
            app.MeasureMenu = uimenu(app.UIFigure);
            app.MeasureMenu.Text = 'Measure';

            % Create CTCFMenu
            app.CTCFMenu = uimenu(app.MeasureMenu);
            app.CTCFMenu.MenuSelectedFcn = createCallbackFcn(app, @CTCFMenuSelected, true);
            app.CTCFMenu.Text = 'CTCF';

            % Create HelpMenu
            app.HelpMenu = uimenu(app.UIFigure);
            app.HelpMenu.Text = 'Help';

            % Create DemonstrationMenu
            app.DemonstrationMenu = uimenu(app.HelpMenu);
            app.DemonstrationMenu.MenuSelectedFcn = createCallbackFcn(app, @DemonstrationMenuSelected, true);
            app.DemonstrationMenu.Text = 'Demonstration';

            % Create ContactMenu
            app.ContactMenu = uimenu(app.HelpMenu);
            app.ContactMenu.MenuSelectedFcn = createCallbackFcn(app, @ContactMenuSelected, true);
            app.ContactMenu.Text = 'Contact';

            % Create ImageAxes
            app.ImageAxes = uiaxes(app.UIFigure);
            app.ImageAxes.Toolbar.Visible = 'off';
            app.ImageAxes.FontName = 'Avenir';
            app.ImageAxes.XColor = 'none';
            app.ImageAxes.XTick = [];
            app.ImageAxes.XTickLabel = '';
            app.ImageAxes.YColor = 'none';
            app.ImageAxes.YTick = [];
            app.ImageAxes.ZColor = 'none';
            app.ImageAxes.GridColor = [0.15 0.15 0.15];
            app.ImageAxes.MinorGridColor = 'none';
            app.ImageAxes.Position = [246 1 538 529];

            % Create BrettYangLabel_2
            app.BrettYangLabel_2 = uilabel(app.UIFigure);
            app.BrettYangLabel_2.FontName = 'Avenir';
            app.BrettYangLabel_2.Position = [670 5 104 22];
            app.BrettYangLabel_2.Text = '© 2021 Brett Yang';

            % Create v011Label
            app.v011Label = uilabel(app.UIFigure);
            app.v011Label.HorizontalAlignment = 'center';
            app.v011Label.FontName = 'Avenir';
            app.v011Label.Position = [-6 5 76 22];
            app.v011Label.Text = 'v0.1.1';

            % Create PolygonButton
            app.PolygonButton = uibutton(app.UIFigure, 'state');
            app.PolygonButton.ValueChangedFcn = createCallbackFcn(app, @PolygonButtonValueChanged, true);
            app.PolygonButton.Text = 'Polygon';
            app.PolygonButton.FontName = 'Avenir';
            app.PolygonButton.Position = [251 551 110 31];

            % Create CircleButton
            app.CircleButton = uibutton(app.UIFigure, 'state');
            app.CircleButton.ValueChangedFcn = createCallbackFcn(app, @CircleButtonValueChanged, true);
            app.CircleButton.Text = 'Circle';
            app.CircleButton.FontName = 'Avenir';
            app.CircleButton.Position = [422 551 110 31];

            % Create FreehandButton
            app.FreehandButton = uibutton(app.UIFigure, 'state');
            app.FreehandButton.ValueChangedFcn = createCallbackFcn(app, @FreehandButtonValueChanged, true);
            app.FreehandButton.Text = 'Freehand';
            app.FreehandButton.FontName = 'Avenir';
            app.FreehandButton.Position = [594 551 110 31];

            % Create LabelSelectionButtonGroup
            app.LabelSelectionButtonGroup = uibuttongroup(app.UIFigure);
            app.LabelSelectionButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @LabelSelectionButtonGroupSelectionChanged, true);
            app.LabelSelectionButtonGroup.TitlePosition = 'centertop';
            app.LabelSelectionButtonGroup.Title = 'Label Selection';
            app.LabelSelectionButtonGroup.FontName = 'Avenir';
            app.LabelSelectionButtonGroup.Position = [37 80 159 169];

            % Create CellButton
            app.CellButton = uitogglebutton(app.LabelSelectionButtonGroup);
            app.CellButton.Text = 'Cell';
            app.CellButton.FontName = 'Avenir';
            app.CellButton.Position = [29 103 100 24];
            app.CellButton.Value = true;

            % Create BackgroundButton
            app.BackgroundButton = uitogglebutton(app.LabelSelectionButtonGroup);
            app.BackgroundButton.Text = 'Background';
            app.BackgroundButton.FontName = 'Avenir';
            app.BackgroundButton.Position = [29 82 100 24];

            % Create LabelVisibilitySwitch
            app.LabelVisibilitySwitch = uiswitch(app.LabelSelectionButtonGroup, 'slider');
            app.LabelVisibilitySwitch.Items = {'Hover', 'Always'};
            app.LabelVisibilitySwitch.ValueChangedFcn = createCallbackFcn(app, @LabelVisibilitySwitchValueChanged, true);
            app.LabelVisibilitySwitch.FontName = 'Avenir';
            app.LabelVisibilitySwitch.Position = [51 17 50 22];
            app.LabelVisibilitySwitch.Value = 'Hover';

            % Create LabelVisibilitySwitchLabel
            app.LabelVisibilitySwitchLabel = uilabel(app.LabelSelectionButtonGroup);
            app.LabelVisibilitySwitchLabel.HorizontalAlignment = 'center';
            app.LabelVisibilitySwitchLabel.FontName = 'Avenir';
            app.LabelVisibilitySwitchLabel.Position = [35 46 82 22];
            app.LabelVisibilitySwitchLabel.Text = 'Label Visibility';

            % Create DeepLearningModulePanel
            app.DeepLearningModulePanel = uipanel(app.UIFigure);
            app.DeepLearningModulePanel.TitlePosition = 'centertop';
            app.DeepLearningModulePanel.Title = 'Deep Learning Module';
            app.DeepLearningModulePanel.FontName = 'Avenir';
            app.DeepLearningModulePanel.Position = [38 284 159 298];

            % Create LoadModelButton
            app.LoadModelButton = uibutton(app.DeepLearningModulePanel, 'push');
            app.LoadModelButton.ButtonPushedFcn = createCallbackFcn(app, @LoadModelButtonPushed, true);
            app.LoadModelButton.FontName = 'Avenir';
            app.LoadModelButton.Position = [18 197 123 24];
            app.LoadModelButton.Text = 'Load Model';

            % Create DrawBoundingBoxButton
            app.DrawBoundingBoxButton = uibutton(app.DeepLearningModulePanel, 'state');
            app.DrawBoundingBoxButton.ValueChangedFcn = createCallbackFcn(app, @DrawBoundingBoxButtonValueChanged, true);
            app.DrawBoundingBoxButton.Text = 'Draw Bounding Box';
            app.DrawBoundingBoxButton.FontName = 'Avenir';
            app.DrawBoundingBoxButton.Position = [19 14 123 31];

            % Create ModelDropDown
            app.ModelDropDown = uidropdown(app.DeepLearningModulePanel);
            app.ModelDropDown.Items = {'96⨉96'};
            app.ModelDropDown.FontName = 'Avenir';
            app.ModelDropDown.Position = [70 235 72 22];
            app.ModelDropDown.Value = '96⨉96';

            % Create ModelDropDownLabel
            app.ModelDropDownLabel = uilabel(app.DeepLearningModulePanel);
            app.ModelDropDownLabel.HorizontalAlignment = 'right';
            app.ModelDropDownLabel.FontName = 'Avenir';
            app.ModelDropDownLabel.Position = [15 235 40 22];
            app.ModelDropDownLabel.Text = 'Model';

            % Create ThresholdKnob
            app.ThresholdKnob = uiknob(app.DeepLearningModulePanel, 'continuous');
            app.ThresholdKnob.ValueChangedFcn = createCallbackFcn(app, @ThresholdKnobValueChanged, true);
            app.ThresholdKnob.FontName = 'Avenir';
            app.ThresholdKnob.Position = [61 111 39 39];
            app.ThresholdKnob.Value = 50;

            % Create ThresholdKnobLabel
            app.ThresholdKnobLabel = uilabel(app.DeepLearningModulePanel);
            app.ThresholdKnobLabel.HorizontalAlignment = 'center';
            app.ThresholdKnobLabel.FontName = 'Avenir';
            app.ThresholdKnobLabel.Position = [51 68 59 22];
            app.ThresholdKnobLabel.Text = 'Threshold';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = LabellerDistributionFull_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end