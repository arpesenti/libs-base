#ifndef	INCLUDED_GSTASKREGISTRY_H
#define	INCLUDED_GSTASKREGISTRY_H

#import <Foundation/Foundation.h>

@class NSURLSessionTask;

@interface GSTaskRegistry : NSObject

- (void ) addTask: (NSURLSessionTask*)task;

- (void) removeTask: (NSURLSessionTask*)task;

- (void) notifyOnTasksCompletion: (void (^)(void))tasksCompletion;

- (NSArray*) allTasks;

- (BOOL) isEmpty;

@end

#endif