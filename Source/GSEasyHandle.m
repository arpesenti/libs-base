#import "GSEasyHandle.h"
#import "GSTimeoutSource.h"

typedef NS_OPTIONS(NSUInteger, GSEasyHandlePauseState) {
    GSEasyHandlePauseStateReceive = 1 << 0,
    GSEasyHandlePauseStateSend = 1 << 1
};

@interface GSEasyHandle ()

- (void) resetTimer;

- (NSInteger) didReceiveData: (char*)data 
                        size: (NSInteger)size 
                       nmemb:(NSInteger)nmemb;

- (NSInteger) fillWriteBuffer: (char *)buffer 
                         size: (NSInteger)size 
                        nmemb: (NSInteger)nmemb;

- (NSInteger) didReceiveHeaderData: (char*)headerData
                              size: (NSInteger)size
                             nmemb: (NSInteger)nmemb
                     contentLength: (double)contentLength;

- (int) seekInputStreamWithOffset: (int64_t)offset 
                           origin: (NSInteger)origin;

@end

static void handleEasyCode(int code)
{
  if (CURLE_OK != code)
    {
      NSString    *reason;
      NSException *e;

      reason = [NSString stringWithFormat: @"An error occurred, CURLcode is %d", 
        code];
      e = [NSException exceptionWithName: @"libcurl.easy" 
                                  reason: reason 
                                userInfo: nil];
      [e raise];
    }
}

static size_t curl_write_function(char *data, size_t size, size_t nmemb, void *userdata) 
{
  if (!userdata)
    {
      return 0;
    }

  GSEasyHandle *handle = (GSEasyHandle*)userdata;
  
  [handle resetTimer]; //FIXME should be deffered after the function returns?

  return [handle didReceiveData:data size:size nmemb:nmemb];
}

static size_t curl_read_function(char *data, size_t size, size_t nmemb, void *userdata) 
{
  if (!userdata)
    {
      return 0;
    }

  GSEasyHandle *handle = (GSEasyHandle*)userdata;
   
  [handle resetTimer]; //FIXME should be deffered after the function returns?

  return [handle fillWriteBuffer: data size: size nmemb: nmemb];
}

size_t curl_header_function(char *data, size_t size, size_t nmemb, void *userdata) 
{
  if (!userdata)
    {
      return 0;
    }

  GSEasyHandle *handle = (GSEasyHandle*)userdata;
  double length;

  [handle resetTimer]; //FIXME should be deffered after the function returns?

  handleEasyCode(curl_easy_getinfo(handle.rawHandle, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length));
  
  return [handle didReceiveHeaderData: data 
                                 size: size 
                                nmemb: nmemb 
                        contentLength: length];
}

static int curl_seek_function(void *userdata, curl_off_t offset, int origin) 
{
  if (!userdata)
    {
      return CURL_SEEKFUNC_FAIL;
    }

  GSEasyHandle *handle = (GSEasyHandle*)userdata;
  
  return [handle seekInputStreamWithOffset: offset origin: origin];
}

static int curl_debug_function(CURL *handle, curl_infotype type, char *data, size_t size, void *userptr) 
{
  if (!userptr)
    {
      return 0;
    }

    NSURLSessionTask *task = (NSURLSessionTask*)userptr;
    NSString *text = @"";

    if (data) 
      {
        text = [NSString stringWithUTF8String: data];
      }
    
    NSLog(@"%lu %d %@", [task taskIdentifier], type, text);

    return 0;
}

static int curl_socket_function(void *userdata, curl_socket_t fd, curlsocktype type) 
{ 
  return 0; 
}

@implementation GSEasyHandle
{
  NSURLSessionConfiguration  *_config;
  GSEasyHandlePauseState     _pauseState;
  struct curl_slist          *_headerList;
}

- (instancetype) initWithDelegate: (id<GSEasyHandleDelegate>)delegate 
{
  if (nil != (self = [super init])) 
    {
      _rawHandle = curl_easy_init();
      _delegate = delegate;

      char *eb = (char *)malloc(sizeof(char) * (CURL_ERROR_SIZE + 1));
      _errorBuffer = memset(eb, 0, sizeof(char) * (CURL_ERROR_SIZE + 1));
      
      [self setupCallbacks];
    }

  return self;
}

