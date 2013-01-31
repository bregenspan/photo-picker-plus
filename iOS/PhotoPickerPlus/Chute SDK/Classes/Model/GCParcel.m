//
//  GCParcel.m
//
//  Created by Achal Aggarwal on 09/09/11.
//  Copyright 2011 Chute Corporation. All rights reserved.
//

#import "GCResource.h"
#import "GCParcel.h"
#import "GCAsset.h"
#import "GCChute.h"
#import "GCUser.h"
#import "GCAccount.h"
#import "GC_UIImage+Extras.h"

NSString * const GCParcelFinishedUploading  = @"GCParcelFinishedUploading";
NSString * const GCParcelAssetsChanged      = @"GCParcelAssetsChanged";
NSString * const GCParcelNoUploads   = @"GCParcelNoUploads";

@implementation GCParcel

@synthesize status;
@synthesize assets;
@synthesize chutes;
@synthesize postMetaData;

@synthesize delegate;
@synthesize completionSelector;

@synthesize assetCount;
@synthesize completedAssetCount;


- (NSDictionary*) dictionaryRepresentation{
    NSMutableDictionary *dictionary;
    if(self.content && self.content.count > 0)
        dictionary = [NSMutableDictionary dictionaryWithDictionary:self.content];
    else
        dictionary = [NSMutableDictionary dictionary];
    
    NSMutableArray *_assetsUniqueDescription = [[NSMutableArray alloc] init];
    for (GCAsset *_asset in assets) {
        NSDictionary *dict = [_asset uniqueRepresentation];
        if(dict)
            [_assetsUniqueDescription addObject:dict];
    }
    
    //Get all Chute IDs
    NSMutableArray *_chuteIDs = [[NSMutableArray alloc] init];
    for (GCChute *_chute in chutes) {
        [_chuteIDs addObject:[_chute proxyForJson]];
    }
    [dictionary setObject:_assetsUniqueDescription forKey:@"assets"];
    [dictionary setObject:_chuteIDs forKey:@"chutes"];
    [dictionary setObject:[NSNumber numberWithInt:self.assetCount] forKey:@"assetCount"];
    [dictionary setObject:[NSNumber numberWithInt:self.completedAssetCount] forKey:@"completedAssetCount"];
    [dictionary setObject:[NSNumber numberWithInt:self.status] forKey:@"status"];
    return dictionary;
}

- (id) initWithDictionaryRepresentation:(NSDictionary*)representation{
    self = [self initWithDictionary:representation];
    if(self){
        NSArray *_repAssets = [representation objectForKey:@"assets"];
        if(_repAssets){
            for(GCAsset *asset in [self assets]){
                ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
                {
                    [asset setAlAsset:myasset];
                };
                NSString *filePath = [asset objectForKey:@"filename"];
                ALAssetsLibraryAccessFailureBlock failureblock = ^(NSError *myerror)
                {
                    NSLog(@"in failureblock, got an error: %@",[myerror localizedDescription]);
                };
                
                NSArray *pathParts = [filePath componentsSeparatedByString:@"://"];
                NSString *assetURLString = @"";
                if([pathParts count] > 1)
                    assetURLString = filePath;
                else{
                    pathParts = [filePath componentsSeparatedByString:@"."];
                    if([pathParts count] > 1){
                        assetURLString = [NSString stringWithFormat:@"assets-library://asset/asset.JPG?id=%@&ext=%@",[pathParts objectAtIndex:0],[pathParts objectAtIndex:1]];
                    }
                    
                }
                if(![[GCAccount sharedManager] assetsLibrary]){
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [[GCAccount sharedManager] setAssetsLibrary:library];
                }
                [[[GCAccount sharedManager] assetsLibrary] assetForURL:[NSURL URLWithString:assetURLString] resultBlock:resultblock failureBlock:failureblock];
            }
        }
        [self setAssetCount:[[representation objectForKey:@"assetCount"] intValue]];
        [self setCompletedAssetCount:[[representation objectForKey:@"completedAssetCount"] intValue]];
    }
    return self;
}

- (void) removeAsset:(GCAsset *)_asset {
    if ([assets indexOfObject:_asset] != NSNotFound) {
        [assets removeObject:_asset];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:GCParcelAssetsChanged object:self];
    if ([assets count] == 0) {
        [self setStatus:GCParcelStatusDone];
        [[NSNotificationCenter defaultCenter] postNotificationName:GCParcelFinishedUploading object:self];
        if (delegate && [delegate respondsToSelector:completionSelector]) {
            [delegate performSelector:completionSelector];
        }
    }
}

