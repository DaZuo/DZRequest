//
//  DZBatchRequest.h
//  DZNetworking
//
//  Created by Wenbing Zuo on 5/6/16.
//  Copyright © 2016 DaZuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DZBaseRequest.h"
@class DZBatchRequest;

typedef void(^DZBatchRequestSuccessCallback)(DZBatchRequest *batchRequest);
typedef void(^DZBatchRequestFailureCallback)(DZBatchRequest *batchRequest, __kindof DZBaseRequest *request, NSError *error);

@interface DZBatchRequest : NSObject

/**
 The requests ran in the receiver.
 */
@property (nonatomic, strong, readonly) NSArray *requests;

/**
 A flag to indicate whether cancel the rest request when error occurs.
 */
@property (nonatomic, assign) BOOL cancelWhenErrorOccur;

@property (nonatomic, strong, readonly) NSMutableArray *accessories;
- (void)addAccessory:(id<DZRequestAccessory>)accessory;


@property (nonatomic, copy) DZBatchRequestSuccessCallback successCallback;
@property (nonatomic, copy) DZBatchRequestFailureCallback failureCallback;
- (void)setSuccesssCallback:(DZBatchRequestSuccessCallback)success failureCallback:(DZBatchRequestFailureCallback)failure;


@property (nonatomic, strong) dispatch_queue_t completionQueue;

- (void)start;

- (void)startBatchReqeustSuccessCallback:(DZBatchRequestSuccessCallback)success failureCallback:(DZBatchRequestFailureCallback)failure;

- (void)cancel;

///---------------------
/// @name Initialization
///---------------------

- (instancetype)initWithRequests:(NSArray<DZBaseRequest *>*) requests;

@end



@interface DZBatchRequestManager : NSObject

+ (instancetype)sharedManager;

- (void)addBatchRequest:(DZBatchRequest *)batchRequest;

- (void)removeBatchRequest:(DZBatchRequest *)batchRequest;

@end

