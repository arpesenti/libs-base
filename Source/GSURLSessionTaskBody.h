#ifndef	INCLUDED_GSURLSESSIONTASKBODY_H
#define	INCLUDED_GSURLSESSIONTASKBODY_H

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, GSURLSessionTaskBodyType) {
    GSURLSessionTaskBodyTypeNone,
    GSURLSessionTaskBodyTypeData,
    GSURLSessionTaskBodyTypeFile,
    GSURLSessionTaskBodyTypeStream,
};

@interface GSURLSessionTaskBody : NSObject
{
  GSURLSessionTaskBodyType  _type;
  NSData                    *_data;
  NSURL                     *_fileURL;
  NSInputStream             *_inputStream;
}

- (instancetype) init;
- (instancetype) initWithData: (NSData*)data;
- (instancetype) initWithFileURL: (NSURL*)fileURL;
- (instancetype) initWithInputStream: (NSInputStream*)inputStream;

- (NSNumber*) getBodyLengthWithError: (NSError**)error;

@end

#endif
