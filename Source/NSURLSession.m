#import <Foundation/NSURLSession.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/Foundation.h>


@interface NSURLSessionTask()
- (instancetype) initWithSession: (NSURLSession*)session
                         request: (NSURLRequest*)request
                  taskIdentifier: (NSUInteger)identifier;
@end

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
  [_workQueue addOperationWithBlock: ^{
    _invalidated = YES;
    
    //TODO wait for tasks to finish

    if (nil == _delegate)
      {
        return;
      }

    [_delegateQueue addOperationWithBlock: ^{
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

  [_workQueue addSynchronousOperationWithBlock: ^{
    _invalidated = YES;
  }];

  e = [_tasks keyEnumerator];
  while (nil != (identifier = [e nextObject]))
    {
      task = [_tasks objectForKey: identifier];
      [task cancel];
    }

  [_workQueue addOperationWithBlock: ^{
    if (nil == _delegate)
      {
        return;
      }
    
    [_delegateQueue addOperationWithBlock: ^{
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

@end

@implementation NSURLSessionTask
{
  NSURLSession      *_session; /* not retained */
  NSOperationQueue  *_workQueue;
  NSUInteger        _suspendCount;
}

- (instancetype) initWithSession: (NSURLSession*)session
                         request: (NSURLRequest*)request
                  taskIdentifier: (NSUInteger)identifier
{
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
  [_workQueue addSynchronousOperationWithBlock: ^{
    if (!(NSURLSessionTaskStateRunning == _state
      || NSURLSessionTaskStateSuspended == _state))
      {
        return;
      }

    _state = NSURLSessionTaskStateCanceling;

    NSLog(@"Cancelling"); //TODO
  }];
}

- (void) suspend
{
  [_workQueue addSynchronousOperationWithBlock: ^{
    if (NSURLSessionTaskStateCanceling == _state
      || NSURLSessionTaskStateCompleted == _state)
      {
        return;
      }

    _suspendCount++;

    [self updateTaskState];

    if (1 == _suspendCount)
      {
        NSLog(@"Suspending"); //TODO
      }    
  }];
}

- (void) resume
{
  [_workQueue addSynchronousOperationWithBlock: ^{
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
          NSLog(@"Resuming"); //TODO
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
    }

  return copy;
}

@end

@implementation NSURLSessionDataTask

@end

@implementation NSURLSessionConfiguration

- (id) copyWithZone: (NSZone*)zone
{
  id copy = [[[self class] alloc] init];

  if (copy) 
    {
      
    }

  return copy;
}

@end