- (void) dealloc 
{
  curl_easy_cleanup(_rawHandle);
  curl_slist_free_all(_headerList);
  free(_errorBuffer);
  DESTROY(_config);
  DESTROY(_timeoutTimer);
  DESTROY(_URL);
  [super dealloc];
}

- (void) transferCompletedWithError: (NSError*)error 
{
  [_delegate transferCompletedWithError: error];
}

- (void) resetTimer 
{
  // simply create a new timer with the same queue, timeout and handler
  // this must cancel the old handler and reset the timer
  DESTROY(_timeoutTimer);
  _timeoutTimer = [[GSTimeoutSource alloc] initWithQueue: [_timeoutTimer queue]
                                            milliseconds: [_timeoutTimer milliseconds]
                                                 handler: [_timeoutTimer handler]];
}

- (void) setupCallbacks 
{
  // write
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_WRITEDATA, self));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_WRITEFUNCTION, curl_write_function));

  // read
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_READDATA, self));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_READFUNCTION, curl_read_function));

  // header
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HEADERDATA, self));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HEADERFUNCTION, curl_header_function));

  // socket options
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_SOCKOPTDATA, self));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_SOCKOPTFUNCTION, curl_socket_function));

  // seeking in input stream
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_SEEKDATA, self));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_SEEKFUNCTION, curl_seek_function));
}

- (int) urlErrorCodeWithEasyCode: (int)easyCode 
{
    int failureErrno = (int)[self connectFailureErrno];
    if (easyCode == CURLE_OK) 
      {
        return 0;
      } 
    else if (failureErrno == ECONNREFUSED) 
      {
        return NSURLErrorCannotConnectToHost;
      } 
    else if (easyCode == CURLE_UNSUPPORTED_PROTOCOL) 
      {
        return NSURLErrorUnsupportedURL;
      } 
    else if (easyCode == CURLE_URL_MALFORMAT) 
      {
        return NSURLErrorBadURL;
      } 
    else if (easyCode == CURLE_COULDNT_RESOLVE_HOST) 
      {
        return NSURLErrorCannotFindHost;
      } 
    else if (easyCode == CURLE_RECV_ERROR && failureErrno == ECONNRESET) 
      {
        return NSURLErrorNetworkConnectionLost;
      } 
    else if (easyCode == CURLE_SEND_ERROR && failureErrno == ECONNRESET) 
      {
        return NSURLErrorNetworkConnectionLost;
      } 
    else if (easyCode == CURLE_GOT_NOTHING) 
      {
        return NSURLErrorBadServerResponse;
      }
    else if (easyCode == CURLE_ABORTED_BY_CALLBACK) 
      {
        return NSURLErrorUnknown;
      }
    else if (easyCode == CURLE_COULDNT_CONNECT && failureErrno == ETIMEDOUT) 
      {
        return NSURLErrorTimedOut;
      }
    else if (easyCode == CURLE_OPERATION_TIMEDOUT) 
      {
        return NSURLErrorTimedOut;
      } 
    else 
      {
        return NSURLErrorUnknown;
      }
}

- (void) setVerboseMode: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_VERBOSE, flag ? 1 : 0));
}

- (void) setDebugOutput: (BOOL)flag 
                   task: (NSURLSessionTask*)task 
{
  if (flag) 
    {
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGDATA, self));
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGFUNCTION, curl_debug_function));
    } 
  else 
    {
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGDATA, NULL));
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_DEBUGFUNCTION, NULL));
    }
}

- (void) setPassHeadersToDataStream: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HEADER, flag ? 1 : 0));
}

- (void) setFollowLocation: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_FOLLOWLOCATION, flag ? 1 : 0));
}

- (void) setProgressMeterOff: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_NOPROGRESS, flag ? 1 : 0));
}

- (void) setSkipAllSignalHandling: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_NOSIGNAL, flag ? 1 : 0));
}

- (void) setErrorBuffer: (char*)buffer 
{
    char *b = buffer ? buffer : _errorBuffer;
    handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_ERRORBUFFER, b));
}

- (void) setFailOnHTTPErrorCode: (BOOL)flag 
{
    handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_FAILONERROR, flag ? 1 : 0));
}

- (void) setURL: (NSURL *)URL 
{
    ASSIGN(_URL, URL);
    if (nil != [URL absoluteString]) 
      {
        handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_URL, [[URL absoluteString] UTF8String]));
      }
}

