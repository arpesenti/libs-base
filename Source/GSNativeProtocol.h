#ifndef	INCLUDED_GSNATIVEPROTOCOL_H
#define	INCLUDED_GSNATIVEPROTOCOL_H

#import <Foundation/Foundation.h>

#import "GSEasyHandle.h"


@interface GSHTTPMessageStartLine: NSObject
{
  NSString  *_version;
}

+ (GSHTTPMessageStartLine*) startLineWithLine: (NSString*)line;

- (NSString*) HTTPVersion;

@end

@interface GSHTTPMessageRequestLine : GSHTTPMessageStartLine
{
  NSString  *_method;
  NSURL     *_uri;
}

- (instancetype) initWithVersion: (NSString*)version
                          method: (NSString*)method
                             uri: (NSURL*)uri;

@end

@interface GSHTTPMessageStatusLine : GSHTTPMessageStartLine
{
  NSInteger _status;
  NSString  *_reason;
}

- (instancetype) initWithVersion: (NSString*)version
                          status: (NSInteger)status
                          reason: (NSString*)reason;

- (NSInteger) statusCode;

@end

@interface GSHTTPMessageHeader: NSObject
{
  NSString  *_name;
  NSString  *_value;
}

+ (NSArray*) headersFromLines: (NSArray*)lines;

- (NSString*) name;
- (NSString*) value;

@end

@interface GSHTTPMessage: NSObject
{
  GSHTTPMessageStartLine  *_startLine;
  NSArray                 *_headers;
}

- (instancetype) initWithStartLine: (GSHTTPMessageStartLine*)startLine
                           headers: (NSArray*)headers;

- (GSHTTPMessageStartLine*) startLine;

- (NSDictionary*) headersAsDictionary;

@end

@interface GSResponseHeaderLines: NSObject
{
  NSMutableArray  *_lines;
}

- (instancetype) init;

- (instancetype) initWithHeaderLines: (NSArray*)lines;

- (void) appendHeaderLine: (NSString*)line;

- (NSHTTPURLResponse*) createHTTPURLResponseFor: (NSURL*)url;

- (GSHTTPMessage*) createHTTPMessage;

@end

@interface GSParsedResponseHeader: NSObject
{
  GSResponseHeaderLines  *_lines;
  BOOL                   _partial;
}

- (BOOL) isPartial;

- (BOOL) isComplete;

@end

@interface GSBodySource: NSObject
//TODO
@end

@interface GSDataDrain: NSObject
//TODO
@end

@interface GSDataDrainInMemory: GSDataDrain
{
  NSMutableData  *_data;
}
//TODO
@end

@interface GSDataDrainToFile: GSDataDrain
{
  NSURL         *_url;
  NSFileHandle  *_fileHandle;
}
//TODO
@end

@interface GSDataDrainIgnore: GSDataDrain
@end

@interface GSTransferState: NSObject
{
  NSURL                   *_url;
  GSParsedResponseHeader  *_parsedResponseHeader;
  NSURLResponse           *_response;
  GSBodySource            *_requestBodySource;
  GSDataDrain             *_bodyDataDrain;
}

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain;

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain
                  bodySource: (GSBodySource*)bodySource;
@end

@interface GSNativeProtocol : NSURLProtocol <GSEasyHandleDelegate>

@end

#endif