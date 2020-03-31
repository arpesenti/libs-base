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

@implementation GSCompletionAction

- (void) dealloc
{
  DESTROY(_redirectRequest);
  [super dealloc];
}

- (GSCompletionActionType) type
{
  return _type;
}

- (void) setType: (GSCompletionActionType) type
{
  _type = type;
}

- (int) errorCode
{
  return _errorCode;
}

- (void) setErrorCode: (int)code
{
  _errorCode = code;
}

- (NSURLRequest*) redirectRequest
{
  return _redirectRequest;
}

- (void) setRedirectRequest: (NSURLRequest*)request
{
  ASSIGN(_redirectRequest, request);
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
      [self completeTaskWithError: [task error]];
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

- (void) resume
{
  //TODO
}

- (void) suspend
{
  //TODO
}

- (void) completeTaskWithError: (NSError*)error
{
  //TODO
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

- (void) notifyDelegateAboutReceivedData: (NSData*)data
{
  NSURLSessionTask              *task;
  id<NSURLSessionDelegate>      delegate;

  task = [self task];

  NSAssert(nil != task, @"Cannot notify");

  delegate = [[task session] delegate];
  if (nil != delegate
    && [task isKindOfClass: [NSURLSessionDataTask class]]
    && [delegate respondsToSelector: @selector(URLSession:dataTask:didReceiveData:)])
    {
      id<NSURLSessionDataDelegate> dataDelegate;
      NSURLSessionDataTask         *dataTask;
      NSURLSession                 *session;

      session = [task session];
      NSAssert(nil != session, @"Missing session");
      dataDelegate = (id<NSURLSessionDataDelegate>)delegate;
      dataTask = (NSURLSessionDataTask*)task;
      [[session delegateQueue] addOperationWithBlock:
        ^{
          [dataDelegate URLSession: session 
                          dataTask: dataTask 
                    didReceiveData: data];
        }];
    }
}

- (void) notifyDelegateAboutUploadedDataCount: (int64_t)count 
{
  NSURLSessionTask              *task;
  id<NSURLSessionDelegate>      delegate;

  task = [self task];

  NSAssert(nil != task, @"Cannot notify");

  delegate = [[task session] delegate];
  if (nil != delegate
    && [task isKindOfClass: [NSURLSessionUploadTask class]]
    && [delegate respondsToSelector: @selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)])
    {
      id<NSURLSessionTaskDelegate> taskDelegate;
      NSURLSession                 *session;

      session = [task session];
      NSAssert(nil != session, @"Missing session");
      taskDelegate = (id<NSURLSessionTaskDelegate>)delegate;
      [[session delegateQueue] addOperationWithBlock:
        ^{
          [taskDelegate URLSession: session
                              task: task
                   didSendBodyData: count
                    totalBytesSent: [task countOfBytesSent]
          totalBytesExpectedToSend: [task countOfBytesExpectedToSend]];
        }];
    }
}

- (GSEasyHandleAction) didReceiveHeaderData: (NSData*)data 
                              contentLength: (int64_t)contentLength
{
  NSAssert(NO, @"Require concrete implementation");
  return GSEasyHandleActionAbort;
}

- (void) fillWriteBufferLength: (NSInteger)length
                        result: (void (^)(GSEasyHandleWriteBufferResult result, NSInteger length, NSData *data))result
{
  id<GSURLSessionTaskBodySource> source;

  NSAssert(GSNativeProtocolInternalStateTransferInProgress == _internalState,
    @"Requested to fill write buffer, but transfer isn't in progress.");
  
  source = [_transferState requestBodySource];

  NSAssert(nil != source, 
    @"Requested to fill write buffer, but transfer state has no body source.");

  if (nil == result) 
    {
      return;
    }

  [source getNextChunkWithLength: length
    completionHandler: ^(GSBodySourceDataChunk chunk, NSData *_Nullable data) 
      {
        switch (chunk) 
          {
            case GSBodySourceDataChunkData: 
              {
                NSUInteger count = [data length];
                [self notifyDelegateAboutUploadedDataCount: (int64_t)count];
                result(GSEasyHandleWriteBufferResultBytes, count, data);
                break;
              }
            case GSBodySourceDataChunkDone:
              result(GSEasyHandleWriteBufferResultBytes, 0, nil);
              break;
            case GSBodySourceDataChunkRetryLater:
              result(GSEasyHandleWriteBufferResultPause, -1, nil);
              break;
            case GSBodySourceDataChunkError:
              result(GSEasyHandleWriteBufferResultAbort, -1, nil);
              break;
          }
      }];
}

- (void) transferCompletedWithError: (NSError*)error
{
  NSURLRequest        *request;
  NSURLResponse       *response;
  GSCompletionAction  *action;

  if (nil != error) 
    {
      [self setInternalState: GSNativeProtocolInternalStateTransferFailed];
      [self failWithError: error request: [self request]];
      return;
    }

  NSAssert(_internalState == GSNativeProtocolInternalStateTransferInProgress, 
    @"Transfer completed, but it wasn't in progress.");

  request = [[self task] currentRequest];
  NSAssert(nil != request,
    @"Transfer completed, but there's no current request.");

  if (nil != [[self task] response]) 
    {
      [_transferState setResponse: [[self task] response]];
    }

  response = [_transferState response];
  NSAssert(nil != response, @"Transfer completed, but there's no response.");

  [self setInternalState: GSNativeProtocolInternalStateTransferCompleted];
  
  action = [self completeActionForCompletedRequest: request response: response];
  switch ([action type])
    {
      case GSCompletionActionTypeCompleteTask:
        [self completeTask];
        break;
      case GSCompletionActionTypeFailWithError:
        [self setInternalState: GSNativeProtocolInternalStateTransferFailed];
        error = [NSError errorWithDomain: NSURLErrorDomain 
                                    code: [action errorCode] 
                                userInfo: nil]; 
        [self failWithError: error request: request];
        break;
      case GSCompletionActionTypeRedirectWithRequest:
        [self redirectForRequest: [action redirectRequest]];
        break;
    }
}

- (GSCompletionAction*) completeActionForCompletedRequest: (NSURLRequest*)request
                                                 response: (NSURLResponse*)response
{
  GSCompletionAction  *action;

  action = AUTORELEASE([[GSCompletionAction alloc] init]);
  [action setType: GSCompletionActionTypeCompleteTask];

  return action;
}

- (void) completeTask
{
  //TODO
}

- (void) redirectForRequest: (NSURLRequest*)request
{
  NSAssert(NO, @"Require concrete implementation");
}

- (void) failWithError: (NSError*)error request: (NSURLRequest*)request
{
  //TODO
}

- (BOOL) seekInputStreamToPosition: (uint64_t)position
{
  //TODO
  return NO;
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


