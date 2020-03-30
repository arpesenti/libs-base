#ifndef	INCLUDED_GSTRANSFERTSTATE_H
#define	INCLUDED_GSTRANSFERTSTATE_H

#import <Foundation/Foundation.h>

#import "GSURLSessionTaskBodySource.h"


@class GSURLSessionTaskBodySource;

typedef NS_ENUM(NSUInteger, GSParsedResponseHeaderType) {
    GSParsedResponseHeaderTypePartial,
    GSParsedResponseHeaderTypeComplete
};

@interface GSParsedResponseHeader: NSObject
{
  NSArray                     *_lines;
  GSParsedResponseHeaderType  _type;
}

- (GSParsedResponseHeaderType) type;

- (instancetype) byAppendingHeaderLine: (NSData*)data;

- (NSHTTPURLResponse*) createHTTPURLResponseForURL: (NSURL*)URL;

@end

typedef NS_ENUM(NSUInteger, GSDataDrainType) {
    GSDataDrainInMemory,
    GSDataDrainTypeToFile,
    GSDataDrainTypeIgnore,
};

@interface GSDataDrain: NSObject
{
  GSDataDrainType _type;
  NSData          *_data;
  NSURL           *_fileURL;
  NSFileHandle    *_fileHandle;
}

- (GSDataDrainType) type;
- (void) setType: (GSDataDrainType)type;

- (NSData*) data;
- (void) setData: (NSData*)data;

- (NSFileHandle*) fileHandle;
- (void) setFileHandle: (NSFileHandle*)handle;

@end

@interface GSTransferState: NSObject
{
  NSURL                           *_url;
  GSParsedResponseHeader          *_parsedResponseHeader;
  NSHTTPURLResponse               *_response;
  id<GSURLSessionTaskBodySource>  _requestBodySource;
  GSDataDrain                     *_bodyDataDrain;
  BOOL                            _isHeaderComplete;
}

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain;

- (instancetype) initWithURL: (NSURL*)url
               bodyDataDrain: (GSDataDrain*)bodyDataDrain
                  bodySource: (id<GSURLSessionTaskBodySource>)bodySource;

- (instancetype) initWithURL: (NSURL*)url
        parsedResponseHeader: (GSParsedResponseHeader*)parsedResponseHeader
                    response: (NSHTTPURLResponse*)response
                  bodySource: (id<GSURLSessionTaskBodySource>)bodySource
               bodyDataDrain: (GSDataDrain*)bodyDataDrain;

- (instancetype) byAppendingBodyData: (NSData*)bodyData;

- (instancetype) byAppendingHTTPHeaderLineData: (NSData*)data 
                                         error: (NSError**)error;

@end

#endif