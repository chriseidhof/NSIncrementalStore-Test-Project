//
//  NSIncrementalStore+Async.m
//
//  Created by Martijn Thé on 3/1/12.
//  Copyright (c) 2012 martijnthe.nl All rights reserved.
//

#import "NSIncrementalStore+Async.h"

NSString* NSAsyncIncrementalStoreErrorDomain = @"nl.martijnthe.asyncincrementalstore";

@implementation NSAsyncFetchRequest
@synthesize willStartBlock;
@synthesize didFinishBlock;
@synthesize returnsCachedResultsImmediately;
@synthesize queue;
@synthesize isCancelled;

- (void)cancel {
    @synchronized(self) {
        isCancelled = YES;
    }
}

@end


#pragma mark - NSIncrementalStore helpers, protocols, templates, etc.

@implementation NSIncrementalStore (Async)

#define callDidFinishBlock(callerQueue, asyncRequest, results, error) \
    if (asyncRequest.didFinishBlock) { \
        NSOperationQueue* _callerQueue = callerQueue; \
        if (_callerQueue) { \
            [_callerQueue addOperationWithBlock:^{ \
                asyncRequest.didFinishBlock(results, error); \
                asyncRequest.didFinishBlock = nil; \
            }]; \
        } else { \
            asyncRequest.didFinishBlock(results, error); \
            asyncRequest.didFinishBlock = nil; \
        } \
    }

