//
//  BandCampIS.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "BandCampIS.h"
#import "BandCampAPI.h"
#import "NSArray+Map.h"

@interface BandCampIS () {
    NSMutableDictionary* cache;
}

// Helper methods
- (NSManagedObjectID*)objectIdForNewObjectOfEntity:(NSEntityDescription*)entityDescription
                                       cacheValues:(NSDictionary*)values;
- (NSString*)nativeKeyForEntityName:(NSString*)entityName;
- (id)fetchObjects:(NSFetchRequest*)request withContext:(NSManagedObjectContext*)context;
- (NSArray*)fetchDiscographyForBandWithId:(NSManagedObjectID*)objectID albumEntity:(NSEntityDescription*)entity;
- (NSArray*)fetchTracksForAlbumWithId:(NSManagedObjectID*)objectID trackEntity:(NSEntityDescription*)entity;

@end

@implementation BandCampIS

+ (void)initialize {
    [NSPersistentStoreCoordinator registerStoreClass:[BandCampIS class] forStoreType:[BandCampIS type]];
}

+ (NSString*)type {
    return @"BandCampIS";
}

+ (NSManagedObjectModel*)model {
    NSURL *modelURL;
    if ([[[NSBundle mainBundle] executablePath] rangeOfString:@"otest"].length != 0) {
        // Test bundle is run headless, find model inside the octest bundle:
        modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"BandCamp" withExtension:@"momd"];
    } else {
        // The test bundle is injected into iPhone app, find model there:
        modelURL = [[NSBundle mainBundle] URLForResource:@"BandCamp" withExtension:@"momd"];
    }
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator*)root configurationName:(NSString*)name URL:(NSURL*)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:root configurationName:name URL:url options:options];
    if (self) {
        cache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)loadMetadata:(NSError**)error {
    // TODO: find out how to generate the UUID? Does it matter?
    NSString* uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [self setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:[BandCampIS type], NSStoreTypeKey, uuid, NSStoreUUIDKey, nil]];
    return YES;
}

- (id)executeRequestBlocking:(NSPersistentStoreRequest*)request 
         withContext:(NSManagedObjectContext*)context 
               error:(NSError**)error {
    NSLog(@"Executing blocking request ..");
    
    if(request.requestType == NSFetchRequestType) {
        NSFetchRequest *fetchRequest = (NSFetchRequest*)request;
        switch (fetchRequest.resultType) {
            case NSManagedObjectResultType:
                return [self fetchObjects:fetchRequest withContext:context];
                
            case NSManagedObjectIDResultType:
                return [self fetchObjectIDs:fetchRequest withContext:context];
        }
    }

    NSLog(@"unimplemented request: %@", request);
    return nil;
}

- (id)executeRequest:(NSPersistentStoreRequest*)request 
         withContext:(NSManagedObjectContext*)context 
               error:(NSError**)error {
    return [self executeRequestAsyncAndSync:request withContext:context error:error];
}

- (id)fetchObjectIDs:(NSFetchRequest*)request withContext:(NSManagedObjectContext*)context {
    NSArray* items = [BandCampAPI apiRequestEntitiesWithName:request.entityName predicate:request.predicate];
    return [items map:^(id item) {
        return [self objectIdForNewObjectOfEntity:request.entity cacheValues:item];
    }];
}

- (id)fetchObjects:(NSFetchRequest*)request withContext:(NSManagedObjectContext*)context {
    NSArray* items = [self fetchObjectIDs:request withContext:context];
    return [items map:^(id item) {
        return [context objectWithID:item];
    }];
}

- (NSIncrementalStoreNode*)newValuesForObjectWithID:(NSManagedObjectID*)objectID 
                                        withContext:(NSManagedObjectContext*)context
                                              error:(NSError**)error {
    NSDictionary* values = [cache objectForKey:objectID];
    NSIncrementalStoreNode* node = 
        [[NSIncrementalStoreNode alloc] initWithObjectID:objectID
                                              withValues:values 
                                                 version:1];
    return node;
}

- (NSArray*)obtainPermanentIDsForObjects:(NSArray*)array error:(NSError**)error {
    // not implemented, we don't support saving
    return nil;
}

