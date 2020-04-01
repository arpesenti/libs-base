#import "GSHTTPURLProtocol.h"
#import "GSTransferState.h"

@interface NSURLSessionTask (Internal)

- (void) setCountOfBytesExpectedToReceive: (int64_t)count;

@end

@implementation NSURLSessionTask (Internal)

- (void) setCountOfBytesExpectedToReceive: (int64_t)count
{
  _countOfBytesExpectedToReceive = count;
}

@end

@interface GSURLCacherHelper : NSObject

+ (BOOL) canCacheResponse: (NSCachedURLResponse*)response 
                  request: (NSURLRequest*)request;

@end

static NSDate* dateFromString(NSString *v) 
{
  // https://tools.ietf.org/html/rfc2616#section-3.3.1
  NSDateFormatter *df;
  NSDate          *d;

  df = AUTORELEASE([[NSDateFormatter alloc] init]);

  // RFC 822
  [df setDateFormat: @"EEE, dd MMM yyyy HH:mm:ss zzz"];
  d = [df dateFromString: v];
  if (nil != d) 
    {
      return d;
    } 

  // RFC 850
  [df setDateFormat: @"EEEE, dd-MMM-yy HH:mm:ss zzz"];
  d = [df dateFromString: v];
  if (nil != d) 
    {
      return d;
    } 

  // ANSI C's asctime() format
  [df setDateFormat: @"EEE MMM dd HH:mm:ss yy"];
  d = [df dateFromString: v];
  if (nil != d) 
    {
      return d;
    } 

  return nil;
}

static NSInteger parseArgumentPart(NSString *part, NSString *name) 
{
  NSString *prefix;
  
  prefix = [NSString stringWithFormat: @"%@=", name];
  if ([part hasPrefix: prefix]) 
    {
      NSArray *split;
      
      split = [part componentsSeparatedByString: @"="];
      if (split && [split count] == 2) 
        {
          NSString *argument = split[1];

          if ([argument hasPrefix: @"\""] && [argument hasSuffix: @"\""]) 
            {
              if ([argument length] >= 2) 
                {
                  NSRange range = NSMakeRange(1, [argument length] - 2);
                  argument = [argument substringWithRange: range];
                  return [argument integerValue];
                } 
              else
                {
                  return 0;
                }
            } 
          else 
            {
              return [argument integerValue];
            }
        }
    }
  
  return 0;
}


@implementation GSURLCacherHelper

+ (BOOL) canCacheResponse: (NSCachedURLResponse*)response 
                  request: (NSURLRequest*)request
{
  NSURLRequest       *httpRequest = request;
  NSHTTPURLResponse  *httpResponse = nil;
  NSDate             *now;
  NSDate             *expirationStart;
  NSString           *dateString;
  NSDictionary       *headers;
  BOOL               hasCacheControl = NO;
  BOOL               hasMaxAge = NO;
  NSString           *cacheControl;
  NSString           *pragma;
  NSString           *expires;

  if (nil == httpRequest)
    {
      return NO;
    } 

  if ([[response response] isKindOfClass: [NSHTTPURLResponse class]]) 
    {
      httpResponse = (NSHTTPURLResponse*)[response response];
    }

  if (nil == httpResponse)
    {
      return NO;
    } 

  // HTTP status codes: https://tools.ietf.org/html/rfc7231#section-6.1
  switch ([httpResponse statusCode]) 
    {
      case 200:
      case 203:
      case 204:
      case 206:
      case 300:
      case 301:
      case 404:
      case 405:
      case 410:
      case 414:
      case 501:
          break;

      default:
          return NO;
    }

  headers = [httpResponse allHeaderFields];

  // Vary: https://tools.ietf.org/html/rfc7231#section-7.1.4
  if (nil != [headers objectForKey: @"Vary"]) 
    {
      return NO;
    }

  now = [NSDate date];
  dateString = [headers objectForKey: @"Date"];
  if (nil != dateString) 
    {
      expirationStart = dateFromString(dateString);
    } 
  else 
    {
      return NO;
    }

  // We opt not to cache any requests or responses that contain authorization headers.
  if ([headers objectForKey: @"WWW-Authenticate"] 
    || [headers objectForKey: @"Proxy-Authenticate"] 
    || [headers objectForKey: @"Authorization"] 
    || [headers objectForKey: @"Proxy-Authorization"]) 
    {
      return NO;
    }

  // HTTP Methods: https://tools.ietf.org/html/rfc7231#section-4.2.3
  if ([[httpRequest HTTPMethod] isEqualToString: @"GET"]) 
    {
    } 
  else if ([[httpRequest HTTPMethod] isEqualToString: @"HEAD"]) 
    {
      if ([response data] && [[response data] length] > 0) 
        {
          return NO;
        }
    } 
  else 
    {
      return NO;
    }

  // Cache-Control: https://tools.ietf.org/html/rfc7234#section-5.2
  cacheControl = [headers objectForKey: @"Cache-Control"];
  if (nil != cacheControl) 
    {
      NSInteger  maxAge = 0;
      NSInteger  sharedMaxAge = 0;
      BOOL       noCache = NO;
      BOOL       noStore = NO;

      [self getCacheControlDeirectivesFromHeaderValue: cacheControl
                                               maxAge: &maxAge
                                         sharedMaxAge: &sharedMaxAge
                                              noCache: &noCache
                                              noStore: &noStore];
      if (noCache || noStore) 
        {
          return false;
        }

      if (maxAge > 0) 
        {
          hasMaxAge = YES;

          NSDate *expiration = [expirationStart dateByAddingTimeInterval: maxAge];
          if ([now timeIntervalSince1970] >= [expiration timeIntervalSince1970]) 
            {
              return NO;
            }
        }

      if (sharedMaxAge)
        {
          hasMaxAge = YES;
        } 
      
      hasCacheControl = YES;
    }

  // Pragma: https://tools.ietf.org/html/rfc7234#section-5.4
  pragma = [headers objectForKey: @"Pragma"];
  if (!hasCacheControl && nil != pragma) 
    {
      NSArray         *cs = [pragma componentsSeparatedByString: @","];
      NSMutableArray  *components = [NSMutableArray arrayWithCapacity: [cs count]];
      NSString        *c;

      for (int i = 0; i < [cs count]; i++)
        {
          c = [cs objectAtIndex: i];
          c = [c stringByTrimmingCharactersInSet: 
            [NSCharacterSet whitespaceCharacterSet]];
          c = [c lowercaseString];
          [components setObject: c atIndexedSubscript: i];
        }
      
      if ([components containsObject: @"no-cache"]) 
        {
          return NO;
        }
    }

  // Expires: <https://tools.ietf.org/html/rfc7234#section-5.3>
  // We should not cache a response that has already expired.
  // We MUST ignore this if we have Cache-Control: max-age or s-maxage.
  expires = [headers objectForKey: @"Expires"];
  if (!hasMaxAge && nil != expires) 
    {
      NSDate *expiration = dateFromString(expires);
      if (nil == expiration)
        {
          return NO;
        }

      if ([now timeIntervalSince1970] >= [expiration timeIntervalSince1970]) 
        {
          return NO;
        }
    }

  if (!hasCacheControl) 
    {
      return NO;
    }

  return YES;
}

