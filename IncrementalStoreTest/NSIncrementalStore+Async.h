//
//  NSIncrementalStore+Async.h
//
//  Created by Martijn Thé on 3/1/12.
//  Copyright (c) 2012 martijnthe.nl All rights reserved.
//

/**
 *  NSIncrementalStore+Async
 *
 *  The goal of this set of helpers is to make it easy to write an NSIncrementalStore subclasses that
 *  have slow backing stores, e.g. web services or remote databases.
 *
 *  It helps you by abstracting away the details of executing NSFetchRequests in the background, faulting
 *  the results back into the caller's context, etc.
 *
 *  NSFetchRequest (and later NSAsyncSaveChangesRequest) are subclassed and decorated with the
 *  protocol NSAsyncIncrementalStoreRequest. This protocol provides additional properties and methods like
 *  willStartBlock, didFinishBlock, -cancel, queue, etc.
 *  These 'async' requests return immediately when executed, either returning cached objects that match the request
 *  or an empty array, depending on the returnsCachedResultsImmediately property of the request and the store's cache itself.
 *
 *
 *  How-to
 *  
 *  In your NSIncrementalStore subclass, do all blocking work inside -executeRequestBlocking:withContext:error:
 *  (or rename your current -executeRequest:withContext:error: if you already had one).
 *  Avoid doing blocking work inside -newValuesForObjectWithID:withContext:error:, it is assumed you have already loaded 
 *  the data in -executeRequestBlocking:.. and have cached the values.
 *  Call -executeRequestAsyncAndSync:withContext:error: inside the required -executeRequest:withContext:error: method.
 *  Just pass the arguments and return the result directly.
 *  
 *  Then use NSAsyncFetchRequest whereever you want to fetch objects asynchronically.
 *  Optionally set it's additional properties like didFinishBlock, returnsCachedResultsImmediately, etc.
 *  Optionally implement the NSIncrementalStoreExecuteRequestCached and NSIncrementalStoreRequestQueuing protocols on the store.
 *
 *
 *  Assumptions about your incremental store subclass
 *  
 *  - All blocking work is done inside -executeRequestBlocking:withContext:error:
 *  - Other required methods like, -newValuesForObjectWithID:withContext:error:, should not be blocking
 *  - Your incremental store needs to be able to handle fetch requests with resultType NSManagedObjectIDResultType.
 *
 *
 *  Todos:
 *
 *  - Handle save requests
 *  - Add documentation to the methods, properties, etc.
 *  - Respect resultType of request when calling the didFinishBlock
 *  - Add a convenience method to dynamically replace the -executeRequest: with -executeRequestAsyncAndSync: and add -executeRequestBlocking:
 *  - Optimize the performance of the process of faulting objects into the caller's context
 *  - Add a block handler to report the progress?
 *
 **/
 

#import <CoreData/CoreData.h>

#pragma mark - General stuff, errors, etc.

extern NSString* NSAsyncIncrementalStoreErrorDomain;

typedef enum {
    NSAsyncIncrementalStoreErrorUnimplemented,
    NSAsyncIncrementalStoreErrorCancelled,
    NSAsyncIncrementalStoreErrorExecutingRequest
} NSAsyncIncrementalStoreError;



#pragma mark - NSPersistentStoreRequest helpers, protocols, templates, etc.

@protocol NSAsyncIncrementalStoreRequest <NSObject>
@required // perhaps make some @optional later on
@property (nonatomic, readwrite, strong) void(^willStartBlock)(void);
@property (nonatomic, readwrite, strong) void(^didFinishBlock)(id results, NSError *error);
@property (nonatomic, readwrite, assign) BOOL returnsCachedResultsImmediately; // should default to YES
@property (nonatomic, readwrite, strong) NSOperationQueue* queue; // if nil, the -queueForRequest: will be called on the store
@property (atomic, readonly, assign) BOOL isCancelled;
- (void)cancel;
@end

@interface NSAsyncFetchRequest : NSFetchRequest <NSAsyncIncrementalStoreRequest> @end
//@interface NSAsyncSaveChangesRequest : NSSaveChangesRequest <NSAsyncIncrementalStoreRequest> @end // TODO



#pragma mark - NSIncrementalStore helpers, protocols, templates, etc.

@interface NSIncrementalStore (Async)
- (id)executeRequestAsyncAndSync:(NSPersistentStoreRequest*)request withContext:(NSManagedObjectContext*)context error:(NSError**)error;
@end

@protocol NSIncrementalStoreExecuteRequestBlocking <NSObject>
@required
- (id)executeRequestBlocking:(NSPersistentStoreRequest*)request withContext:(NSManagedObjectContext*)context error:(NSError**)error;
@end

@protocol NSIncrementalStoreExecuteRequestCached <NSObject>
@required
- (id)executeRequestCached:(NSPersistentStoreRequest*)request withContext:(NSManagedObjectContext*)context error:(NSError**)error;
@end

@protocol NSIncrementalStoreRequestQueuing <NSObject>
- (NSOperationQueue*)queueForRequest:(NSPersistentStoreRequest*)request; // if nil or not implemented, a new queue will be used for each request
@end