- (GCResponse *) newParcel {
    
    //Unique Description of Assets
    NSMutableArray *_assetsUniqueDescription = [[NSMutableArray alloc] init];
    for (GCAsset *_asset in assets) {
        NSDictionary *dict = [_asset uniqueRepresentation];
        if(dict)
            [_assetsUniqueDescription addObject:dict];
    }
    
    //Get all Chute IDs
    NSMutableArray *_chuteIDs = [[NSMutableArray alloc] init];
    for (GCChute *_chute in chutes) {
        [_chuteIDs addObject:[NSString stringWithFormat:@"%@",[_chute objectID]]];
    }
    
    //Make Parameters to be sent across with the request
    NSMutableDictionary *params    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      [_assetsUniqueDescription JSONRepresentation], @"files", 
                                      [_chuteIDs JSONRepresentation], @"chutes", 
                                      nil];
    
    if(self.postMetaData)
        [params setObject:[self.postMetaData JSONRepresentation] forKey:@"metadata"];
    
    
    NSString *_path = [[NSString alloc] initWithFormat:@"%@%@", API_URL, @"parcels"];
    
    GCRequest *gcRequest = [[GCRequest alloc] init];
    GCResponse *response = [gcRequest postRequestWithPath:_path andParams:params];
    
    return response;
}

- (GCResponse *) tokenForAsset:(GCAsset *) anAsset {
    NSString *_path = [[NSString alloc] initWithFormat:@"%@uploads/%@/token", API_URL, [anAsset objectID]];
    GCRequest *gcRequest = [[GCRequest alloc] init];
    GCResponse *response = [gcRequest getRequestWithPath:_path];
    return response;
}

- (BOOL) uploadAssetToS3:(GCAsset *) anAsset withToken:(NSDictionary *) _token {
    
    __block NSMutableData* _imageData = [UIImageJPEGRepresentation([UIImage imageWithCGImage:[[anAsset.alAsset defaultRepresentation] fullResolutionImage] scale:1 orientation:[[anAsset.alAsset valueForProperty:ALAssetPropertyOrientation] intValue]], 1.0) mutableCopy];
    if(!_imageData && [anAsset objectID]){
        NSString *assetURL = NULL;
        for(NSDictionary *dict in [self objectForKey:@"uploads"]){
            if([[NSString stringWithFormat:@"%@",[dict objectForKey:@"asset_id"]] isEqualToString:[anAsset objectID]])
                assetURL = [NSString stringWithFormat:@"%@",[dict objectForKey:@"file_path"]];
        }
        if(![[GCAccount sharedManager] assetsLibrary]){
            ALAssetsLibrary *temp = [[ALAssetsLibrary alloc] init];
            [[GCAccount sharedManager] setAssetsLibrary:temp];
        }
        ALAssetsLibrary *library = [[GCAccount sharedManager] assetsLibrary];
        __block BOOL _response;
        [library assetForURL:[NSURL URLWithString:assetURL] resultBlock:^(ALAsset* _alasset){
            _imageData = [UIImageJPEGRepresentation([UIImage imageWithCGImage:[[_alasset defaultRepresentation] fullResolutionImage] scale:1 orientation:[[anAsset.alAsset valueForProperty:ALAssetPropertyOrientation] intValue]], 1.0) mutableCopy];
            
            ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[_token objectForKey:@"upload_url"]]];
            [request setUploadProgressDelegate:anAsset];
            [request setRequestMethod:@"PUT"];
            [request setPostBody:_imageData];
            
            [request addRequestHeader:@"Date" value:[_token objectForKey:@"date"]];
            [request addRequestHeader:@"Authorization" value:[_token objectForKey:@"signature"]];
            [request addRequestHeader:@"Content-Type" value:[_token objectForKey:@"content_type"]];
            [request addRequestHeader:@"x-amz-acl" value:@"public-read"];
            [request setTimeOutSeconds:300];
            [request startSynchronous];
            GCResponse *_result = [[GCResponse alloc] initWithRequest:request];
            
            _response = [_result isSuccessful];
            
            if (_response) {
                [anAsset setStatus:GCAssetStateCompleting];
            }
            else {
                [anAsset setStatus:GCAssetStateUploadingToS3Failed];
            }
        } failureBlock:^(NSError* error){
        }];
        return _response;
    }else{
        
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[_token objectForKey:@"upload_url"]]];
        [request setUploadProgressDelegate:anAsset];
        [request setRequestMethod:@"PUT"];
        [request setPostBody:_imageData];
        
        [request addRequestHeader:@"Date" value:[_token objectForKey:@"date"]];
        [request addRequestHeader:@"Authorization" value:[_token objectForKey:@"signature"]];
        [request addRequestHeader:@"Content-Type" value:[_token objectForKey:@"content_type"]];
        [request addRequestHeader:@"x-amz-acl" value:@"public-read"];
        [request setTimeOutSeconds:300];
        [request startSynchronous];
        GCResponse *_result = [[GCResponse alloc] initWithRequest:request];
        
        BOOL _response = [_result isSuccessful];
        
        if (_response) {
            [anAsset setStatus:GCAssetStateCompleting];
        }
        else {
            [anAsset setStatus:GCAssetStateUploadingToS3Failed];
        }
        return _response;
    }
}

