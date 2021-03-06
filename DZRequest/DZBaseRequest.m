//
//  DZBaseRequest.m
//  DZNetworking
//
//  Created by Wenbing Zuo on 5/3/16.
//  Copyright © 2016 DaZuo. All rights reserved.
//

#import "DZBaseRequest.h"
#import "DZRequestConst.h"
#import "AFNetworkActivityIndicatorManager.h"

@interface DZBaseRequest ()
@property (nonatomic, strong, readwrite) NSPointerArray *accessories;
@property (nonatomic, strong, readwrite) NSURLSessionDataTask *task;

@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, assign, getter=isCanceling) BOOL canceling;
@end

@implementation DZBaseRequest

- (instancetype)init {
    self = [super init];
    if (self) {
        self.requestMethod = DZRequestMethodGET;
        self.requestTimeoutInterval = 20;
        self.requestSerializerType = DZRequestSerializerTypeJSON;
        self.responseSerializerType = DZResponseSerializerTypeJSON;
    }
    return self;
}

- (NSPointerArray *)accessories {
    if (!_accessories) {
        _accessories = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];;
    }
    return _accessories;
}

- (void)addAccessory:(id<DZRequestAccessory>)accessory {
    [self.accessories addPointer:(__bridge void *)accessory];
}

- (void)start {
    if (self.isRunning) return;
    self.running = YES;
    
    [self toggleAccessoriesRequestWillStart];
    [[DZRequestManager sharedManager] addRequest:self];
}

- (void)startRequestSuccessCallback:(DZRequestSuccessCallback)success failureCallback:(DZRequestFailureCallback)failure {
    [self setSuccessCallback:success failure:failure];
    [self start];
}

- (void)setSuccessCallback:(DZRequestSuccessCallback)success failure:(DZRequestFailureCallback)failure {
    self.successCallback = success;
    self.failureCallback = failure;
}

- (void)cancel {
    if (self.canceling) return;
    self.canceling = YES;
    [[DZRequestManager sharedManager] removeRequest:self];
}

- (void)cancelWithCallback:(DZRequestCancelCallback)cancel {
    self.cancelCallback = cancel;
    [self cancel];
}

- (void)requestDidFinishSuccess {
    
}

- (void)requestDidFinishFailure {
    
}

#pragma mark - Getter

- (NSInteger)responseStatusCode {
    return [(NSHTTPURLResponse *)self.task.response statusCode];
}

- (BOOL)canCancel {
    return self.task ? YES : NO;
}

- (NSDictionary *)responseHeader {
    return [(NSHTTPURLResponse *)self.task.response allHeaderFields];
}

#pragma mark - Private

- (void)toggleAccessoriesRequestWillStart {
    for (id<DZRequestAccessory> obj in self.accessories) {
        if ([obj respondsToSelector:@selector(requestWillStart:)]) {
            [obj requestWillStart:self];
        }
    }
}

- (void)toggleAccessoriesRequestDidStart {
    for (id<DZRequestAccessory> obj in self.accessories) {
        if ([obj respondsToSelector:@selector(requestDidStart:)]) {
            [obj requestDidStart:self];
        }
    }
}

- (void)toggleAccessoriesRequestWillStop {
    for (id<DZRequestAccessory> obj in self.accessories) {
        if ([obj respondsToSelector:@selector(requestWillStop:)]) {
            [obj requestWillStop:self];
        }
    }
}

- (void)toggleAccessoriesRequestDidStop {
    for (id<DZRequestAccessory> obj in self.accessories) {
        if ([obj respondsToSelector:@selector(requestDidStop:)]) {
            [obj requestDidStop:self];
        }
    }
}

@end



static NSDictionary * DZHeadDictionaryFromRequest(DZBaseRequest *request) {
    NSDictionary *defaultHeader = request.requestDefaultHeader;
    NSDictionary *normalHeader = request.requestHeader;
    
    NSMutableDictionary *header = [NSMutableDictionary dictionaryWithDictionary:defaultHeader];
    [header addEntriesFromDictionary:normalHeader];
    return header;
}

static NSString * DZURLStringFromRequest(DZBaseRequest *request) {
    NSString *detailURL = request.requestURL;
    if ([[detailURL lowercaseString] hasPrefix:@"http"]) {
        return detailURL;
    }
    
    NSString *baseURL = request.requestBaseURL;
    if ([[baseURL lowercaseString] hasPrefix:@"http"]) {
        return [NSString stringWithFormat:@"%@%@", baseURL, detailURL.length==0?@"":detailURL];
    } else {
        return nil;
    }
}

static NSString * DZHashStringFromTask(NSURLSessionDataTask *task) {
    return [NSString stringWithFormat:@"%lu", (unsigned long)[task hash]];
}

@interface DZRequestManager ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableDictionary *requests;

@end

@implementation DZRequestManager

