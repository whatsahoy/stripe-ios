# Using Sources with the iOS SDK

Creating a payment using Sources with the iOS SDK is a multi-step process:

1. [Create an `STPSource` object](#create-an-stpsource-object) that represents the customer's payment method
2. [Check if further action is required](#check-if-further-action-is-required) from your customer

If no further action is required:

3. Confirm the source is ready to use
4. Tell your backend to create a charge request using the source

If further action is required:

3. Present the user with any information they may need to authorize the charge
4. In your backend, listen to Stripe webhooks to create a charge with the source
5. In your app, display the appropriate confirmation to your customer based on the source's status

## Create an STPSource object

Once you've collected your customer's payment details, you can use the `STPAPIClient` class to create a source. First, assemble an `STPSourceParams` object with the payment information you've collected. Then, pass this object to the `createSourceWithParams:` method in `STPAPIClient` to create a source. To create an `STPSourceParams` object, we recommend that you use one of the helper constructors we provide, which specify the information needed for each payment method.

For example, to create a source for a [Sofort](https://stripe.com/docs/sources/sofort) payment:

```
// Objective-C
STPSourceParams *sourceParams = [STPSourceParams sofortParamsWithAmount:1099
                                                              returnURL:@"payments-example://stripe-redirect"
                                                                country:@"DE"
                                                    statementDescriptor:@"ORDER AT11990"];
[[STPAPIClient sharedClient] createSourceWithParams:sourceParams completion:completionBlock];
```

```
// Swift
let sourceParams = STPSourceParams.sofortParams(withAmount: 1099,
                                                returnURL: "payments-example://stripe-redirect",
                                                country: "DE",
                                                statementDescriptor: "ORDER AT11990")
STPAPIClient.shared().createSource(with: sourceParams, completion: completionBlock)
```

## Check if further action is required from your customer

To determine whether further action is required from your customer, check the `flow` property on the newly created `STPSource` object. If `flow` is `STPSourceFlowNone`, no further action is required. For example, if you create a source for a card payment, its status is immediately set to `STPSourceStatusChargeable`. No additional customer action is needed, so you can tell your backend to create a charge with the source right away.

```
// Objective-C
STPCardParams *cardParams = [STPCardParams new];
cardParams.name = @"Jenny Rosen";
cardParams.number = @"4242424242424242";
cardParams.expMonth = 12;
cardParams.expYear = 18;
cardParams.cvc = @"123";

STPSourceParams *sourceParams = [STPSourceParams cardParamsWithCard:cardParams];

[[STPAPIClient sharedClient] createSourceWithParams:sourceParams
                                         completion:^(STPSource *source, NSError *error) {
                                             if (source.flow == STPSourceFlowNone
                                                 && source.status == STPSourceStatusChargeable) {
                                                 [self createBackendChargeWithSourceID:source.stripeID];
                                             }
                                         }];
```

```
// Swift
let cardParams = STPCardParams()
cardParams.name = "Jenny Rosen"
cardParams.number = "4242424242424242"
cardParams.expMonth = 12
cardParams.expYear = 18
cardParams.cvc = "424"

let sourceParams = STPSourceParams.cardParams(withCard: cardParams)
STPAPIClient.shared().createSource(with: sourceParams) { (source, error) in
    if let s = source, s.flow == .none && s.status == .chargeable {
        self.createBackendChargeWithSourceID(s.stripeID)
    }
}
```

If the source's flow is not `STPSourceFlowNone`, then your customer needs to complete an action before the source can be used in a charge request.

* `STPSourceFlowRedirect`
  * Your customer must be redirected to the payment method's website or app to confirm the charge. See the section below for more information.
* `STPSourceFlowReceiver`
  * Your customer must push funds to the account information provided in the Source object. See the documentation for the specific payment method you are using for more information.
* `STPSourceFlowVerification`
  * Your customer must verify ownership of their account by providing a code that you post to the Stripe API for authentication. See the documentation for the specific payment method you are using for more information.

If the source requires further action from your customer, your iOS app should _not_ tell your backend to create a charge request. Instead, your backend should listen for the `source.chargeable` webhook event to charge the source. This ensures that the source will be charged even if the user never returns to your app after taking the required action. You can refer to our [best practices](https://stripe.com/docs/sources#best-practices) for more information on supporting different payment methods using webhooks.

## Redirecting your customer to authorize a source

For sources that require redirecting your customer to authorize the payment, you'll need to specify a return URL when you create the source. This allows your customer to be redirected back to your app after they authorize the payment. For this return URL, you can either use a custom URL scheme or a universal link supported by your app. For more information on registering and handling URLs in your app, refer to the Apple documentation:

* [Implementing Custom URL Schemes](https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW10)
* [Supporting Universal Links](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html)

To handle redirecting your customer to the URL in the source object's `redirect.url` parameter, we recommend using `[UIApplication openURL:]`. Opening the URL in an in-app container like `STPSafariViewController` can prevent your customer's installed banking app from launching to complete authentication, resulting in a lower conversion rate.

When you redirect your customer to authorize the payment, we recommend that you start polling the source in order to display the appropriate confirmation status to your customer when they return to your app. `STPAPIClient`'s `startPollingSourceWithId` method will continuously fetch a source, and call its completion block once the source's status is no longer `pending`, or after the specified timeout length has been exceeded. Most sources will become `chargeable` within a few seconds of your customer authorizing the payment, but some may take longer, and it is always possible for your customer to return to your app without authorizing the payment. To avoid making your customer wait for too long for a confirmation after they return to your app, we recommend polling with a short timeout (e.g. 10 seconds).

While polling, be sure to update your app's UI in order to prevent your customer from making an additional payment. If the status of the source is still `pending` after polling for a short time, or if the status cannot be determined, it may be more appropriate for your app to simply tell the user that their order has been received. Once your backend creates a charge using the source, you can notify your customer that their order has been fulfilled (e.g. by sending an email or a push notification).

```
// Objective-C
STPAPIClient *stripeClient = [STPAPIClient sharedClient];
STPSourceParams *sourceParams = [STPSourceParams sofortParamsWithAmount:1099
                                                              returnURL:@"payments-example://stripe-redirect"
                                                                country:@"DE"
                                                    statementDescriptor:@"ORDER AT11990"];
[stripeClient createSourceWithParams:sourceParams completion:^(STPSource *source, NSError *error) {
    if (error) {
        [self handleError:error];
    } else {
        [[UIApplication sharedApplication] openURL:source.redirect.url];
        [self presentPollingUI];
        [stripeClient startPollingSourceWithId:source.stripeID clientSecret:source.clientSecret completion:^(STPSource *source, NSError *error) {
            [self dismissPollingUI];
            if (source && source.status == STPSourceStatusConsumed) {
                [self displayOrderConfirmation:@"Payment successfully created"];
            } else if (source && source.status == STPSourceStatusFailed) {
                [self displayOrderConfirmation:@"Payment failed"];
            } else {
              [self displayOrderConfirmation:@"Order received"];
            }
        }];
    }
}];
```

```
// Swift
let stripeClient = STPAPIClient.shared()
let sourceParams = STPSourceParams.sofortParams(withAmount: 1099,
                                                returnURL: "payments-example://stripe-redirect",
                                                country: "DE",
                                                statementDescriptor: "ORDER AT11990")
stripeClient.createSource(with: sourceParams) { (source, error) in
    if let e = error {
        self.handleError(e)
    } else if let s = source, let url = s.redirect?.url, let clientSecret = s.clientSecret {
        UIApplication.shared.openURL(url)
        self.presentPollingUI()
        stripeClient.startPollingSource(withId: s.stripeID, clientSecret: clientSecret, completion: { (source, error) in
            self.dismissPollingUI()
            if let s = source, s.status == .consumed {
                self.displayOrderConfirmation("Payment successfully created")
            } else if let s = source, s.status == .failed {
                self.displayOrderConfirmation("Payment failed")
            } else {
                self.displayOrderConfirmation("Order received")
            }
        })
    }
}
```

## More information

If you'd like more help, we provide an example app [0] that demonstrates creating a payment using several different payment methods.

[0] https://github.com/stripe/stripe-ios/tree/master/Example/Stripe%20iOS%20Example%20(Custom)
