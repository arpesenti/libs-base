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

@implementation GSHTTPMessageStartLine

+ (GSHTTPMessageStartLine*) startLineWithLine: (NSString*)line
{
  NSArray                 *array;
  NSString                *version;
  GSHTTPMessageStartLine  *startLine;
  
  array =  [line componentsSeparatedByCharactersInSet: 
    [NSCharacterSet whitespaceCharacterSet]];
  if (3 != [array count])
    {
      return nil;
    }
  
  if ([[array objectAtIndex: 0] hasPrefix: @"HTTP/"])
    {
      NSInteger  status;
      NSString   *reason;

      version = [array objectAtIndex: 0];
      status = [[array objectAtIndex: 1] integerValue];
      reason = [array objectAtIndex: 2];
      if (status < 100 || status > 999)
        {
          return nil;
        }
      
      startLine =  [[GSHTTPMessageStatusLine alloc] initWithVersion: version
                                                             status: status
                                                             reason: reason];
    }
  else if ([[array objectAtIndex: 2] hasPrefix: @"HTTP/"])
    {
      NSString  *method;
      NSURL     *uri;

      method = [array objectAtIndex: 0];
      uri = [NSURL URLWithString: [array objectAtIndex: 1]];
      version = [array objectAtIndex: 2];
      if (nil == uri)
        {
          return nil;
        }

      startLine = [[GSHTTPMessageRequestLine alloc] initWithVersion: version
                                                             method: method
                                                                uri: uri];
    }
  else
    {
      startLine = nil;
    }

  return AUTORELEASE(startLine);
}

- (NSString*) HTTPVersion
{
  return _version;
}

@end

@implementation GSHTTPMessageRequestLine

- (instancetype) initWithVersion: (NSString*)version
                          method: (NSString*)method
                             uri: (NSURL*)uri
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_version, version);
      ASSIGN(_method, method);
      ASSIGN(_uri, uri);
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_version);
  DESTROY(_method);
  DESTROY(_uri);
  [super dealloc];
}

@end

@implementation GSHTTPMessageStatusLine

- (instancetype) initWithVersion: (NSString*)version
                          status: (NSInteger)status
                          reason: (NSString*)reason
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_version, version);
      _status = status;
      ASSIGN(_reason, reason);
    }

  return self;
}

- (void) dealloc 
{
  DESTROY(_version);
  DESTROY(_reason);
  [super dealloc];
}

- (NSInteger) statusCode
{
  return _status;
}

@end


@implementation GSResponseHeaderLines

- (instancetype) init
{
  return [self initWithHeaderLines: nil];
}

- (instancetype) initWithHeaderLines: (NSArray*)lines
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_lines, [NSMutableArray arrayWithArray: lines]);
    }

  return self; 
}

- (void) dealloc
{
  DESTROY(_lines);
  [super dealloc];
}

- (void) appendHeaderLine: (NSString*)line
{
  [_lines addObject: line];
}

- (NSHTTPURLResponse*) createHTTPURLResponseFor: (NSURL*)url
{
  GSHTTPMessage            *message;
  NSHTTPURLResponse        *response;
  GSHTTPMessageStatusLine  *statusLine;
  NSDictionary             *headers;

  message = [self createHTTPMessage];
  if (nil == message)
    {
      return nil;
    }

  if (![[message startLine] isKindOfClass: [GSHTTPMessageStatusLine class]])
    {
      return nil;
    }

  statusLine = (GSHTTPMessageStatusLine*)[message startLine];

  headers = [message headersAsDictionary];

  response = [[NSHTTPURLResponse alloc] initWithURL: url 
                                         statusCode: [statusLine statusCode] 
                                        HTTPVersion: [statusLine HTTPVersion] 
                                       headerFields: headers];
  return AUTORELEASE(response);
}

- (GSHTTPMessage*) createHTTPMessage
{
  GSHTTPMessageStartLine  *startLine;
  NSArray                 *headers;
  GSHTTPMessage           *message;

  if ([_lines count] == 0)
    {
      return nil;
    }

  startLine = [GSHTTPMessageStartLine startLineWithLine: 
    [_lines objectAtIndex: 0]];
  if (nil == startLine)
    {
      return nil;
    }

  if ([_lines count] > 1)
    {
      headers = [GSHTTPMessageHeader headersFromLines: 
        [_lines subarrayWithRange: NSMakeRange(1, [_lines count])]];
    }
  else
    {
      headers = [NSArray array];
    }
  
  message = [[GSHTTPMessage alloc] initWithStartLine: startLine
                                             headers: headers];

  return AUTORELEASE(message);
}

