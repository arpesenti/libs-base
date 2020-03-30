#ifndef	INCLUDED_GSURLSESSIONTASKBODYSOURCE_H
#define	INCLUDED_GSURLSESSIONTASKBODYSOURCE_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, GSBodySourceDataChunk) {
    GSBodySourceDataChunkData,
    GSBodySourceDataChunkDone,
    GSBodySourceDataChunkRetryLater,
    GSBodySourceDataChunkError
};

@protocol GSURLSessionTaskBodySource <NSObject>

- (void) getNextChunkWithLength: (NSInteger)length
              completionHandler: (void (^)(GSBodySourceDataChunk chunk, NSData *data))completionHandler;

@end

@interface GSBodyStreamSource : NSObject <GSURLSessionTaskBodySource>

- (instancetype) initWithInputStream: (NSInputStream*)inputStream;

@end

@interface GSBodyDataSource : NSObject <GSURLSessionTaskBodySource>

- (instancetype)initWithData:(NSData *)data;

@end

@interface GSBodyFileSource : NSObject <GSURLSessionTaskBodySource>

- (instancetype) initWithFileURL: (NSURL*)fileURL
                       workQueue: (dispatch_queue_t)workQueue
            dataAvailableHandler: (void (^)(void))dataAvailableHandler;

@end

#endif