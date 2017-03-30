clear all;
close all;
clc;

run('C:\Users\Dilin\Documents\MATLAB\vlfeat-0.9.20\toolbox\vl_setup');

imagePaths = {...
'C:\Users\Dilin\Documents\MATLAB\machine vision\project2\shanghai\shanghai01.jpg',...
'C:\Users\Dilin\Documents\MATLAB\machine vision\project2\shanghai\shanghai02.jpg',...
'C:\Users\Dilin\Documents\MATLAB\machine vision\project2\shanghai\shanghai03.jpg'
};
imageCount = size(imagePaths,2);
images = cell(1,imageCount);
featurePoints = cell(1,imageCount);
features = cell(1,imageCount);
featureBoundaries = zeros(1,imageCount);
for i=1:imageCount
    images{i} = single(rgb2gray(imread(imagePaths{i})));
    images{i} = imresize(images{i},0.5);
    [F,D] = vl_sift(images{i});
    featurePoints{i} = F;
    features{i} = D;
end

matchCount = getMatchCounts(features,imageCount);
TH = 500;
E = zeros(imageCount,imageCount);
maxWeight = 0;
src = 0;
dst = 0;
allH = cell(imageCount,imageCount);
for i=1:imageCount
    for j=1:imageCount
        if(matchCount(i,j)<TH)
            E(i,j) = inf;
            continue;
        end
        matches = vl_ubcmatch(features{i},features{j});
        pts1 = featurePoints{i}(1:2,matches(1,:));
        pts2 = featurePoints{j}(1:2,matches(2,:));
        [H,ni,nf,e] = ransacH(pts1,pts2,0.2,2,4000);
        allH{i,j} = H';
        E(i,j) = e;
        if(e>maxWeight)
            src = j;
            dst = i;
            maxWeight = e;
        end
    end
end

% estimate best path for stitching
G = digraph(E);
[P,~] = shortestpath(G,src,dst);

tforms = cell(imageCount,1);
for i=1:numel(P)
    if(i<2)
        T = eye(3);
    else
        T = tforms{P(i-1)}.T*allH{P(i),P(i-1)};
    end
    tforms{P(i)} = projective2d(T);
end

imageSize = size(images{1});  % all the images are the same size

% Compute the output limits  for each transform

% for i = 1:numel(tforms)           
%     [xlim(P(i),:), ylim(P(i),:)] = outputLimits(tforms{P(i)}, [1 imageSize(2)], [1 imageSize(1)]);    
% end
% 
% avgXLim = mean(xlim, 2);
% 
% [~, idx] = sort(avgXLim);

centerIdx = floor((numel(tforms)/2)) + 1;

% centerImageIdx = P(idx(centerIdx));
centerImageIdx = P(centerIdx);

Tinv = invert(tforms{centerImageIdx});

for i = 1:numel(tforms)    
    tforms{P(i)}.T = Tinv.T * tforms{P(i)}.T;
end

% Now, create an initial, empty, panorama into which all the images are
% mapped. 
% 
% Use the |outputLimits| method to compute the minimum and maximum output
% limits over all transformations. These values are used to automatically
% compute the size of the panorama.

for i = 1:numel(tforms)           
    [xlim(P(i),:), ylim(P(i),:)] = outputLimits(tforms{P(i)}, [1 imageSize(2)], [1 imageSize(1)]);
end

% Find the minimum and maximum output limits 
xMin = min([1; xlim(:)]);
xMax = max([imageSize(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([imageSize(1); ylim(:)]);

% Width and height of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the "empty" panorama.
panorama = zeros([height width 3], 'like', uint8(images{1}));

% Use |imwarp| to map images into the panorama and use
% |vision.AlphaBlender| to overlay the images together.

blender = vision.AlphaBlender('Operation', 'Binary mask', ...
    'MaskSource', 'Input port');  

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);

% Create the panorama.
for i = 1:imageCount
    
    I = imresize(imread(imagePaths{P(i)}),0.5);   
   
    % Transform I into the panorama.
    warpedImage = imwarp(I, tforms{P(i)}, 'OutputView', panoramaView);
    figure;
    imshow(uint8(warpedImage))
    % Overlay the warpedImage onto the panorama.
    panorama = step(blender, panorama, warpedImage, warpedImage(:,:,1));
end

figure
imshow(uint8(panorama))