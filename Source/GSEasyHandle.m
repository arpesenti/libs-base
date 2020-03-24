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
      handleEasyCode(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGDATA, NULL));
      handleEasyCode(curl_easy_setopt(self.rawHandle, CURLOPT_DEBUGFUNCTION, NULL));
    }
}

@end