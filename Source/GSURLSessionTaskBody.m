#import "GSURLSessionTaskBody.h"

@implementation GSURLSessionTaskBody

- (instancetype) init 
{
  if (nil != (self = [super init])) 
    {
      _type = GSURLSessionTaskBodyTypeNone;
    }
  
  return self;
}

- (instancetype) initWithData: (NSData*)data 
{
  if (nil != (self = [super init])) 
    {
      _type = GSURLSessionTaskBodyTypeData;
      ASSIGN(_data, data);
    }

  return self;
}

- (instancetype) initWithFileURL: (NSURL*)fileURL 
{
  if (nil != (self = [super init])) 
    {
      _type = GSURLSessionTaskBodyTypeFile;
      ASSIGN(_fileURL, fileURL);
    }

  return self;
}

- (instancetype) initWithInputStream: (NSInputStream*)inputStream 
{
  if (nil != (self = [super init])) 
    {
      _type = GSURLSessionTaskBodyTypeStream;
      ASSIGN(_inputStream, inputStream);
    }
  
  return self;
}

- (void) dealloc
{
  DESTROY(_data);
  DESTROY(_fileURL);
  DESTROY(_inputStream);
  [super dealloc];
}

- (NSNumber*) getBodyLengthWithError: (NSError**)error 
{
  switch (_type) 
    {
      case GSURLSessionTaskBodyTypeNone:
        return [NSNumber numberWithInt: 0];
      case GSURLSessionTaskBodyTypeData:
        return [NSNumber numberWithUnsignedInteger: [_data length]];
      case GSURLSessionTaskBodyTypeFile: 
        {
          NSDictionary *attributes;
          
          attributes = [[NSFileManager defaultManager] 
            attributesOfItemAtPath: [_fileURL path]
            error: error];
          if (!error) 
            {
              NSNumber *size = [attributes objectForKey: NSFileSize];
              return size;
            }
          else 
            {
              return nil;
            }
        }
      case GSURLSessionTaskBodyTypeStream:
          return nil;
    }
}

@end