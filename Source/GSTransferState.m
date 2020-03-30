#import "GSTransferState.h"
#import "GSURLSessionTaskBodySource.h"

#define GS_DELIMITERS_CR 0x0d
#define GS_DELIMITERS_LR 0x0a

@implementation GSParsedResponseHeader

- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _lines = [[NSMutableArray alloc] init];
      _type = GSParsedResponseHeaderTypePartial;
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_lines);
  [super dealloc];
}

- (void) setType: (GSParsedResponseHeaderType)type
{
  _type = type;
}

- (void) setLines: (NSArray*)lines
{
  ASSIGN(_lines, lines);
}

- (instancetype) byAppendingHeaderLine: (NSData*)data 
{
  NSUInteger length = [data length];

  if (length >= 2) 
    {
      uint8_t last2;
      uint8_t last1;

      [data getBytes: &last2 range: NSMakeRange(length - 2, 1)];
      [data getBytes: &last1 range: NSMakeRange(length - 1, 1)];

      if (GS_DELIMITERS_CR == last2 && GS_DELIMITERS_LR == last1) 
        {
          NSData *lineBuffer;
          NSString *line;

          lineBuffer = [data subdataWithRange: NSMakeRange(0, length - 2)];
          line = AUTORELEASE([[NSString alloc] initWithData: lineBuffer 
                                                   encoding: NSUTF8StringEncoding]);

          if (nil == line)
            {
              return nil;
            } 
          
          return [self _byAppendingHeaderLine: line];
        }
    }

  return nil;
}

- (NSHTTPURLResponse*) createHTTPURLResponseForURL: (NSURL*)URL 
{
  NSArray       *tail;
  NSArray       *startLine;
  NSDictionary  *headerFields;
  NSString      *head;
  NSString      *s, *v;

  head = [_lines firstObject];
  if (nil == head) 
    {
      return nil;
    }
  if ([_lines count] == 0)
    {
      return nil;
    } 
  
  tail = [_lines subarrayWithRange: NSMakeRange(1, [_lines count] - 1)];

  startLine = [self statusLineFromLine: head];
  if (nil == startLine) 
    {
      return nil;
    }

  headerFields = [self createHeaderFieldsFromLines: tail];

  v = [startLine objectAtIndex: 0];
  s = [startLine objectAtIndex: 1];

  return AUTORELEASE([[NSHTTPURLResponse alloc] initWithURL: URL
                                                 statusCode: [s integerValue]
                                                HTTPVersion: v
                                               headerFields: headerFields]);
}

- (NSArray*) statusLineFromLine: (NSString*)line 
{
  NSArray    *a;
  NSString   *s;
  NSInteger  status;

  a = [line componentsSeparatedByString: @" "];
  if ([a count] < 3) 
    {
      return nil;
    }

  s = [a objectAtIndex: 1];

  status = [s integerValue];
  if (status >= 100 && status <= 999) 
    {
      return a;
    } 
  else 
    {
      return nil;
    }
}

- (NSDictionary *) createHeaderFieldsFromLines: (NSArray *)lines 
{
  NSMutableDictionary *headerFields = nil;
  NSEnumerator        *e;
  NSString            *line;

  e = [_lines objectEnumerator];
  while (nil != (line = [e nextObject]))
    {
      NSRange        r;
      NSString       *head;
      NSString       *tail;
      NSCharacterSet *set;
      NSString       *key;
      NSString       *value;
      NSString       *v;

      r = [line rangeOfString: @":"];
      if (r.location != NSNotFound) 
        {
          head = [line substringToIndex: r.location];
          tail = [line substringFromIndex: r.location + 1];
          set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
          key = [head stringByTrimmingCharactersInSet: set];
          value = [tail stringByTrimmingCharactersInSet: set];
          if (nil != key && nil != value) 
            {
              if (nil == headerFields) 
                {
                  headerFields = [NSMutableDictionary dictionary];
                }
              if (nil != [headerFields objectForKey: key]) 
                {
                  v = [NSString stringWithFormat:@"%@, %@", 
                    [headerFields objectForKey: key], value];
                  [headerFields setObject: v forKey: key];
                } 
              else 
                {
                  [headerFields setObject: value forKey: key];
                }
            }
        } 
      else 
        {
          continue;
        }
    }
  
  return AUTORELEASE([headerFields copy]);
}

- (instancetype) _byAppendingHeaderLine: (NSString*)line 
{
  GSParsedResponseHeader *header;

  header = AUTORELEASE([[GSParsedResponseHeader alloc] init]);

  if ([line length] == 0) 
    {
      switch (_type) 
        {
          case GSParsedResponseHeaderTypePartial: 
            {
              [header setType: GSParsedResponseHeaderTypeComplete];
              [header setLines: _lines];

              return header;
            }
          case GSParsedResponseHeaderTypeComplete:
            return header;
      }
    } 
  else 
    {
      NSMutableArray *lines = [[self partialResponseHeader] mutableCopy];
      
      [lines addObject:line];

      [header setType: GSParsedResponseHeaderTypePartial];
      [header setLines: lines];

      RELEASE(lines);

      return header;
  }
}

- (NSArray*) partialResponseHeader 
{
  switch (_type) 
    {
      case GSParsedResponseHeaderTypeComplete:
        return [NSArray array];

      case GSParsedResponseHeaderTypePartial:
        return _lines;
    }
}

@end

@implementation GSDataDrain
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
                  bodySource: (id<GSURLSessionTaskBodySource>)bodySource
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