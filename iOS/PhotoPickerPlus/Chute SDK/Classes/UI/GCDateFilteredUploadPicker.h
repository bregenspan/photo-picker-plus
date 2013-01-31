//
//  GCDateFilteredUploadPicker.h
//  ChuteSDKDevProject
//
//  Created by Brandon Coston on 9/14/11.
//  Copyright 2011 Chute Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GetChute.h"

@interface GCDateFilteredUploadPicker : GCUIBaseViewController <UITableViewDelegate, UITableViewDataSource>{
    NSArray *images;
    NSArray *filteredImages;
    NSMutableSet *selected;
    IBOutlet UIImageView *selectedIndicator;
    IBOutlet UITableView *imageTable;
    
    IBOutlet UIView *switchModeView;
    IBOutlet UILabel *switchModeLabel;
    
    //selectedSlider is an optional UI component.  In a subclass if you do not initialize the slider in code or hook it up in interface builder the class will still function the same.
    IBOutlet UIScrollView *selectedSlider;
    
    NSArray *uploadChutes;
}
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) NSArray *filteredImages;
@property (nonatomic, strong) IBOutlet UIImageView *selectedIndicator;
@property (nonatomic, strong) NSArray *uploadChutes;
@property (nonatomic, strong) NSDate *start;
@property (nonatomic, strong) NSDate *end;
@property (nonatomic, strong) NSMutableSet *_selected;
@property (nonatomic, strong) IBOutlet UITableView *imageTable;
@property (nonatomic, strong) IBOutlet UILabel *switchModeLabel;

-(NSArray*)selectedImages;
-(IBAction)uploadAssets:(id)sender;

-(IBAction)switchMode:(id)sender;


//Override in subclass to adjust UI if the filtered images are the same as all the images, or if no filtering is being done.
-(void)hideSwitchView;

@end
