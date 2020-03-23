#import <Foundation/NSURLSession.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/Foundation.h>


@interface NSURLSession()
- (NSOperationQueue*) workQueue;
@end

@interface NSURLSessionTask()
- (instancetype) initWithSession: (NSURLSession*)session
                         request: (NSURLRequest*)request
                  taskIdentifier: (NSUInteger)identifier;

- (NSURLProtocol*) protocol;

- (NSURLSession*) session;

- (void) setState: (NSURLSessionTaskState)state;

- (void) invalidateProtocol;

- (void) setResponse: (NSURLResponse*)response;
@end

@interface NSURLSessionTask (URLProtocolClient) <NSURLProtocolClient>

@end

typedef NS_ENUM(NSUInteger, NSURLSessionTaskProtocolState) {
  NSURLSessionTaskProtocolStateToBeCreated = 0,    
  NSURLSessionTaskProtocolStateExisting = 1,  
  NSURLSessionTaskProtocolStateInvalidated = 2,  
};

@interface NSOperationQueue (SynchronousBlock)

- (void) addSynchronousOperationWithBlock: (GSBlockOperationBlock)block;

@end

@implementation NSOperationQueue (SynchronousBlock)

- (void) addSynchronousOperationWithBlock: (GSBlockOperationBlock)block
{
  NSBlockOperation *bop = [NSBlockOperation blockOperationWithBlock: block];
  NSArray *ops = [NSArray arrayWithObject: bop];
  [self addOperations: ops waitUntilFinished: YES];
}

@end

@implementation NSURLSession
{
  NSOperationQueue     *_workQueue;
  NSUInteger           _nextTaskIdentifier;
  NSMutableDictionary  *_tasks; /* task identifier -> task */
  BOOL                 _invalidated;
}

+ (NSURLSession *) sessionWithConfiguration: (NSURLSessionConfiguration*)configuration 
                                   delegate: (id <NSURLSessionDelegate>)delegate 
                              delegateQueue: (NSOperationQueue*)queue
{
  NSURLSession *session;

  session = [[NSURLSession alloc] initWithConfiguration: configuration 
                                               delegate: delegate 
                                          delegateQueue: queue];

  return AUTORELEASE(session);
}

- (instancetype) initWithConfiguration: (NSURLSessionConfiguration*)configuration 
                              delegate: (id <NSURLSessionDelegate>)delegate 
                         delegateQueue: (NSOperationQueue*)queue
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_configuration, configuration);
      _delegate = delegate; 
      ASSIGN(_delegateQueue, queue);
      _workQueue = [[NSOperationQueue alloc] init];
      [_workQueue setMaxConcurrentOperationCount: 1];
      _nextTaskIdentifier = 0;
      ASSIGN(_tasks, [NSMutableDictionary dictionary]);
      _invalidated = NO;
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_configuration);
  DESTROY(_delegateQueue);
  DESTROY(_workQueue);
  DESTROY(_tasks);
  [super dealloc];
}

- (NSOperationQueue*) delegateQueue
{
  return _delegateQueue;
}

- (id <NSURLSessionDelegate>) delegate
{
  return _delegate;
}

- (NSURLSessionConfiguration*) configuration
{
  return _configuration;
}

- (NSString*) sessionDescription
{
  return _sessionDescription;
}

- (void) setSessionDescription: (NSString*)sessionDescription
{
  ASSIGN(_sessionDescription, sessionDescription);
}

- (void) finishTasksAndInvalidate
{
  [_workQueue addOperationWithBlock: 
    ^{
      _invalidated = YES;
      
      //TODO wait for tasks to finish

      if (nil == _delegate)
        {
          return;
        }

      [_delegateQueue addOperationWithBlock: 
        ^{
          if ([_delegate respondsToSelector: @selector(URLSession:didBecomeInvalidWithError:)])
            {
              [_delegate URLSession: self didBecomeInvalidWithError: nil];
              _delegate = nil;
            }
        }];
    }];
}

