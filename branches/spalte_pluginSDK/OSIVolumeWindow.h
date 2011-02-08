//
//  OSIVolumeWindow.h
//  OsiriX
//
//  Created by Joël Spaltenstein on 1/25/11.
//  Copyright 2011 OsiriX Team. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OSIROIManager.h"

/**  
 
 Each instance of a OSIVolumeWindow is paired was an OsiriX `ViewerController`. The goal of the Volume Window is to provide a simplified interface to common tasks that are inherently difficult to do directly with a `ViewerController`. 
 
 */

extern NSString* const OSIVolumeWindowDidCloseNotification; 

// This is a peer of the ViewerController. It provides an abstract and cleaner interface to the ViewerController
// for now 

// it really is the window that is showing stuff, so it should be possible to ask the window what the hell it is showing.

// a study is a tag on images, but many differnt studies could be shown in the same window. a specific volume definitly belongs to a study, and it should be possible to
// ask the environment what all the open studies are.



@class OSIFloatVolumeData;
@class OSIROIManager;
@class ViewerController;

@interface OSIVolumeWindow : NSObject <OSIROIManagerDelegate>  {
	ViewerController *_viewerController; // this is retained
	OSIROIManager *_ROIManager;
}

///-----------------------------------
/// @name Managing the Volume Window
///-----------------------------------

/** Returns YES if the `ViewerController` paired with this Volume Window is still open and it's data is currently loaded.
 
 @see viewerController
 */
- (BOOL)isOpen; // observable. Is this VolumeWindow actually connected to a ViewerController. If the ViewerController is closed, the connection will be lost
// but if the plugin is lazy and doesn't close things properly, at least the ViewerController will be released, the memory will be released, and the plugin will just be holding on to
// a super lightweight object

/** Returns the title of the window represented by this Volume Window.
 
 @return The title of the window represented by this Volume Window.
 */
- (NSString *)title;

///-----------------------------------
/// @name Managing ROIs
///-----------------------------------

/** Returns the OSIROIManager for this Volume Window.
  
 @return The title of the window represented by this Volume Window.
 
 @warning *Important:* The Volume Window is the delegate of this ROIManger, you should never change its delegate.
 */
- (OSIROIManager *)ROIManager; // no not mess with the delegate of this ROI manager, but feel free to ask if for it's list of ROIs

///-----------------------------------
/// @name Dealing with Volume Data
///-----------------------------------

// not done
//- (NSArray *)selectedROIs; // observable list of selected ROIs
//

/** Returns the dimensions available in the Volume Window.
 
 Volume Data objects represent a volume in the three natural dimensions. Additional dimensions such as _movieIndex_ may be available in a given Volume Window. This method returns the names of the available dimensions as NSString objects
 
 @return An array of NSString objects representing the names of the available dimensions.
 */
- (NSArray *)dimensions; // dimensions other than the 3 natural dimensions, time for example

/** Returns the depth, or avaibable frames in the given dimension.
 
 @return The number of frames available in the given dimension.
 @param dimension The dimension name for which the depth is sought
 */
- (NSUInteger)depthOfDimension:(NSString *)dimension; // I don't like this name


/** Returns a Volume Data object that can be used to access the data at the  given dimension coordinates
 
 @return The Volume Data for the dimension coordinates.
 @param dimensions An array of dimension names as NSString objects.
 @param indexes An array of indexes as NSNumber objects in the corresponding dimension 
 */
- (OSIFloatVolumeData *)floatVolumeDataForDimensions:(NSArray *)dimensions indexes:(NSArray *)indexes;

/** Returns a Volume Data object that can be used to access the data at the  given dimension coordinates
 
 @return The Volume Data for the dimension coordinates.
 @param firstDimension The first dimension name.
 @param ... First the index in the firstDimension as an NSNumber object, then a null-terminated list of alternating dimension names and indexes.
 */
- (OSIFloatVolumeData *)floatVolumeDataForDimensionsAndIndexes:(NSString *)firstDimension, ... NS_REQUIRES_NIL_TERMINATION;
//
//- (OSIFloatVolumeData *)displayedFloatVolumeData;

///-----------------------------------
/// @name Breaking out of the SDK
///-----------------------------------

/** Returns the shared `ViewerController` this Volume Window is paired with.
 
 If the `ViewerController` instance this Volume Window is paired with closes, viewerController will return nil. 
 
 @return The shared `ViewerController` this Volume Window is paired with.
 @see isOpen
 */
- (ViewerController *)viewerController; // if you really want to go into the depths of OsiriX, use at your own peril!


@end
