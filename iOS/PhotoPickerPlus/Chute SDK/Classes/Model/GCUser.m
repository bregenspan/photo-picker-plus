//
//  GCUser.m
//
//  Created by Achal Aggarwal on 07/09/11.
//  Copyright 2011 Chute Corporation. All rights reserved.
//

#import "GCUser.h"

@implementation GCUser

@synthesize name;
@synthesize avatarURL;

#pragma mark - Accessor Methods
- (NSString *)name
{
    return [self objectForKey:@"name"]; 
}
- (void)setName:(NSString *)aName
{
    [self setObject:aName forKey:@"name"];
}

- (NSString *)avatarURL
{
    return [self objectForKey:@"avatar"]; 
}

- (void)setAvatarURL:(NSString *)anAvatarURL
{
    [self setObject:anAvatarURL forKey:@"avatar"];
}



- (BOOL) isEqual:(id)object {
    if (IS_NULL([self objectID]) && IS_NULL([object objectID])) {
        return [super isEqual:object];
    }
    if (IS_NULL([self objectID]) || IS_NULL([object objectID])) {
        return NO;
    }
    
    if ([[self objectID] intValue] == [[object objectID] intValue]) {
        return YES;
    }
    return NO;
}

-(NSUInteger)hash{
    if(IS_NULL([self objectID]))
        return [super hash];
    return [[self objectID] hash];
}

@end
