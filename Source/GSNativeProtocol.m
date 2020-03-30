#import "GSNativeProtocol.h"
#import "GSTransferState.h"


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

static BOOL isEasyHandlePaused(GSNativeProtocolInternalState state)
{
  switch (state)
    {
      case GSNativeProtocolInternalStateInitial:
        return NO;
      case GSNativeProtocolInternalStateFulfillingFromCache:
        return NO;
      case GSNativeProtocolInternalStateTransferReady:
        return NO;
      case GSNativeProtocolInternalStateTransferInProgress:
        return NO;
      case GSNativeProtocolInternalStateTransferCompleted:
        return NO;
      case GSNativeProtocolInternalStateTransferFailed:
        return NO;
      case GSNativeProtocolInternalStateWaitingForRedirectCompletionHandler:
        return NO;
      case GSNativeProtocolInternalStateWaitingForResponseCompletionHandler:
        return YES;
      case GSNativeProtocolInternalStateTaskCompleted:
        return NO;
    }
}

static BOOL isEasyHandleAddedToMultiHandle(GSNativeProtocolInternalState state)
{
  switch (state)
    {
      case GSNativeProtocolInternalStateInitial:
        return NO;
      case GSNativeProtocolInternalStateFulfillingFromCache:
        return NO;
      case GSNativeProtocolInternalStateTransferReady:
        return NO;
      case GSNativeProtocolInternalStateTransferInProgress:
        return YES;
      case GSNativeProtocolInternalStateTransferCompleted:
        return NO;
      case GSNativeProtocolInternalStateTransferFailed:
        return NO;
      case GSNativeProtocolInternalStateWaitingForRedirectCompletionHandler:
        return NO;
      case GSNativeProtocolInternalStateWaitingForResponseCompletionHandler:
        return YES;
      case GSNativeProtocolInternalStateTaskCompleted:
        return NO;
    }
}

@interface NSURLSession (Internal)

- (void) removeHandle: (GSEasyHandle*)handle;

- (void) addHandle: (GSEasyHandle*)handle;

@end

@implementation NSURLSession (Internal)

- (void) removeHandle: (GSEasyHandle*)handle
{
  [_multiHandle removeHandle: handle];
}

- (void) addHandle: (GSEasyHandle*)handle
{
  [_multiHandle addHandle: handle];
}

@end

@implementation GSNativeProtocol
{
  GSEasyHandle                   *_easyHandle;
  GSNativeProtocolInternalState  _internalState;
  GSTransferState                *_transferState;
}

- (instancetype) initWithTask: (NSURLSessionTask*)task 
               cachedResponse: (NSCachedURLResponse*)cachedResponse 
                       client: (id<NSURLProtocolClient>)client 
{
  if (nil != (self = [super initWithTask: task 
                          cachedResponse: cachedResponse 
                                  client: client]))
    {
      _internalState = GSNativeProtocolInternalStateInitial;
      _easyHandle = [[GSEasyHandle alloc] initWithDelegate: self];
    }
    
  return self;
}

- (instancetype) initWithRequest: (NSURLRequest*)request 
                  cachedResponse: (NSCachedURLResponse*)cachedResponse 
                          client: (id<NSURLProtocolClient>)client 
{
  if (nil != (self = [super initWithRequest: request 
                             cachedResponse: cachedResponse 
                                     client: client]))
    {
      _internalState = GSNativeProtocolInternalStateInitial;
      _easyHandle = [[GSEasyHandle alloc] initWithDelegate: self];
    }
    
  return self;
}

- (void) dealloc
{
  DESTROY(_easyHandle);
  [super dealloc];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*)request 
{
  return request;
}

- (void) startLoading 
{
  [self resume];
}

- (void) stopLoading 
{
  NSURLSessionTask  *task;

  if (nil != (task = [self task])
    &&  NSURLSessionTaskStateSuspended == [task state])
    {
      [self suspend];
    }
  else
    {
      [self setInternalState: GSNativeProtocolInternalStateTransferFailed];
      NSAssert(nil != [task error], @"Missing error for failed task");
      [self completeTask: [task error]];
    }
}

- (void) setInternalState: (GSNativeProtocolInternalState)newState
{
  NSURLSessionTask               *task;
  GSNativeProtocolInternalState  oldState;

  if (!isEasyHandlePaused(_internalState) && isEasyHandlePaused(newState))
    {
      NSAssert(NO, @"Need to solve pausing receive.");
    }
  
  if (isEasyHandleAddedToMultiHandle(_internalState) 
    && !isEasyHandleAddedToMultiHandle(newState))
    {
      if (nil != (task = [self task]))
        {
          [[task session] removeHandle: _easyHandle];
        }
    }
  
  oldState = _internalState;
  _internalState = newState;

  if (!isEasyHandleAddedToMultiHandle(oldState) 
    && isEasyHandleAddedToMultiHandle(_internalState))
    {
      if (nil != (task = [self task]))
        {
          [[task session] addHandle: _easyHandle];
        }
    }
  if (isEasyHandlePaused(oldState) && !isEasyHandlePaused(_internalState))
    {
      NSAssert(NO, @"Need to solve pausing receive.");
    }
}

- (GSEasyHandleAction) didReceiveData: (NSData*)data
{
  NSURLResponse  *response;

  NSAssert(GSNativeProtocolInternalStateTransferInProgress == _internalState,
    @"Received body data, but no transfer in progress.");

  response = [self validateHeaderCompleteTransferState: _transferState];

  if (nil != response)
    {
      [_transferState setResponse: response];
    }

  [self notifyDelegateAboutReceivedData: data];

  _internalState = GSNativeProtocolInternalStateTransferInProgress;
  ASSIGN(_transferState, [_transferState byAppendingBodyData: data]);

  return GSEasyHandleActionProceed;
}

- (NSURLResponse*) validateHeaderCompleteTransferState: (GSTransferState*)ts 
{
  if (![ts isHeaderComplete]) 
    {
      NSAssert(NO, @"Received body data, but the header is not complete, yet.");
    }
  
  return nil;
}

- (GSEasyHandleAction) didReceiveHeaderData: (NSData*)data 
                              contentLength: (int64_t)contentLength
{
  //TODO
}

- (void) transferCompletedWithError: (NSError*)error
{
  //TODO
}

- (void) fillWriteBufferLength: (NSInteger)length
                        result: (void (^)(GSEasyHandleWriteBufferResult result, NSInteger length, NSData *data))result
{
  //TODO
}

- (BOOL) seekInputStreamToPosition: (uint64_t)position
{
  //TODO
}

- (void) needTimeoutTimerToValue: (NSInteger)value
{
  //TODO
}

- (void) updateProgressMeterWithTotalBytesSent: (int64_t)totalBytesSent 
                      totalBytesExpectedToSend: (int64_t)totalBytesExpectedToSend 
                            totalBytesReceived: (int64_t)totalBytesReceived 
                   totalBytesExpectedToReceive: (int64_t)totalBytesExpectedToReceive
{
  //TODO
}

@end