- (id)executeRequestAsyncAndSync:(NSPersistentStoreRequest*)request withContext:(NSManagedObjectContext*)callerMoc error:(NSError**)error {
    if ([request conformsToProtocol:@protocol(NSAsyncIncrementalStoreRequest)] == NO) {
        // request is not an async request, just go down the regular path:
        return [(id<NSIncrementalStoreExecuteRequestBlocking>)self executeRequestBlocking:request withContext:callerMoc error:error];
    } else {
        NSPersistentStoreRequest<NSAsyncIncrementalStoreRequest>* asyncRequest = (NSPersistentStoreRequest<NSAsyncIncrementalStoreRequest>*)request;
        
        // Keep a reference to the original queue, we want to run the handler ('delegate') blocks on this queue.
        NSOperationQueue* callerQueue = [NSOperationQueue currentQueue];
        
        if (asyncRequest.isCancelled) {
            NSError* cancelError = [NSError errorWithDomain:NSAsyncIncrementalStoreErrorDomain code:NSAsyncIncrementalStoreErrorCancelled userInfo:nil];
            if (error) {
                *error = cancelError;
            }
            callDidFinishBlock(nil, asyncRequest, nil, cancelError);
            return nil;
        }
        
        // We're dealing with an async request,
        // so 2 things need to be done: 1) execute the request on a queue, 2) return cached results immediately (optionally)
        
        // 1)        
        // Figure out which queue to use by cascading:
        NSOperationQueue* requestQueue;
        if (asyncRequest.queue) {
            requestQueue = asyncRequest.queue;
        }
        if (requestQueue == nil && [self conformsToProtocol:@protocol(NSIncrementalStoreRequestQueuing)]) {
            requestQueue = [(id<NSIncrementalStoreRequestQueuing>)self queueForRequest:asyncRequest];
        }
        if (requestQueue == nil) {
            requestQueue = [[NSOperationQueue alloc] init];
        }
        
        [requestQueue addOperationWithBlock:^{
            
            // Check if cancelled:
            if (asyncRequest.isCancelled) {
                callDidFinishBlock(callerQueue, asyncRequest, nil, [NSError errorWithDomain:NSAsyncIncrementalStoreErrorDomain code:NSAsyncIncrementalStoreErrorCancelled userInfo:nil]);
                return;
            }
            
            if (asyncRequest.willStartBlock) {
                [callerQueue addOperationWithBlock:^{
                    asyncRequest.willStartBlock();
                    asyncRequest.willStartBlock = nil;
                }];
            }
            
            // Prepare background request + moc:
            NSManagedObjectContext* bgMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
            // bgMoc.parentContext = self.moc; // <-- this will cause a call executeRequest:withContext:error: to the store on the CALLER's (MAIN) THREAD... :-S
            bgMoc.persistentStoreCoordinator = callerMoc.persistentStoreCoordinator;
            NSPersistentStoreRequest<NSAsyncIncrementalStoreRequest>* bgRequest;
            switch (asyncRequest.requestType) {
                case NSFetchRequestType: {
                    NSFetchRequest<NSAsyncIncrementalStoreRequest>* bgFetchRequest = [asyncRequest copy];
                    bgFetchRequest.entity = [NSEntityDescription entityForName:bgFetchRequest.entityName inManagedObjectContext:bgMoc];
                    bgFetchRequest.resultType = NSManagedObjectIDResultType; // get objectIDs, we fault the objects into the callerMoc later on
                    bgRequest = bgFetchRequest;
                    break;
                }
                case NSSaveRequestType: {
                    
                    // TODO:
                    // NSSaveChangesRequests contain references to the inserted, updated and deleted objects that need to be saved.
                    // We cannot use these objects on this queue (thread/queue confinement).
                    // Faulting them into this context is not going to work either, because then they won't contain the changes.
                    // So at some point in time, the changed objects faulted into the bg context and
                    // their changed properties need to be copied from the objects in the caller moc.
                                        
                    // break; // for now, fall-thru
                }
                default: {
                    // Finish with 'unimplemented' error:
                    callDidFinishBlock(callerQueue, asyncRequest, nil, [NSError errorWithDomain:NSAsyncIncrementalStoreErrorDomain code:NSAsyncIncrementalStoreErrorUnimplemented userInfo:nil]);
                    return;
                }
            }
            
            // Finally, run the (blocking) request:
            NSError* executeError = nil;
            NSArray* objectIDs = [(id<NSIncrementalStoreExecuteRequestBlocking>)self executeRequestBlocking:bgRequest withContext:callerMoc error:error];
            
            // Handle executeError:
            if (objectIDs == nil) {
                NSDictionary* userInfo = nil;
                if (error) {
                    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:executeError, NSUnderlyingErrorKey, nil];
                }
                NSError* wrappedError = [NSError errorWithDomain:NSAsyncIncrementalStoreErrorDomain code:NSAsyncIncrementalStoreErrorExecutingRequest userInfo:userInfo];
                callDidFinishBlock(callerQueue, asyncRequest, nil, wrappedError);
                return;
            }
            
            // Check if cancelled:
            if (asyncRequest.isCancelled) {
                callDidFinishBlock(callerQueue, asyncRequest, nil, [NSError errorWithDomain:NSAsyncIncrementalStoreErrorDomain code:NSAsyncIncrementalStoreErrorCancelled userInfo:nil]);
                return;
            }
            
            // Fault objects into callerMoc & refresh objects:
            [callerQueue addOperationWithBlock:^{
                // At this point in time, the newly fetched objects are not registered in callerMoc, but only in bgMoc
                
                NSError* lookupError = nil;
                NSManagedObject* mObject;
                NSMutableArray* results = [NSMutableArray arrayWithCapacity:[objectIDs count]];
                for (NSManagedObjectID *objectID in objectIDs) {
                    // -existingObjectWithID:error: causes the object to "register" in the callerMoc (-managedObjectContextDidRegisterObjectsWithIDs: is also called on the IncrementalStore).
                    // It also fires the fault, which is important, because the objects like NSFetchedResultsController will filter the registeredObjects in-memory based on its the fetchRequest.
                    mObject = [callerMoc existingObjectWithID:objectID error:&lookupError];
                    // Interestingly, even though existingObjectWithID:error: will cause objects to be "registered" in the context, its does not cause NSManagedObjectContextObjectsDidChangeNotifications to fire...
                    if (mObject) {
                        // -refreshObject:mergeChanges: trigger the NSManagedObjectContextObjectsDidChangeNotification which drives the change-monitoring features of objects like NSFetchedResultsController
                        // NOTE: I suspect this could be optimized to avoid triggering change notifications for objects that were already in the callerMoc AND have not been changed in the mean while.
                        [callerMoc refreshObject:mObject mergeChanges:YES];
                        [results addObject:mObject];
                    } else {
                        NSLog(@"Error trying to look up object in moc: %@", lookupError);
                    }
                }
                
                // TODO: respect the resultType of a fetch request (now we're always returning managed objects)
                
                // Done without errors:
                callDidFinishBlock(nil, asyncRequest, results, nil);
            }];
        }];
        
        // 2)
        // If cache is requested immediately and the store implements the method to do that, return cache:
        if (asyncRequest.returnsCachedResultsImmediately && [self conformsToProtocol:@protocol(NSIncrementalStoreExecuteRequestCached)]) {
            return [(id<NSIncrementalStoreExecuteRequestCached>)self executeRequestCached:request withContext:callerMoc error:error];
        } else {
            // Else, always return an empty array, otherwise an error will be assumed by the caller:
            return [NSArray array];
        }
    }
}

@end