-(void) setConnectToHost: (NSString*)host port: (NSInteger)port 
{
  if (nil != host) 
    {
      NSString *originHost = [_URL host];
      NSString *value = nil;
      if (port == 0) 
        {
          value = [NSString stringWithFormat:@"%@::%@", originHost, host];
        } 
      else 
        {
          value = [NSString stringWithFormat:@"%@:%lu:%@", 
            originHost, port, host];
        }
      
      struct curl_slist *connect_to = NULL;
      connect_to = curl_slist_append(NULL, [value UTF8String]);
      // TODO why CURLOPT_CONNECT_TO is missing?
      // handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_CONNECT_TO, connect_to));
    }
}

- (void) setSessionConfig: (NSURLSessionConfiguration*)config 
{
  ASSIGN(_config, config);
}

- (void) setAllowedProtocolsToHTTPAndHTTPS 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS));
}

- (void) setPreferredReceiveBufferSize: (NSInteger)size 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_BUFFERSIZE, MIN(size, CURL_MAX_WRITE_SIZE)));
}

- (void) setCustomHeaders: (NSArray*)headers 
{
  NSEnumerator  *e;
  NSString      *h;

  e = [headers objectEnumerator];
  while (nil != (h = [e nextObject]))
    {
      _headerList = curl_slist_append(_headerList, [h UTF8String]);
    }
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HTTPHEADER, _headerList));
}

- (void) setAutomaticBodyDecompression: (BOOL)flag 
{
  if (flag) 
    {
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_ACCEPT_ENCODING, ""));
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 1));
    } 
  else 
    {
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_ACCEPT_ENCODING, NULL));
      handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_HTTP_CONTENT_DECODING, 0));
    }
}

- (void) setRequestMethod: (NSString*)method 
{
  if (nil == method) 
    {
      return;
    }

  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_CUSTOMREQUEST, [method UTF8String]));
}

- (void) setNoBody: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_NOBODY, flag ? 1 : 0));
}

- (void) setUpload: (BOOL)flag 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_UPLOAD, flag ? 1 : 0));
}

- (void) setRequestBodyLength: (int64_t)length 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_INFILESIZE_LARGE, length));
}

- (void) setTimeout: (NSInteger)timeout 
{
  handleEasyCode(curl_easy_setopt(_rawHandle, CURLOPT_TIMEOUT, (long)timeout));
}

- (void) setProxy 
{    
  //TODO
}

- (void) updatePauseState: (GSEasyHandlePauseState)pauseState 
{
  NSUInteger send = pauseState & GSEasyHandlePauseStateSend;
  NSUInteger receive = pauseState & GSEasyHandlePauseStateReceive;
  int bitmask = 0 | (send ? CURLPAUSE_SEND : CURLPAUSE_SEND_CONT) | (receive ? CURLPAUSE_RECV : CURLPAUSE_RECV_CONT);
  handleEasyCode(curl_easy_pause(_rawHandle, bitmask));
}

- (double) getTimeoutIntervalSpent 
{
  double timeSpent;
  curl_easy_getinfo(_rawHandle, CURLINFO_TOTAL_TIME, &timeSpent);
  return timeSpent / 1000;
}

- (long) connectFailureErrno 
{
  long _errno;
  handleEasyCode(curl_easy_getinfo(_rawHandle, CURLINFO_OS_ERRNO, &_errno));
  return _errno;
}

- (void) pauseSend 
{
  if (_pauseState & GSEasyHandlePauseStateSend) 
    {
      return;
    }
    
    _pauseState = _pauseState | GSEasyHandlePauseStateSend;
    [self updatePauseState: _pauseState];
}

- (void) unpauseSend {
  if (!(_pauseState & GSEasyHandlePauseStateSend))
    {
      return;
    }
  
  _pauseState = _pauseState ^ GSEasyHandlePauseStateSend;
  [self updatePauseState: _pauseState];
}

- (void) pauseReceive {
  if (_pauseState & GSEasyHandlePauseStateReceive) 
    {
      return;
    }
  
  _pauseState = _pauseState | GSEasyHandlePauseStateReceive;
  [self updatePauseState: _pauseState];
}

- (void) unpauseReceive 
{
  if (!(_pauseState & GSEasyHandlePauseStateReceive))
    {
      return;
    }
  
  _pauseState = _pauseState ^ GSEasyHandlePauseStateReceive;
  [self updatePauseState: _pauseState];
}

//TODO add remaining methods

@end