- (GCResponse *) completionRequestForAsset:(GCAsset *) anAsset {
    NSString *_path = [[NSString alloc] initWithFormat:@"%@uploads/%@/complete", API_URL, [anAsset objectID]];
    GCRequest *gcRequest = [[GCRequest alloc] init];
    GCResponse *response = [gcRequest getRequestWithPath:_path];
    
    if ([response isSuccessful]) {
        [anAsset setStatus:GCAssetStateFinished];
    }
    else {
        [anAsset setStatus:GCAssetStateCompletingFailed];
    }
    
    return response;
}

- (void) removeUploadedAssets {
    NSMutableArray *assetUrls = [[NSMutableArray alloc] init];
    for (NSDictionary *_assetDetails in [self objectForKey:@"uploads"]) {
        [assetUrls addObject:[_assetDetails objectForKey:@"file_path"]];
    }
    
    NSMutableArray *assetsToRemove = [[NSMutableArray alloc] init];
    
    for (GCAsset *_asset in assets) {
        if ([assetUrls indexOfObject:[_asset uniqueURL]] != NSNotFound) {
            NSString *_id = [[[self objectForKey:@"uploads"] objectAtIndex:[assetUrls indexOfObject:[_asset uniqueURL]]] objectForKey:@"asset_id"];
            [_asset setObject:_id forKey:@"id"];
        }
        else if ([_asset objectForKey:@"filename"] && [assetUrls indexOfObject:[_asset objectForKey:@"filename"]] != NSNotFound) {
            NSString *_id = [[[self objectForKey:@"uploads"] objectAtIndex:[assetUrls indexOfObject:[_asset objectForKey:@"filename"]]] objectForKey:@"asset_id"];
            [_asset setObject:_id forKey:@"id"];
        }
        else{
            [assetsToRemove addObject:_asset];
            continue;
        }
        if([_asset status] == GCAssetStateFinished){
            [assetsToRemove addObject:_asset];
        }
    }
    
    for (GCAsset *obj in assetsToRemove) {
        [self removeAsset:obj];
    }
    
    completedAssetCount = [assetsToRemove count];
    
}

- (void) startUpload {
    //Create Parcel with Assets and Chutes
    if(![self objectID]){
        NSDictionary *_parcel = [[[self newParcel] rawResponse] JSONValue];
        for (NSString *key in [_parcel allKeys]) {
            [self setObject:[_parcel objectForKey:key] forKey:key];
        }
    }
    
    //Remove assets which are already uploaded.
    [self removeUploadedAssets];
    if(status == GCParcelStatusDone)
        return;
    dispatch_queue_t queue;
    queue = dispatch_queue_create("com.sharedRoll.queue", NULL);
    
    //Start loop of assets
    for (GCAsset *_asset in assets) {
        if ([_asset status] == GCAssetStateFinished) {
            continue;
        }
        
        dispatch_async(queue, ^(void) {
            [_asset setStatus:GCAssetStateGettingToken];
            
            //Generate New token for each asset
            GCResponse *_response = [self tokenForAsset:_asset];
            if([_response statusCode] >=300 && [_response statusCode] < 400){
                [self removeAsset:_asset];
                return;
            }
            
            while (![_response isSuccessful]) {
                [_asset setStatus:GCAssetStateGettingTokenFailed];
                _response = [self tokenForAsset:_asset];
            }
            
            //Upload using the token to S3
            NSDictionary *_token = [_response data];
            [_asset setStatus:GCAssetStateUploadingToS3];
            
            BOOL uploaded = [self uploadAssetToS3:_asset withToken:_token];
            while (!uploaded) {
                uploaded = [self uploadAssetToS3:_asset withToken:_token];
            }
            
            [_asset setStatus:GCAssetStateCompleting];
            //Send completion Request to the asset after uploading to S3
            _response = [self completionRequestForAsset:_asset];
            while (![_response isSuccessful]) {
                _response = [self completionRequestForAsset:_asset];
            }
            
        });
    }
}

