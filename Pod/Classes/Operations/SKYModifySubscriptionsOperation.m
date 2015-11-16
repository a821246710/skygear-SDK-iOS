//
//  SKYModifySubscriptionsOperation.m
//  askq
//
//  Created by Kenji Pa on 29/1/15.
//  Copyright (c) 2015 Rocky Chan. All rights reserved.
//

#import "SKYModifySubscriptionsOperation.h"

#import "SKYDefaults.h"
#import "SKYSubscriptionSerialization.h"
#import "SKYSubscriptionSerializer.h"
#import "SKYDataSerialization.h"

@implementation SKYModifySubscriptionsOperation {
    NSMutableDictionary *subscriptionsByID;
}

- (instancetype)initWithSubscriptionsToSave:(NSArray *)subscriptionsToSave
{
    self = [super init];
    if (self) {
        self.subscriptionsToSave = subscriptionsToSave;
    }
    return self;
}

+ (instancetype)operationWithSubscriptionsToSave:(NSArray *)subscriptionsToSave;
{
    return [[self alloc] initWithSubscriptionsToSave:subscriptionsToSave];
}

- (void)prepareForRequest
{
    SKYSubscriptionSerializer *serializer = [SKYSubscriptionSerializer serializer];

    NSMutableDictionary *payload = [@{
        @"database_id" : self.database.databaseID,
    } mutableCopy];

    NSMutableArray *dictionariesToSave = [NSMutableArray array];
    subscriptionsByID = [NSMutableDictionary dictionary];
    for (SKYSubscription *subscription in self.subscriptionsToSave) {
        [dictionariesToSave addObject:[serializer dictionaryWithSubscription:subscription]];
        subscriptionsByID[subscription.subscriptionID] = subscription;
    }
    if (dictionariesToSave.count) {
        payload[@"subscriptions"] = dictionariesToSave;
    }

    NSString *deviceID = nil;
    if (self.deviceID) {
        deviceID = self.deviceID;
    } else {
        deviceID = [SKYDefaults sharedDefaults].deviceID;
    }
    if (deviceID.length) {
        payload[@"device_id"] = deviceID;
    }

    self.request = [[SKYRequest alloc] initWithAction:@"subscription:save" payload:payload];
    self.request.APIKey = self.container.APIKey;
    self.request.accessToken = self.container.currentAccessToken;
}

- (void)setModifySubscriptionsCompletionBlock:
    (void (^)(NSArray *, NSError *))modifySubscriptionsCompletionBlock
{
    [self willChangeValueForKey:@"modifySubscriptionsCompletionBlock"];
    _modifySubscriptionsCompletionBlock = modifySubscriptionsCompletionBlock;
    [self updateCompletionBlock];
    [self didChangeValueForKey:@"modifySubscriptionsCompletionBlock"];
}

- (NSArray *)processResultArray:(NSArray *)result
{
    NSMutableArray *savedSubscriptions = [NSMutableArray array];
    for (NSDictionary *dict in result) {
        // per item error has not been utilized yet
        //        NSError *error = nil;
        SKYSubscription *subscription = nil;
        NSString *subscriptionID = dict[SKYSubscriptionSerializationSubscriptionIDKey];
        if (subscriptionID) {
            subscription = subscriptionsByID[subscriptionID];
            if (!subscription) {
                NSLog(@"A returned subscription is not requested.");
            }

            NSString *subscriptionType = dict[SKYSubscriptionSerializationSubscriptionTypeKey];
            if ([subscriptionType isEqual:SKYSubscriptionSerializationSubscriptionTypeQuery]) {
                // do nothing
            } else if ([subscriptionType
                           isEqual:SKYSubscriptionSerializationSubscriptionTypeError]) {
                //                NSMutableDictionary *userInfo = [SKYDataSerialization
                //                userInfoWithErrorDictionary:dict];
                //                userInfo[NSLocalizedDescriptionKey] = @"An error occurred while
                //                modifying subscription.";
                //                error = [NSError errorWithDomain:(NSString
                //                *)SKYOperationErrorDomain
                //                                            code:0
                //                                        userInfo:userInfo];
            }
        } else {
            //            NSMutableDictionary *userInfo = [self
            //            errorUserInfoWithLocalizedDescription:@"Missing `id`"
            //                                                                        errorDictionary:nil];
            //            error = [NSError errorWithDomain:(NSString *)SKYOperationErrorDomain
            //                                        code:0
            //                                    userInfo:userInfo];
        }

        if (subscription) {
            [savedSubscriptions addObject:subscription];
        }
    }

    return savedSubscriptions;
}

- (void)updateCompletionBlock
{
    if (self.modifySubscriptionsCompletionBlock) {
        __weak typeof(self) weakSelf = self;
        self.completionBlock = ^{
            NSArray *resultArray = nil;
            NSError *error = weakSelf.error;
            if (!error) {
                NSArray *responseArray = weakSelf.response[@"result"];
                if ([responseArray isKindOfClass:[NSArray class]]) {
                    resultArray = [weakSelf processResultArray:responseArray];
                } else {
                    NSDictionary *userInfo = [weakSelf
                        errorUserInfoWithLocalizedDescription:@"Server returned malformed results."
                                              errorDictionary:nil];
                    error = [NSError errorWithDomain:(NSString *)SKYOperationErrorDomain
                                                code:0
                                            userInfo:userInfo];
                }
            }

            if (weakSelf.modifySubscriptionsCompletionBlock) {
                weakSelf.modifySubscriptionsCompletionBlock(resultArray, error);
            }
        };
    } else {
        self.completionBlock = nil;
    }
}

@end