- (void) invalidateAndCancel
{
  NSEnumerator      *e;
  NSNumber          *identifier;
  NSURLSessionTask  *task;

  [_workQueue addSynchronousOperationWithBlock: 
    ^{
      _invalidated = YES;
    }];

  e = [_tasks keyEnumerator];
  while (nil != (identifier = [e nextObject]))
    {
      task = [_tasks objectForKey: identifier];
      [task cancel];
    }

  [_workQueue addOperationWithBlock: 
    ^{
      if (nil == _delegate)
        {
          return;
        }
      
      [_delegateQueue addOperationWithBlock: 
        ^{
          if ([_delegate respondsToSelector: @selector(URLSession:didBecomeInvalidWithError:)])
            {
              [_delegate URLSession: self didBecomeInvalidWithError: nil];
              _delegate = nil;
            }
        }];
    }];
}

- (NSURLSessionDataTask*) dataTaskWithRequest: (NSURLRequest*)request
{
  NSURLSessionDataTask  *task;

  if (_invalidated)
    {
      return nil;
    }

  task = [[NSURLSessionDataTask alloc] initWithSession: self 
                                               request: request 
                                        taskIdentifier: _nextTaskIdentifier++];

  [self addTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDataTask*) dataTaskWithURL: (NSURL*)url
{
  NSMutableURLRequest *request;
  
  request = [NSMutableURLRequest requestWithURL: url];
  [request setHTTPMethod: @"POST"];

  return [self dataTaskWithRequest: request];
}

- (void) addTask: (NSURLSessionTask*)task
{
  NSNumber  *identifier;

  identifier = [NSNumber numberWithUnsignedInteger: [task taskIdentifier]];
  [_tasks setObject: task forKey: identifier];
}

- (void) removeTask: (NSURLSessionTask*)task
{
  NSNumber  *identifier;

  identifier = [NSNumber numberWithUnsignedInteger: [task taskIdentifier]];
  [_tasks removeObjectForKey: identifier];
}

- (NSOperationQueue*) workQueue
{
  return _workQueue;
}

@end

@interface _NSURLProtocolClient : NSObject <NSURLProtocolClient>
{
  NSURLRequestCachePolicy  _cachePolicy;
  NSMutableArray           *_cacheableData;
  NSURLResponse            *_cacheableResponse;
}
@end

@implementation _NSURLProtocolClient

- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _cachePolicy = NSURLCacheStorageNotAllowed;
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_cacheableData);
  DESTROY(_cacheableResponse);
  [super dealloc];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{

}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
  NSURLSessionTask  *task = [protocol task];

  NSAssert(nil != task, @"Missing task");

  [self task: task didFailWithError: error];
}

