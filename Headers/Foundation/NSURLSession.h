#ifndef __NSURLSession_h_GNUSTEP_BASE_INCLUDE
#define __NSURLSession_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSHTTPCookieStorage.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)
@protocol NSURLSessionDelegate;
@protocol NSURLSessionTaskDelegate;

@class NSURLSessionConfiguration;
@class NSOperationQueue;
@class NSURLSessionDataTask;
@class NSURL;
@class NSURLRequest;
@class NSURLResponse;
@class NSError;
@class NSURLCache;
@class GSMultiHandle;

@interface NSURLSession : NSObject
{
  NSOperationQueue           *_delegateQueue;
  id <NSURLSessionDelegate>  _delegate;
  NSURLSessionConfiguration  *_configuration;
  NSString                   *_sessionDescription;
  GSMultiHandle              *_multiHandle;
}

/*
 * Customization of NSURLSession occurs during creation of a new session.
 * If you do specify a delegate, the delegate will be retained until after
 * the delegate has been sent the URLSession:didBecomeInvalidWithError: message.
 */
+ (NSURLSession*) sessionWithConfiguration: (NSURLSessionConfiguration*)configuration 
                                  delegate: (id <NSURLSessionDelegate>)delegate 
                             delegateQueue: (NSOperationQueue*)queue;

- (NSOperationQueue*) delegateQueue;

- (id <NSURLSessionDelegate>) delegate;

- (NSURLSessionConfiguration*) configuration;

- (NSString*) sessionDescription;

- (void) setSessionDescription: (NSString*)sessionDescription;

/* -finishTasksAndInvalidate returns immediately and existing tasks will be 
 * allowed to run to completion.  New tasks may not be created.  The session
 * will continue to make delegate callbacks until 
 * URLSession:didBecomeInvalidWithError: has been issued. 
 *
 * When invalidating a background session, it is not safe to create another 
 * background session with the same identifier until 
 * URLSession:didBecomeInvalidWithError: has been issued.
 */
- (void) finishTasksAndInvalidate;

/* -invalidateAndCancel acts as -finishTasksAndInvalidate, but issues
 * -cancel to all outstanding tasks for this session.  Note task 
 * cancellation is subject to the state of the task, and some tasks may
 * have already have completed at the time they are sent -cancel. 
 */
- (void) invalidateAndCancel;

/* 
 * NSURLSessionTask objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 */

/* Creates a data task with the given request. 
 * The request may have a body stream. */
- (NSURLSessionDataTask*) dataTaskWithRequest: (NSURLRequest*)request;

/* Creates a data task to retrieve the contents of the given URL. */
- (NSURLSessionDataTask*) dataTaskWithURL: (NSURL*)url;

@end

typedef NS_ENUM(NSUInteger, NSURLSessionTaskState) {
  /* The task is currently being serviced by the session */
  NSURLSessionTaskStateRunning = 0,    
  NSURLSessionTaskStateSuspended = 1,
  /* The task has been told to cancel.  
   * The session will receive URLSession:task:didCompleteWithError:. */
  NSURLSessionTaskStateCanceling = 2,  
  /* The task has completed and the session will receive no more 
   * delegate notifications */
  NSURLSessionTaskStateCompleted = 3,  
};

/*
 * NSURLSessionTask - a cancelable object that refers to the lifetime
 * of processing a given request.
 */
@interface NSURLSessionTask : NSObject <NSCopying>
{
  NSUInteger    _taskIdentifier;                /* an identifier for this task, 
                                                 * assigned by and unique to the 
                                                 * owning session */
  NSURLRequest  *_originalRequest;
  NSURLRequest  *_currentRequest;               /* may differ from 
                                                 * originalRequest due to http 
                                                 * server redirection */
  NSURLResponse *_response;                     /* may be nil if no response has
                                                 * been received */
  int64_t       _countOfBytesReceived;          /* number of body bytes already 
                                                 * received */
  int64_t       _countOfBytesSent;              /* number of body bytes already 
                                                 * sent */
  int64_t       _countOfBytesExpectedToSend;    /* number of body bytes we 
                                                 * expect to send, derived from 
                                                 * the Content-Length of the 
                                                 * HTTP request */
  int64_t       _countOfBytesExpectedToReceive; /* number of byte bytes we 
                                                 * expect to receive, usually 
                                                 * derived from the 
                                                 * Content-Length header of an 
                                                 * HTTP response. */
  NSString      *_taskDescription;
  NSURLSessionTaskState _state;                 /* The current state of the task 
                                                 * within the session. */
  NSError       *_error;                        /* The error, if any, delivered 
                                                 * via -URLSession:task:didCompleteWithError:
                                                 * This property will be nil in 
                                                 * the event that no error 
                                                 * occured. */
}

