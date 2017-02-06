//
//  STPAPIClient+ApplePay.m
//  Stripe
//
//  Created by Jack Flintermann on 12/19/14.
//

#import <AddressBook/AddressBook.h>

#import "PKPayment+Stripe.h"
#import "STPAPIClient+ApplePay.h"
#import "STPAPIClient+Private.h"
#import "STPAnalyticsClient.h"

FAUXPAS_IGNORED_IN_FILE(APIAvailability)

@implementation STPAPIClient (ApplePay)

- (void)createTokenWithPayment:(PKPayment *)payment completion:(STPTokenCompletionBlock)completion {
    [self createTokenWithParameters:[self.class parametersForPayment:payment]
                         completion:completion];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
+ (NSDictionary *)parametersForPayment:(PKPayment *)payment {
    NSCAssert(payment != nil, @"Cannot create a token with a nil payment.");
    NSMutableDictionary *payload = [NSMutableDictionary new];
    NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [set removeCharactersInString:@"+="];
    NSString *paymentString =
    [[[NSString alloc] initWithData:payment.token.paymentData encoding:NSUTF8StringEncoding] stringByAddingPercentEncodingWithAllowedCharacters:set];
    payload[@"pk_token"] = paymentString;

    ABRecordRef billingAddress = payment.billingAddress;
    if (billingAddress) {
        NSMutableDictionary *cardParams = [NSMutableDictionary dictionary];

        NSString *firstName = (__bridge_transfer NSString*)ABRecordCopyValue(billingAddress, kABPersonFirstNameProperty);
        NSString *lastName = (__bridge_transfer NSString*)ABRecordCopyValue(billingAddress, kABPersonLastNameProperty);
        if (firstName.length && lastName.length) {
            cardParams[@"name"] = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
        }

        ABMultiValueRef addressValues = ABRecordCopyValue(billingAddress, kABPersonAddressProperty);
        if (addressValues != NULL) {
            if (ABMultiValueGetCount(addressValues) > 0) {
                CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(addressValues, 0);
                NSString *line1 = CFDictionaryGetValue(dict, kABPersonAddressStreetKey);
                if (line1) {
                    cardParams[@"address_line1"] = line1;
                }
                NSString *city = CFDictionaryGetValue(dict, kABPersonAddressCityKey);
                if (city) {
                    cardParams[@"address_city"] = city;
                }
                NSString *state = CFDictionaryGetValue(dict, kABPersonAddressStateKey);
                if (state) {
                    cardParams[@"address_state"] = state;
                }
                NSString *zip = CFDictionaryGetValue(dict, kABPersonAddressZIPKey);
                if (zip) {
                    cardParams[@"address_zip"] = zip;
                }
                NSString *country = CFDictionaryGetValue(dict, kABPersonAddressCountryKey);
                if (country) {
                    cardParams[@"address_country"] = country;
                }
                CFRelease(dict);
                payload[@"card"] = cardParams;
            }
            CFRelease(addressValues);
        }
    }

    NSString *paymentInstrumentName = payment.token.paymentInstrumentName;
    if (paymentInstrumentName) {
        payload[@"pk_token_instrument_name"] = paymentInstrumentName;
    }

    NSString *paymentNetwork = payment.token.paymentNetwork;
    if (paymentNetwork) {
        payload[@"pk_token_payment_network"] = paymentNetwork;
    }

    NSString *transactionIdentifier = payment.token.transactionIdentifier;
    if (transactionIdentifier) {
        if ([payment stp_isSimulated]) {
            transactionIdentifier = [PKPayment stp_testTransactionIdentifier];
        }
        payload[@"pk_token_transaction_id"] = transactionIdentifier;
    }
    return payload;
}
#pragma clang diagnostic pop

@end

void linkSTPAPIClientApplePayCategory(void){}