- (void) task: (NSURLSessionTask *)task
    didFailWithError: (NSError *)error
{
  NSURLSession                  *session;
  NSOperationQueue              *delegateQueue;
  id<NSURLSessionDelegate>      delegate;

  session = [task session];
  NSAssert(nil != session, @"Missing session");

  delegateQueue = [session delegateQueue];
  delegate = [session delegate];

  if (nil != delegate)
    {
      [delegateQueue addOperationWithBlock: 
        ^{
          if (NSURLSessionTaskStateCompleted == [task state])
            {
              return;
            }

          if ([delegate respondsToSelector: @selector(URLSession:task:didCompleteWithError:)])
            {
              [(id<NSURLSessionTaskDelegate>)delegate URLSession: session 
                                                            task: task 
                                            didCompleteWithError: error];
            }

          [task setState: NSURLSessionTaskStateCompleted];
          [[session workQueue] addOperationWithBlock: 
            ^{
              [session removeTask: task];
            }];
        }];
    }
  else
    {
      if (NSURLSessionTaskStateCompleted == [task state])
        {
          return;
        }

      [task setState: NSURLSessionTaskStateCompleted];
      [[session workQueue] addOperationWithBlock: 
        ^{
          [session removeTask: task];
        }];
    }
  
  [task invalidateProtocol];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
	       didLoadData: (NSData *)data
{
  NSURLSessionTask          *task = [protocol task];
  NSURLSession              *session;
  NSOperationQueue          *delegateQueue;
  id<NSURLSessionDelegate>  delegate;

  NSAssert(nil != task, @"Missing task");

  session = [task session];
  delegate = [session delegate];
  delegateQueue = [session delegateQueue];

  switch (_cachePolicy)
    {
      case NSURLCacheStorageAllowed:
      case NSURLCacheStorageAllowedInMemoryOnly:
        {
          if (nil != _cacheableData)
            {
              [_cacheableData addObject: data];
            }
          break;
        }
      case NSURLCacheStorageNotAllowed:
        break;
    }

  if (nil != delegate 
    && [task isKindOfClass: [NSURLSessionDataTask class]]
    && [delegate respondsToSelector: @selector(URLSession:dataTask:didReceiveData:)])
    {
      [delegateQueue addOperationWithBlock:
       ^{
         [(id<NSURLSessionDataDelegate>)delegate URLSession: session 
                                                   dataTask: (NSURLSessionDataTask*)task 
                                             didReceiveData: data];
       }];
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  //FIXME
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
  NSURLSessionTask          *task = [protocol task];
  NSURLSession              *session;

  NSAssert(nil != task, @"Missing task");

  [task setResponse: response];

  session = [task session];

  if (![task isKindOfClass: [NSURLSessionDataTask class]])
    {
      return;
    }

  _cachePolicy = policy;

  if (nil != [[session configuration] URLCache])
    {
      switch (policy)
        {
          case NSURLCacheStorageAllowed:
          case NSURLCacheStorageAllowedInMemoryOnly:
            ASSIGN(_cacheableData, [NSMutableArray array]);
            ASSIGN(_cacheableResponse, response);
            break;
          case NSURLCacheStorageNotAllowed:
            break;
        }
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  wasRedirectedToRequest: (NSURLRequest *)request
  redirectResponse: (NSURLResponse *)redirectResponse
{
  NSAssert(NO, @"The NSURLSession implementation doesn't currently handle redirects directly.");
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol
{
  NSURLSessionTask          *task = [protocol task];
  NSURLSession              *session;
  NSURLResponse             *urlResponse;
  NSURLCache                *cache;
  NSOperationQueue          *delegateQueue;
  id<NSURLSessionDelegate>  delegate;

  NSAssert(nil != task, @"Missing task");

  session = [task session];
  urlResponse = [task response];
  delegate = [session delegate];
  delegateQueue = [session delegateQueue];

  if (nil != (cache = [[session configuration] URLCache])
    && [task isKindOfClass: [NSURLSessionDataTask class]]
    && nil != _cacheableData
    && nil != _cacheableResponse)
    {
      NSCachedURLResponse  *cacheable;
      NSMutableData        *data;
      NSEnumerator         *e;
      NSData               *d;

      data = [NSMutableData data];
      e = [_cacheableData objectEnumerator];
      while (nil != (d = [e nextObject]))
        {
          [data appendData: d];
        }

      cacheable = [[NSCachedURLResponse alloc] initWithResponse: urlResponse 
                                                           data: data 
                                                       userInfo: nil 
                                                  storagePolicy: _cachePolicy];
      [cache storeCachedResponse: cacheable 
                     forDataTask: (NSURLSessionDataTask*)task];
      RELEASE(cacheable);
    }

  if (nil != delegate)
    {
      [delegateQueue addOperationWithBlock: 
        ^{
          if (NSURLSessionTaskStateCompleted == [task state])
            {
              return;
            }
          
          if ([delegate respondsToSelector: @selector(URLSession:task:didCompleteWithError:)])
            {
              [(id<NSURLSessionTaskDelegate>)delegate URLSession: session 
                                                            task: task 
                                            didCompleteWithError: nil];
            }
          
          [task setState: NSURLSessionTaskStateCompleted];

          [[session workQueue] addOperationWithBlock: 
            ^{
              [session removeTask: task];
            }];
        }];
    }
  else
    {
      if (NSURLSessionTaskStateCompleted != [task state])
        {
          [task setState: NSURLSessionTaskStateCompleted];
          [[session workQueue] addOperationWithBlock: 
            ^{
              [session removeTask: task];
            }];
        }
    }

  [task invalidateProtocol];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  //FIXME
}

@end

@implementation NSURLSessionTask
{
  NSURLSession                   *_session; /* not retained */
  NSOperationQueue               *_workQueue;
  NSUInteger                     _suspendCount;
  NSLock                         *_protocolLock;
  NSURLSessionTaskProtocolState  _protocolState;
  NSURLProtocol                  *_protocol;
  Class                          _protocolClass;
}

- (instancetype) initWithSession: (NSURLSession*)session
                         request: (NSURLRequest*)request
                  taskIdentifier: (NSUInteger)identifier
{
  NSEnumerator  *e;
  Class         protocolClass;

  if (nil != (self = [super init]))
    {
      _session = session;
      ASSIGN(_originalRequest, request);
      ASSIGN(_currentRequest, request);
      _taskIdentifier = identifier;
      _workQueue = [[NSOperationQueue alloc] init];
      [_workQueue setMaxConcurrentOperationCount: 1];
      _state = NSURLSessionTaskStateSuspended;
      _suspendCount = 1;
      _protocolLock = [[NSLock alloc] init];
      _protocolState = NSURLSessionTaskProtocolStateToBeCreated;
      _protocol = nil;
      e = [[[session configuration] protocolClasses] objectEnumerator];
      while (nil != (protocolClass = [e nextObject]))
        {
          if ([protocolClass canInitWithRequest: request])
            {
              _protocolClass = protocolClass;
            }
        }
      NSAssert(nil != _protocolClass, @"Unsupported protocol");      
    }
  
  return self;
}

- (void) dealloc
{
  DESTROY(_originalRequest);
  DESTROY(_currentRequest);
  DESTROY(_response);
  DESTROY(_taskDescription);
  DESTROY(_error);
  DESTROY(_workQueue);
  DESTROY(_protocolLock);
  [super dealloc];
}

- (NSURLSessionTaskState) updateTaskState
{
  if (0 == _suspendCount)
    {
      _state = NSURLSessionTaskStateRunning;
    }
  else
    {
      _state = NSURLSessionTaskStateSuspended;
    }
  
  return _state;
}

- (NSUInteger) taskIdentifier
{
  return _taskIdentifier;
}

- (NSURLRequest*) originalRequest
{
  return _originalRequest;
}

- (NSURLRequest*) currentRequest
{
  return _currentRequest;
}

- (NSURLResponse*) response
{
  return _response;
}

- (int64_t) countOfBytesReceived
{
  return _countOfBytesReceived;
}

- (int64_t) countOfBytesSent
{
  return _countOfBytesSent;
}

- (int64_t) countOfBytesExpectedToSend
{
  return _countOfBytesExpectedToSend;
}

- (int64_t) countOfBytesExpectedToReceive
{
  return _countOfBytesExpectedToReceive;
}

- (NSString*) taskDescription
{
  return _taskDescription;
}

- (void) setTaskDescription: (NSString*)taskDescription
{
  ASSIGN(_taskDescription, taskDescription);
}

- (NSURLSessionTaskState) state
{
  return _state;
}

- (NSError*) error
{
  return _error;
}

- (void) cancel
{
  [_workQueue addSynchronousOperationWithBlock: 
    ^{
      if (!(NSURLSessionTaskStateRunning == _state
        || NSURLSessionTaskStateSuspended == _state))
        {
          return;
        }

      _state = NSURLSessionTaskStateCanceling;

      NSURLProtocol  *protocol;

      protocol = [self protocol];

      [_workQueue addOperationWithBlock:
        ^{
          _error = [[NSError alloc] initWithDomain: NSURLErrorDomain 
                                              code: NSURLErrorCancelled 
                                          userInfo: nil];
          if (nil != protocol)
            {
              id<NSURLProtocolClient> client;

              [protocol stopLoading];
              if (nil != (client = [protocol client]))
                {
                  [client URLProtocol: protocol didFailWithError: _error];
                }
            }
        }];
    }];
}

- (void) suspend
{
  [_workQueue addSynchronousOperationWithBlock: 
    ^{
      if (NSURLSessionTaskStateCanceling == _state
        || NSURLSessionTaskStateCompleted == _state)
        {
          return;
        }

      _suspendCount++;

      [self updateTaskState];

      if (1 == _suspendCount)
        {
          NSURLProtocol  *protocol;

          protocol = [self protocol];

          [_workQueue addOperationWithBlock: 
            ^{
              if (nil != protocol)
                {
                  [protocol stopLoading];
                }
            }];
        }    
    }];
}

- (void) resume
{
  [_workQueue addSynchronousOperationWithBlock: 
    ^{
      if (NSURLSessionTaskStateCanceling == _state
        || NSURLSessionTaskStateCompleted == _state)
        {
          return;
        }

      if (_suspendCount > 0)
        {
          _suspendCount--;
        }

      [self updateTaskState];

      if (0 == _suspendCount)
        {
          NSURLProtocol  *protocol;
          
          protocol = [self protocol];

          [_workQueue addOperationWithBlock: 
            ^{
              if (nil != protocol)
                {
                  [protocol startLoading];
                }
              else if (nil == _error)
                {
                  NSDictionary          *userInfo;
                  _NSURLProtocolClient  *client;

                  userInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
                    [_originalRequest URL], NSURLErrorFailingURLErrorKey,
                    [[_originalRequest URL] absoluteString], NSURLErrorFailingURLStringErrorKey,
                    nil];
                  _error = [[NSError alloc] initWithDomain: NSURLErrorDomain 
                                                      code: NSURLErrorUnsupportedURL 
                                                  userInfo: userInfo];
                  client = [[_NSURLProtocolClient alloc] init];
                  [client task: self didFailWithError: _error];
                }
            }];
        }
    }];
}

- (id) copyWithZone: (NSZone*)zone
{
  NSURLSessionTask *copy = [[[self class] alloc] init];

  if (copy) 
    {
      copy->_taskIdentifier = _taskIdentifier;
      copy->_originalRequest = [_originalRequest copyWithZone: zone];
      copy->_currentRequest = [_currentRequest copyWithZone: zone];
      copy->_response = [_response copyWithZone: zone];
      copy->_countOfBytesReceived = _countOfBytesReceived;
      copy->_countOfBytesSent = _countOfBytesSent;
      copy->_countOfBytesExpectedToSend = _countOfBytesExpectedToSend;
      copy->_countOfBytesExpectedToReceive = _countOfBytesExpectedToReceive;
      copy->_taskDescription = [_taskDescription copyWithZone: zone];
      copy->_state = _state;
      copy->_error = [_error copyWithZone: zone];
      copy->_session = _session;
      copy->_workQueue = _workQueue;
      copy->_suspendCount  = _suspendCount;
      copy->_protocolLock = [_protocolLock copy];
    }

  return copy;
}

- (NSURLProtocol*) protocol
{
  NSURLProtocol  *protocol;

  [_protocolLock lock];

  switch (_protocolState)
    {
      case NSURLSessionTaskProtocolStateToBeCreated:
        {
          NSURLCache           *cache;
          NSCachedURLResponse  *response;

          if (nil != (cache = [[_session configuration] URLCache]))
            {
              response = [cache cachedResponseForRequest: _currentRequest];
              _protocol = [[_protocolClass alloc] initWithTask: self 
                                                cachedResponse: response 
                                                        client: nil];
            }
          else
            {
              _protocol = [[_protocolClass alloc] initWithTask: self 
                                                cachedResponse: nil 
                                                        client: nil];
            }
          _protocolState = NSURLSessionTaskProtocolStateExisting;
          protocol = _protocol;
          break;
        } 
      case NSURLSessionTaskProtocolStateExisting:
        protocol = _protocol;
        break;
      case NSURLSessionTaskProtocolStateInvalidated:
        protocol = nil;
        break;    
    }

  [_protocolLock unlock];

  return protocol;
}

- (NSURLSession*) session 
{
  return _session;
}

- (void) setState: (NSURLSessionTaskState)state
{
  _state = state;
}

- (void) invalidateProtocol
{
  [_protocolLock lock];
  _protocolState = NSURLSessionTaskProtocolStateInvalidated;
  DESTROY(_protocol);
  [_protocolLock unlock];
}

- (void) setResponse: (NSURLResponse*)response
{
  ASSIGN(_response, response);
}

@end

@implementation NSURLSessionDataTask

@end

@implementation NSURLSessionConfiguration

- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _protocolClasses = [NSArray arrayWithObjects: nil]; //TODO add HTTP protocol class
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_URLCache);
  DESTROY(_protocolClasses);
  [super dealloc];
}

- (NSURLCache*) URLCache
{
  return _URLCache;
}

- (void) setURLCache: (NSURLCache*)cache
{
  ASSIGN(_URLCache, cache);
}

- (NSURLRequestCachePolicy) requestCachePolicy
{
  return _requestCachePolicy;
}

- (void) setRequestCachePolicy: (NSURLRequestCachePolicy)policy
{
  _requestCachePolicy = policy;
}

- (NSArray*) protocolClasses
{
  return _protocolClasses;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSURLSessionConfiguration *copy = [[[self class] alloc] init];

  if (copy) 
    {
      copy->_URLCache = [_URLCache copy];
      copy->_protocolClasses = [_protocolClasses copyWithZone: zone];
    }

  return copy;
}

@end
