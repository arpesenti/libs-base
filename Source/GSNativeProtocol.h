#ifndef	INCLUDED_GSNATIVEPROTOCOL_H
#define	INCLUDED_GSNATIVEPROTOCOL_H

#import <Foundation/Foundation.h>

#import "GSEasyHandle.h"

typedef NS_ENUM(NSUInteger, GSCompletionActionType) {
    GSCompletionActionTypeCompleteTask,
    GSCompletionActionTypeFailWithError,
    GSCompletionActionTypeRedirectWithRequest,
};

@interface GSCompletionAction : NSObject
{
  GSCompletionActionType _type;
  int                    _errorCode;
  NSURLRequest           *_redirectRequest;
}

- (GSCompletionActionType) type;
- (void) setType: (GSCompletionActionType) type;

- (int) errorCode;
- (void) setErrorCode: (int)code;

- (NSURLRequest*) redirectRequest;
- (void) setRedirectRequest: (NSURLRequest*)request;

@end

@interface GSNativeProtocol : NSURLProtocol <GSEasyHandleDelegate>

@end

#endif