- (id)newValueForRelationship:(NSRelationshipDescription*)relationship forObjectWithID:(NSManagedObjectID*)objectID withContext:(NSManagedObjectContext*)context error:(NSError**)error {
    if([relationship.name isEqualToString:@"discography"]) {
        return [self fetchDiscographyForBandWithId:objectID 
                                       albumEntity:relationship.destinationEntity];
    } else if([relationship.name isEqualToString:@"tracks"]) {
        return [self fetchTracksForAlbumWithId:objectID 
                                   trackEntity:relationship.destinationEntity];
    }
    NSLog(@"unknown relatioship: %@", relationship);
    return nil;
}

#pragma mark Relationship fetching

- (NSArray*)fetchDiscographyForBandWithId:(NSManagedObjectID*)objectID
                              albumEntity:(NSEntityDescription*)entity {
    id bandId = [self referenceObjectForObjectID:objectID];            
    NSArray* discographyData = [BandCampAPI apiDiscographyForBandWithId:bandId];
    return [discographyData map:^(id album) {
        return [self objectIdForNewObjectOfEntity:entity cacheValues:album];
        
    }];
}

- (NSArray*)fetchTracksForAlbumWithId:(NSManagedObjectID*)objectID trackEntity:(NSEntityDescription*)entity {
    NSDictionary* albumData = [cache objectForKey:objectID];
    NSArray* tracks = [albumData objectForKey:@"tracks"];
    return [tracks map:^(id trackData){
        return [self objectIdForNewObjectOfEntity:entity cacheValues:trackData];
        
    }];
}

#pragma mark Caching

- (NSManagedObjectID*)objectIdForNewObjectOfEntity:(NSEntityDescription*)entityDescription
                                       cacheValues:(NSDictionary*)values {
    NSString* nativeKey = [self nativeKeyForEntityName:entityDescription.name];
    id referenceId = [values objectForKey:nativeKey];
    NSManagedObjectID *objectId = [self newObjectIDForEntity:entityDescription 
                                             referenceObject:referenceId];
    [cache setObject:values forKey:objectId];
    return objectId;
}

- (NSString*)nativeKeyForEntityName:(NSString*)entityName {
    return [[entityName lowercaseString] stringByAppendingString:@"_id"];
}

- (NSArray*)objectIdsInCacheMatchingFetchRequest:(NSFetchRequest*)fetchRequest {
    NSMutableArray *matchingIds = [NSMutableArray arrayWithCapacity:[cache count]];
    [cache enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSManagedObjectID *objectID, NSDictionary *cachedValues, BOOL *stop) {
        if ([[objectID entity] isEqual:fetchRequest.entity]) {
            if ([fetchRequest.predicate evaluateWithObject:cachedValues]) {
                [matchingIds addObject:objectID];
            }
        }
    }];
    return [NSArray arrayWithArray:matchingIds];
}

- (id)executeRequestCached:(NSPersistentStoreRequest*)request withContext:(NSManagedObjectContext*)context error:(NSError**)error {
    if(request.requestType == NSFetchRequestType) {
        NSFetchRequest *fetchRequest = (NSFetchRequest*)request;
        switch (fetchRequest.resultType) {
            case NSManagedObjectResultType:
                // todo: handle stuff like sorting, limiting, etc. 
                return [[self objectIdsInCacheMatchingFetchRequest:fetchRequest] map:^id(NSManagedObjectID* objectID) {
                    return [context existingObjectWithID:objectID error:nil];
                }];
                
            case NSManagedObjectIDResultType:
                // todo: handle stuff like sorting, limiting, etc. 
                return [self objectIdsInCacheMatchingFetchRequest:fetchRequest];
        }
    }
    
    NSLog(@"Un-implemented method for request: %@", request);
    if (error) {
        // *error = ... 
    }
    return nil;
}

#pragma mark MOC registration

- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray*)objectIDs {
    [super managedObjectContextDidRegisterObjectsWithIDs:objectIDs];
    NSLog(@"__register %@: %@", [NSThread isMainThread] ? @"(mainThread)" : @"(bgThread)", objectIDs);
}

// Inform the store that the objects with ids in objectIDs are no longer in use in a client NSManagedObjectContext
- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray*)objectIDs {
    [super managedObjectContextDidUnregisterObjectsWithIDs:objectIDs];
    NSLog(@"UNregister %@: %@", [NSThread isMainThread] ? @"(mainThread)" : @"(bgThread)", objectIDs);

}


@end
