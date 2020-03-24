#ifndef	INCLUDED_GSTIMEOUTSOURCE_H
#define	INCLUDED_GSTIMEOUTSOURCE_H

#import <Foundation/Foundation.h>

@interface GSTimeoutSource : NSObject
{
  dispatch_source_t  _rawSource;
  NSInteger          _milliseconds;
  dispatch_queue_t   _queue;
  dispatch_block_t   _handler;
}

- (NSInteger) milliseconds;

- (dispatch_queue_t) queue;

- (dispatch_block_t) handler;

- (instancetype) initWithQueue: (dispatch_queue_t)queue
                  milliseconds: (NSInteger)milliseconds
                       handler: (dispatch_block_t)handler;

@end

#endif