- (void) updateUploadQueue:(NSNotification *) notification {
    if ([[notification object] status] == GCAssetStateFinished) {
        completedAssetCount ++;
        [self removeAsset:[notification object]];
    }
}

- (void) startUploadWithTarget:(id)_target andSelector:(SEL)_selector {
    [self setDelegate:_target];
    [self setCompletionSelector:_selector];
    [self setStatus:GCParcelStatusUploading];
    [self performSelector:@selector(startUpload)];
}

- (GCResponse*)serverAssets{
    if(![self objectID]){
        GCResponse *response = [[GCResponse alloc] init];
        NSMutableDictionary *_errorDetail = [NSMutableDictionary dictionary];
        [_errorDetail setValue:@"This parcel is missing an id." forKey:NSLocalizedDescriptionKey];
        [response setError:[GCError errorWithDomain:@"GCError" code:401 userInfo:_errorDetail]];
        return response;
    }
    NSString *_path              = [[NSString alloc] initWithFormat:@"%@%@/%@/assets", API_URL, [[self class] elementName], [self objectID]];
    GCRequest *gcRequest         = [[GCRequest alloc] init];
    GCResponse *_response        = [gcRequest getRequestWithPath:_path];
    NSMutableArray *_assets    = [[NSMutableArray alloc] init]; 
    for (NSDictionary *_dic in [_response data]) {
        [_assets addObject:[GCAsset objectWithDictionary:_dic]];
    }
    [_response setObject:_assets];
    return _response;
}

- (id) initWithAssets:(NSArray *) _assets andChutes:(NSArray *) _chutes {
    self = [super init];
    if (self) {
        assets = [NSMutableArray arrayWithArray:_assets];
        chutes = [NSArray arrayWithArray:_chutes];
        [self setAssetCount:[assets count]];
        [self setStatus:GCParcelStatusNew];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUploadQueue:) name:GCAssetUploadComplete object:nil];
    }
    return self;
}

+ (id) objectWithAssets:(NSArray *) _assets andChutes:(NSArray *) _chutes {
    return [[self alloc] initWithAssets:_assets andChutes:_chutes];
}


+ (id) objectWithAssets:(NSArray *) _assets andChutes:(NSArray *) _chutes andMetaData:(NSDictionary*)_metaData{
    id parcel = [[self alloc] initWithAssets:_assets andChutes:_chutes];
    if(parcel){
        [parcel setPostMetaData:_metaData];
    }
    return parcel;
}

+ (id) objectWithDictionary:(NSDictionary *) dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (id) initWithDictionary:(NSDictionary *) dictionary {
    self = [self init];
    if(self){
        for (NSString *key in [dictionary allKeys]) {
            id _obj;
            if ([key isEqualToString:@"user"]) {
                _obj = [GCUser objectWithDictionary:[dictionary objectForKey:key]];
            }
            else if ([key isEqualToString:@"assets"]) {
                assets = [[NSMutableArray alloc] init];
                for (NSDictionary *_dic in [dictionary objectForKey:key]) {
                    GCAsset *asset = [GCAsset objectWithDictionary:_dic];
                    if([_dic objectForKey:@"status"])
                        [asset setStatus:[[_dic objectForKey:@"status"] intValue]];
                    else
                        [asset setStatus:GCAssetStateNew];
                    [assets addObject:asset];
                }
                
            }
            else if ([key isEqualToString:@"chutes"]) {
                NSMutableArray *array = [NSMutableArray array];
                for (NSDictionary *_dic in [dictionary objectForKey:key]) {
                    [array addObject:[GCChute objectWithDictionary:_dic]];
                }
                chutes = [NSArray arrayWithArray:array];
            }
            else if ([key isEqualToString:@"chute"]) {
                chutes = [NSArray arrayWithObject:[GCChute objectWithDictionary:[dictionary objectForKey:key]]];
            }
            else {
                _obj = IS_NULL([dictionary objectForKey:key])? @"": [dictionary objectForKey:key];
            }
            [self setObject:_obj forKey:key];
        }
        [self setStatus:GCParcelStatusDone];
    }
    return self;
}

+ (NSString *)elementName {
    return @"parcels";
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
