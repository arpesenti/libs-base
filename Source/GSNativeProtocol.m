#import "GSNativeProtocol.h"


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

  //TODO
}

@end


