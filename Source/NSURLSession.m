#import <Foundation/NSURLSession.h>

@implementation NSURLSession

+ (NSURLSession *) sessionWithConfiguration: (NSURLSessionConfiguration*)configuration 
                                   delegate: (id <NSURLSessionDelegate>)delegate 
                              delegateQueue: (NSOperationQueue*)queue
{
  //TODO
  return nil;
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
  //TODO
}

- (void) invalidateAndCancel
{
  //TODO
}

- (NSURLSessionDataTask*) dataTaskWithRequest: (NSURLRequest*)request
{
  //TODO
  return nil;
}

- (NSURLSessionDataTask*) dataTaskWithURL: (NSURL*)url
{
  //TODO
  return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
  //TODO
  return self;
}

@end

@implementation NSURLSessionTask

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
  //TODO
}

- (void) suspend
{
  //TODO
}

- (void) resume
{
  //TODO
}

- (id) copyWithZone: (NSZone*)zone
{
  //TODO
  return self;
}

@end

@implementation NSURLSessionDataTask

@end

@implementation NSURLSessionConfiguration

- (id) copyWithZone: (NSZone*)zone
{
  //TODO
  return self;
}

@end