@end

@implementation GSHTTPMessageHeader

+ (NSArray*) headersFromLines: (NSArray*)lines
{
  NSMutableArray  *headers;
  NSArray         *headerLines;

  headers = [NSMutableArray array];
  headerLines = lines;
  while ([headerLines count] > 0)
    {
      NSArray              *remaining;
      GSHTTPMessageHeader  *header;

      header = [GSHTTPMessageHeader headerFromLines: headerLines 
                                          remaining: &remaining];
      if (nil == header)
        {
          return nil;
        }
      [headers addObject: header];
      headerLines = remaining;
    }

  return headers;
}

+ (GSHTTPMessageHeader*) headerFromLines: (NSArray*)lines
                               remaining: (NSArray**)remaining
{
  //TODO parse header lines
  return nil;
}

- (instancetype) initWithName: (NSString*)name
                        value: (NSString*)value
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_name, name);
      ASSIGN(_value, value);
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_name);
  DESTROY(_value);
  [super dealloc];
}

- (NSString*) name
{
  return _name;
}

- (NSString*) value
{
  return _value;
}

@end

@implementation GSHTTPMessage

- (instancetype) initWithStartLine: (GSHTTPMessageStartLine*)startLine
                           headers: (NSArray*)headers
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_startLine, startLine);
      ASSIGN(_headers, headers);
    }
  
  return self;
}

- (void) dealloc
{
  DESTROY(_startLine);
  DESTROY(_headers);
  [super dealloc];
}

- (GSHTTPMessageStartLine*) startLine
{
  return _startLine;
}

- (NSDictionary*) headersAsDictionary
{
  NSMutableDictionary  *d;
  NSEnumerator         *e;
  GSHTTPMessageHeader  *header;
  NSString             *name;
  NSString             *value;
  NSMutableString      *s;

  d = [NSMutableDictionary dictionary];
  e = [_headers objectEnumerator];
  while (nil != (header = [e nextObject]))
    {
      name = [header name];
      value = [header value];
      if (nil != (s = [d objectForKey: name]))
        {
          [s appendFormat: @", %@", value];
        }
      else
        {
          s = [NSMutableString stringWithString: value];
          [d setObject: s forKey: name];
        }
    }
  
  return d;
}

@end

@implementation GSParsedResponseHeader

- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _lines = [[GSResponseHeaderLines alloc] init];
      _partial = YES;
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_lines);
  [super dealloc];
}

- (void) appendHeaderLine: (NSData*)data
{
  //TODO
}

- (BOOL) isPartial
{
  return _partial;
}

- (BOOL) isComplete
{
  return !_partial;
}

@end

@implementation GSBodySource
//TODO
@end

@implementation GSDataDrain
//TODO
@end

@implementation GSDataDrainInMemory
//TODO
@end

@implementation GSDataDrainToFile
//TODO
@end

@implementation GSDataDrainIgnore
//TODO
@end

@implementation GSTransferState

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_url, url);
      _parsedResponseHeader = [[GSParsedResponseHeader alloc] init];
      _response = nil;
      _requestBodySource = nil;
      ASSIGN(_bodyDataDrain, bodyDataDrain);
    }
  
  return self;
}

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain
                  bodySource: (GSBodySource*)bodySource
{
  if (nil != (self = [super init]))
    {
      ASSIGN(_url, url);
      _parsedResponseHeader = [[GSParsedResponseHeader alloc] init];
      _response = nil;
      _requestBodySource = bodySource;
      ASSIGN(_bodyDataDrain, bodyDataDrain);
    }
  
  return self;
}

- (void) dealloc
{
  DESTROY(_url);
  DESTROY(_parsedResponseHeader);
  DESTROY(_response);
  DESTROY(_requestBodySource);
  DESTROY(_bodyDataDrain);
  [super dealloc];
}

- (void) appendHTTPHeaderLine: (NSData*)data
{
  [_parsedResponseHeader appendHTTPHeaderLine: data];
  if ([_parsedResponseHeader isComplete])
    {

    }

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