- (NSUInteger) taskIdentifier;

- (NSURLRequest*) originalRequest;

- (NSURLRequest*) currentRequest;

- (NSURLResponse*) response;

- (int64_t) countOfBytesReceived;

- (int64_t) countOfBytesSent;

- (int64_t) countOfBytesExpectedToSend;

- (int64_t) countOfBytesExpectedToReceive;

- (NSString*) taskDescription;

- (void) setTaskDescription: (NSString*)taskDescription;

- (NSURLSessionTaskState) state;

- (NSError*) error;

- (NSURLSession*) session;

/* -cancel returns immediately, but marks a task as being canceled.
 * The task will signal -URLSession:task:didCompleteWithError: with an
 * error value of { NSURLErrorDomain, NSURLErrorCancelled }. In some 
 * cases, the task may signal other work before it acknowledges the 
 * cancelation.  -cancel may be sent to a task that has been suspended.
 */
- (void) cancel;

/*
 * Suspending a task will prevent the NSURLSession from continuing to
 * load data.  There may still be delegate calls made on behalf of
 * this task (for instance, to report data received while suspending)
 * but no further transmissions will be made on behalf of the task
 * until -resume is sent.  The timeout timer associated with the task
 * will be disabled while a task is suspended.
 */
- (void) suspend;
- (void) resume;

@end

@interface NSURLSessionDataTask : NSURLSessionTask
@end

@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

@interface NSURLSessionDownloadTask : NSURLSessionTask
@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
@interface NSURLSessionStreamTask : NSURLSessionTask
@end
#endif

/*
 * Configuration options for an NSURLSession.  When a session is
 * created, a copy of the configuration object is made - you cannot
 * modify the configuration of a session after it has been created.
 */
@interface NSURLSessionConfiguration : NSObject <NSCopying>
{
  NSURLCache               *_URLCache;
  NSURLRequestCachePolicy  _requestCachePolicy;
  NSArray                  *_protocolClasses;
  NSInteger                _HTTPMaximumConnectionsPerHost;
  BOOL                     _HTTPShouldUsePipelining;
  NSHTTPCookieAcceptPolicy _HTTPCookieAcceptPolicy;
  NSHTTPCookieStorage      *_HTTPCookieStorage;
}

- (NSURLCache*) URLCache;

- (void) setURLCache: (NSURLCache*)cache;

- (NSURLRequestCachePolicy) requestCachePolicy;

- (void) setRequestCachePolicy: (NSURLRequestCachePolicy)policy;

- (NSArray*) protocolClasses;

- (NSInteger) HTTPMaximumConnectionsPerHost;

- (void) setHTTPMaximumConnectionsPerHost: (NSInteger)n;

- (BOOL) HTTPShouldUsePipelining;

- (void) setHTTPShouldUsePipelining: (BOOL)flag;

- (NSHTTPCookieAcceptPolicy) HTTPCookieAcceptPolicy;

- (void) setHTTPCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)policy;

- (NSHTTPCookieStorage*) HTTPCookieStorage;

- (void) setHTTPCookieStorage: (NSHTTPCookieStorage*)storage;

@end

@protocol NSURLSessionDelegate <NSObject>

/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case the error parameter will be nil.
 */
- (void)         URLSession: (NSURLSession*)session 
  didBecomeInvalidWithError: (NSError*)error;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete. 
 */
- (void )   URLSession: (NSURLSession*)session 
                  task: (NSURLSessionTask*)task
  didCompleteWithError: (NSError*)error;
     
/* Periodically informs the delegate of the progress of sending body content 
 * to the server.
 */
- (void)       URLSession: (NSURLSession*)session 
                     task: (NSURLSessionTask*)task 
          didSendBodyData: (int64_t)bytesSent 
           totalBytesSent: (int64_t)totalBytesSent 
 totalBytesExpectedToSend: (int64_t)totalBytesExpectedToSend;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>

/* Sent when data is available for the delegate to consume.
 */
- (void) URLSession: (NSURLSession*)session 
           dataTask: (NSURLSessionDataTask*)dataTask
     didReceiveData: (NSData*)data;

@end

#endif
#endif
