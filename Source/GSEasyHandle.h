#ifndef	INCLUDED_GSEASYHANDLE_H
#define	INCLUDED_GSEASYHANDLE_H

#import <Foundation/Foundation.h>
#import <curl/curl.h>

@class NSURLSessionConfiguration;
@class NSURLSessionTask;
@class GSTimeoutSource;

typedef NS_ENUM(NSUInteger, GSEasyHandleAction) {
    GSEasyHandleActionAbort,
    GSEasyHandleActionProceed,
    GSEasyHandleActionPause,
};

typedef NS_ENUM(NSUInteger, GSEasyHandleWriteBufferResult) {
    GSEasyHandleWriteBufferResultAbort,
    GSEasyHandleWriteBufferResultPause,
    GSEasyHandleWriteBufferResultBytes,
};

@protocol GSEasyHandleDelegate <NSObject>

- (GSEasyHandleAction) didReceiveData: (NSData*)data;

- (GSEasyHandleAction) didReceiveHeaderData: (NSData*)data 
                              contentLength: (int64_t)contentLength;

- (void) transferCompletedWithError: (NSError*)error;

- (void) fillWriteBufferLength: (NSInteger)length
                        result: (void (^)(GSEasyHandleWriteBufferResult result, NSInteger length, NSData *data))result;

- (BOOL) seekInputStreamToPosition: (uint64_t)position;

- (void) updateProgressMeterWithTotalBytesSent: (int64_t)totalBytesSent 
                      totalBytesExpectedToSend: (int64_t)totalBytesExpectedToSend 
                            totalBytesReceived: (int64_t)totalBytesReceived 
                   totalBytesExpectedToReceive: (int64_t)totalBytesExpectedToReceive;

@end

@interface GSEasyHandle : NSObject
{
  CURL                      *_rawHandle;
  char                      *_errorBuffer;
  id<GSEasyHandleDelegate>  _delegate;
  GSTimeoutSource           *_timeoutTimer;
  NSURL                     *_URL;
}

- (CURL*) rawHandle;

- (char*) errorBuffer;

- (GSTimeoutSource*) timeoutTimer;

- (void) setTimeoutTimer: (GSTimeoutSource*)timer;

- (NSURL*) URL;

- (void) setURL: (NSURL*)URL;

- (instancetype) initWithDelegate: (id<GSEasyHandleDelegate>)delegate;

- (void) transferCompletedWithError: (NSError*)error;

- (int) urlErrorCodeWithEasyCode: (int)easyCode;

- (void) setVerboseMode: (BOOL)flag;

- (void) setDebugOutput: (BOOL)flag 
                   task: (NSURLSessionTask*)task;

- (void) setPassHeadersToDataStream: (BOOL)flag;

- (void) setFollowLocation: (BOOL)flag;

- (void) setProgressMeterOff: (BOOL)flag;

- (void) setSkipAllSignalHandling: (BOOL)flag;

- (void) setFailOnHTTPErrorCode: (BOOL)flag;

- (void) setConnectToHost: (NSString*)host 
                     port: (NSInteger)port;

- (void) setSessionConfig: (NSURLSessionConfiguration*)config;

- (void) setAllowedProtocolsToHTTPAndHTTPS;

- (void) setPreferredReceiveBufferSize: (NSInteger)size;

- (void) setCustomHeaders: (NSArray*)headers;

- (void) setAutomaticBodyDecompression: (BOOL)flag;

- (void) setRequestMethod:(NSString*)method;

- (void) setNoBody: (BOOL)flag;

- (void) setUpload: (BOOL)flag;

- (void) setRequestBodyLength: (int64_t)length;

- (void) setTimeout: (NSInteger)timeout;

- (void) setProxy;

- (double) getTimeoutIntervalSpent;

- (void) pauseReceive;
- (void) unpauseReceive;

- (void) pauseSend;
- (void) unpauseSend;

@end

#endif