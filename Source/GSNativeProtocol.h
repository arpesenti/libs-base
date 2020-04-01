#ifndef	INCLUDED_GSNATIVEPROTOCOL_H
#define	INCLUDED_GSNATIVEPROTOCOL_H

#import <Foundation/Foundation.h>

#import "GSEasyHandle.h"

@class GSTransferState;

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

typedef NS_ENUM(NSUInteger, GSNativeProtocolInternalState) {
    GSNativeProtocolInternalStateInitial,
    GSNativeProtocolInternalStateFulfillingFromCache,
    GSNativeProtocolInternalStateTransferReady,
    GSNativeProtocolInternalStateTransferInProgress,
    GSNativeProtocolInternalStateTransferCompleted,
    GSNativeProtocolInternalStateTransferFailed,
    GSNativeProtocolInternalStateWaitingForRedirectCompletionHandler,
    GSNativeProtocolInternalStateWaitingForResponseCompletionHandler,
    GSNativeProtocolInternalStateTaskCompleted,
};

@interface GSNativeProtocol : NSURLProtocol <GSEasyHandleDelegate>
{
  GSEasyHandle                   *_easyHandle;
  GSNativeProtocolInternalState  _internalState;
  GSTransferState                *_transferState;
}

- (void) setInternalState: (GSNativeProtocolInternalState)newState;

- (void) failWithError: (NSError*)error request: (NSURLRequest*)request;

- (void) completeTaskWithError: (NSError*)error;

- (void) completeTask;

- (void) startNewTransferWithRequest: (NSURLRequest*)request;

@end

#endif