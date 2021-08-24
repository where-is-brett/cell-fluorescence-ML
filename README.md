# Semi-automated Cell Fluorescence Measurement
[![View Semi-automatic Corrected Total Cell Fluorescence Measurement on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://au.mathworks.com/matlabcentral/fileexchange/98134-semi-automatic-corrected-total-cell-fluorescence-measurement)

## MATLAB File Exchange Visitors
MATLAB FileExchange has a file size limit of 250MB. The fully self-contained app could not be made available for download directly from the MATLAB Add-ons. As an alternative, you may download the app from the [main branch](https://github.com/where-is-brett/cell-fluorescence-ml) or [Releases](https://github.com/where-is-brett/cell-fluorescence-ml/releases/tag/0.1.0).

## Pre-requisites
* A valid MATLAB license is required.
* Deep Learning Tool Box

## Usage
The current release is a personal project in its infancy. Despite my best efforts to deliver both functionality and user experience, there may be runtime errors if the app is not used as intented. It is important to understand the app UI before usage. You can find detailed instructions and a video demonstration [here](https://brettyang.info/neuroscience/computation/2021/08/21/CTCF-ML/). Please do not hesitate to report any issues or suggestions via this [form](https://brettyang.info/contact).

## Functionality
The user may manually define these MATLAB ROI objects:
* images.roi.Circle
* images.roi.Freehand
* images.roi.Polygon

The "Deep Learning Toolbox" requires the user to first load a model specified in the model selection dropdown (currently only 96 by 96 model is available). Once the model has been imported, the "Draw Bounding Box" button will become available. The user may draw bounding boxes to predict cell boundaries within it. The initial prediction time is around 4 seconds and subsquent predictions take about 1 second (tested on a 2016 MacBook Pro). 

The user may save ROI data in the following forms:
* A binary file containing a cell array of MATLAB ROI objects, '.ROI' format
* An 8-bit binary mask image in the '.PNG' or '.TIF' format
* An 8-bit instance mask image in the '.PNG' or '.TIF' format

The user may load ROI data to workspace from '.ROI' files created in this app.

## License
This app is distributed under the MIT license. For details, please refer to the LICENSE file in the main branch.


*This app was designed for the Laboratory of Molecular Neuroscience and Dementia*
