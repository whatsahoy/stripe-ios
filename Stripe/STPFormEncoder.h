//
//  STPFormEncoder.h
//  Stripe
//
//  Created by Jack Flintermann on 1/8/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class STPCardParams, STPBankAccountParams;
@protocol STPFormEncodable;

@interface STPFormEncoder : NSObject

+ (NSDictionary *)dictionaryForObject:(NSObject<STPFormEncodable> *)object;

+ (NSData *)formEncodedDataForDictionary:(NSDictionary *)dictionary;

+ (NSData *)formEncodedDataForObject:(NSObject<STPFormEncodable> *)object;

+ (NSString *)stringByURLEncoding:(NSString *)string;

+ (NSString *)stringByReplacingSnakeCaseWithCamelCase:(NSString *)input;

+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters;

@end

NS_ASSUME_NONNULL_END
