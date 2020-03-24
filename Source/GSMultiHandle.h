#ifndef	INCLUDED_GSMULTIHANDLE_H
#define	INCLUDED_GSMULTIHANDLE_H

#import <Foundation/Foundation.h>
#import <curl/curl.h>

@class NSURLSessionConfiguration;
@class GSEasyHandle;

@interface GSMultiHandle : NSObject
{
  CURLM  *_rawHandle;
}

- (CURLM*) rawHandle;
- (instancetype) initWithConfiguration: (NSURLSessionConfiguration*)configuration 
                             workQueue: (dispatch_queue_t)workQueque;
- (void) addHandle: (GSEasyHandle*)easyHandle;
- (void) removeHandle: (GSEasyHandle*)easyHandle;
- (void) updateTimeoutTimerToValue: (NSInteger)value;

@end

typedef NS_ENUM(NSUInteger, GSSocketRegisterActionType) {
    GSSocketRegisterActionTypeNone = 0,
    GSSocketRegisterActionTypeRegisterRead,
    GSSocketRegisterActionTypeRegisterWrite,
    GSSocketRegisterActionTypeRegisterReadAndWrite,
    GSSocketRegisterActionTypeUnregister,
};

@interface GSSocketRegisterAction : NSObject
{
  GSSocketRegisterActionType  _type;
}

- (instancetype) initWithRawValue: (int)rawValue;
- (GSSocketRegisterActionType) type;
- (BOOL) needsReadSource;
- (BOOL) needsWriteSource;
- (BOOL) needsSource;

@end

@interface GSSocketSources : NSObject
{
  dispatch_source_t _readSource;
  dispatch_source_t _writeSource;
}

- (dispatch_source_t) readSource;
- (void) setReadSource: (dispatch_source_t)source;
- (dispatch_source_t) writeSource;
- (void) setWriteSource: (dispatch_source_t)source;
- (void) createSourcesWithAction: (GSSocketRegisterAction *)action
                          socket: (curl_socket_t)socket
                           queue: (dispatch_queue_t)queue
                         handler: (dispatch_block_t)handler;
- (void) createReadSourceWithSocket: (curl_socket_t)socket
                              queue: (dispatch_queue_t)queue
                            handler: (dispatch_block_t)handler;
- (void) createWriteSourceWithSocket: (curl_socket_t)socket
                               queue: (dispatch_queue_t)queue
                             handler: (dispatch_block_t)handler;

+ (instancetype) from: (void*)socketSourcePtr;

@end

#endif