+ (instancetype)sharedManager {
    static DZRequestManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [DZRequestManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sessionManager = [AFHTTPSessionManager manager];
        self.sessionManager.completionQueue = dispatch_queue_create("io.dazuo.github.request.session.completion.queue", DISPATCH_QUEUE_CONCURRENT);
        self.requests = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Private

- (void)_addTask:(DZBaseRequest *)request {
    if (request.task) {
        NSString *key = DZHashStringFromTask(request.task);
        @synchronized(self) {
            [self.requests setValue:request forKey:key];
        }
    }
}

- (void)_removeTask:(DZBaseRequest *)request {
    NSString *key = DZHashStringFromTask(request.task);
    @synchronized(self) {
        [self.requests removeObjectForKey:key];
    }
}

- (void)_handleResponseSuccess:(DZBaseRequest *)request responseObject:(id)responseObject {
    request.responseObject = responseObject;
    request.error = nil;
    [request requestDidFinishSuccess];
    !request.successCallback?:request.successCallback(request, request.responseObject);
}

- (void)_handleResponseFailure:(DZBaseRequest *)request error:(NSError *)error {
    request.responseObject = nil;
    request.error = error;
    [request requestDidFinishFailure];
    !request.failureCallback?:request.failureCallback(request, request.error);
}

- (void)_handleResponseCancelled:(DZBaseRequest *)request {
    !request.cancelCallback?:request.cancelCallback(request);
}

- (void)_handleResponse:(NSURLSessionDataTask *)task response:(id)responseObject error:(NSError *)error {
    NSString *key = DZHashStringFromTask(task);
    
    DZBaseRequest *request = self.requests[key];
    if (error.code == NSURLErrorCancelled) {
        request.running = NO;
        [self _handleResponseCancelled:request];
        request.canceling = NO;
    } else {
        request.running = NO;
        request.canceling = NO;
        
        [request toggleAccessoriesRequestWillStop];
        if (!error) {
            if (request.responseFilterCallback) {
                NSError *filterError = request.responseFilterCallback(request, responseObject);
                if (filterError) {
                    [self _handleResponseFailure:request error:filterError];
                } else {
                    [self _handleResponseSuccess:request responseObject:responseObject];
                }
            } else {
                [self _handleResponseSuccess:request responseObject:responseObject];
            }
        } else {
            [self _handleResponseFailure:request error:error];
        }
        [request toggleAccessoriesRequestDidStop];
    }
    
    [self _removeTask:request];
}

#pragma mark - Public

- (void)addRequest:(DZBaseRequest *)request {
    DZRequestSerializerType requestSerializerType = request.requestSerializerType;
    switch (requestSerializerType) {
        case DZRequestSerializerTypeHTTP:{
            self.sessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
        } break;
        case DZRequestSerializerTypeJSON: {
            self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        } break;
        default:
            break;
    }
    self.sessionManager.requestSerializer.timeoutInterval = request.requestTimeoutInterval;
    NSDictionary *headers = DZHeadDictionaryFromRequest(request);
    for (id field in headers.allKeys) {
        id value = headers[field];
        if ([field isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
            [self.sessionManager.requestSerializer setValue:value forHTTPHeaderField:field];
        } else {
            DZLog(@"Error, the key and value in HTTPRequestHeaders should be string.");
        }
    }
    
    DZResponseSerializerType responseSerializerType = request.responseSerializerType;
    switch (responseSerializerType) {
        case DZResponseSerializerTypeJSON:
            self.sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
            break;
        case DZResponseSerializerTypeHTTP:
            self.sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
            break;
        default:
            break;
    }
    
    NSString *url = DZURLStringFromRequest(request);
    if (url.length == 0) DZLog(@"Error, the request URL format is wrong.");
    DZRequestMethod method = request.requestMethod;
    id params = request.requestParameters;
    DZRequestConstructionCallback constructionBlock = request.requestConstructionCallback;
    DZRequestProgressCallback uploadProgressCallback = request.uploadProgressCallback;
    DZRequestProgressCallback downloadProgressCallback = request.downloadProgressCallback;
    
    NSURLSessionDataTask *task = nil;
    switch (method) {
        case DZRequestMethodGET: {
            task = [self.sessionManager GET:url parameters:params progress:^(NSProgress *downloadProgress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    !downloadProgressCallback?:downloadProgressCallback(downloadProgress);
                });
            } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [self _handleResponse:task response:responseObject error:nil];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self _handleResponse:task response:nil error:error];
            }];
        } break;
            
        case DZRequestMethodPOST: {
            if (constructionBlock) {
                task = [self.sessionManager POST:url parameters:params constructingBodyWithBlock:constructionBlock progress:^(NSProgress * _Nonnull uploadProgress) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        !uploadProgressCallback?:uploadProgressCallback(uploadProgress);
                    });
                } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    [self _handleResponse:task response:responseObject error:nil];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    [self _handleResponse:task response:nil error:error];
                }];
            } else {
                task = [self.sessionManager POST:url parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    [self _handleResponse:task response:responseObject error:nil];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    [self _handleResponse:task response:nil error:error];
                }];
            }
        } break;
            
        case DZRequestMethodPUT: {
            task = [self.sessionManager PUT:url parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [self _handleResponse:task response:responseObject error:nil];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self _handleResponse:task response:nil error:error];
            }];
        } break;
            
        case DZRequestMethodDELETE: {
            task = [self.sessionManager DELETE:url parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [self _handleResponse:task response:responseObject error:nil];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self _handleResponse:task response:nil error:error];
            }];
        } break;
            
        case DZRequestMethodPATCH: {
            task = [self.sessionManager PATCH:url parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                [self _handleResponse:task response:responseObject error:nil];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self _handleResponse:task response:nil error:error];
            }];
        } break;
            
        case DZRequestMethodHEAD: {
            task = [self.sessionManager HEAD:url parameters:params success:^(NSURLSessionDataTask * _Nonnull task) {
                [self _handleResponse:task response:nil error:nil];
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                [self _handleResponse:task response:nil error:error];
            }];
        } break;
            
        default:
            break;
    }
    
    [AFNetworkActivityIndicatorManager sharedManager].enabled = request.showActivityIndicator;
    request.task = task;
    [self _addTask:request];
    [request toggleAccessoriesRequestDidStart];
}

- (void)removeRequest:(DZBaseRequest *)request {
    [request.task cancel];
}

@end