+ (void) getCacheControlDeirectivesFromHeaderValue: (NSString*)headerValue
                                            maxAge: (NSInteger*)maxAge
                                      sharedMaxAge: (NSInteger*)sharedMaxAge
                                           noCache: (BOOL*)noCache
                                           noStore: (BOOL*)noStore 
{
    NSArray       *components;
    NSEnumerator  *e;
    NSString      *part;
    
    components = [headerValue componentsSeparatedByString: @","];
    e = [components objectEnumerator];
    while (nil != (part = [e nextObject]))
      {
        part = [part stringByTrimmingCharactersInSet: 
          [NSCharacterSet whitespaceCharacterSet]];
        part = [part lowercaseString];

        if ([part isEqualToString: @"no-cache"]) 
          {
            *noCache = YES;
          }
        else if ([part isEqualToString: @"no-store"]) 
          {
            *noStore = YES;
          }
        else if ([part containsString: @"max-age"]) 
          {
            *maxAge = parseArgumentPart(part, @"max-age");
          } 
        else if ([part containsString: @"s-maxage"]) 
          {
            *sharedMaxAge = parseArgumentPart(part, @"s-maxage");
          } 
      }
}

@end

@implementation GSHTTPURLProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest*)request
{
  NSURL  *url;

  if (nil != (url = [request URL]) 
    && ([[url scheme] isEqualToString: @"http"]
    || [[url scheme] isEqualToString: @"https"]))
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (GSEasyHandleAction) didReceiveHeaderData: (NSData*)data 
                              contentLength: (int64_t)contentLength
{
  NSURLSessionTask  *task;
  GSTransferState   *newTS;
  NSError           *error = NULL;

  NSAssert(_internalState == GSNativeProtocolInternalStateTransferInProgress,
    @"Received header data, but no transfer in progress.");

  task = [self task];
  NSAssert(nil != task, @"Received header data but no task available.");

  newTS = [_transferState byAppendingHTTPHeaderLineData: data error: &error];
  if (nil != newTS && NULL == error)
    {
      BOOL didCompleteHeader;

      didCompleteHeader = ![_transferState isHeaderComplete] 
        && [newTS isHeaderComplete];
      [self setInternalState: GSNativeProtocolInternalStateTransferInProgress];
      ASSIGN(_transferState, newTS);
      if (didCompleteHeader)
        {
          // The header is now complete, but wasn't before.
          NSHTTPURLResponse  *response;
          NSString           *contentEncoding;

          response = (NSHTTPURLResponse*)[newTS response];
          contentEncoding = [[response allHeaderFields] 
            objectForKey: @"Content-Encoding"];
          if (nil != contentEncoding
            && ![contentEncoding isEqual: @"identity"])
            {
              // compressed responses do not report expected size
              [task setCountOfBytesExpectedToReceive: -1];
            }
          else
            {
              [task setCountOfBytesExpectedToReceive: 
                (contentLength > 0 ? contentLength : -1)];
            }
          [self didReceiveResponse];
        }
      return GSEasyHandleActionProceed;
    }
  else
    {
      return GSEasyHandleActionAbort;
    }
}

- (BOOL) canRespondFromCacheUsing: (NSCachedURLResponse*)response
{
  BOOL              canCache;
  NSURLSessionTask  *task;

  task = [self task];

  canCache = [GSURLCacherHelper canCacheResponse: response 
                                         request: [task currentRequest]];
  if (!canCache)
    {
      // If somehow cached a response that shouldn't have been,
      // we should remove it.
      NSURLCache  *cache;

      cache = [[[task session] configuration] URLCache];
      if (nil != cache)
        {
          [cache removeCachedResponseForRequest: [task currentRequest]];
        }

      return NO;
    }
  
  return YES;
}

- (void) didReceiveResponse
{
  //TODO
}

@end
