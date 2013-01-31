//
//  GCUser.h
//
//  Created by Achal Aggarwal on 07/09/11.
//  Copyright 2011 Chute Corporation. All rights reserved.
//

#import "GCResource.h"

@interface GCUser : GCResource

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *avatarURL;

@end
