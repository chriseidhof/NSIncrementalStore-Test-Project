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

+ (NSString*)type {
    return @"BandCampIS";
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

- (id)executeRequest:(NSPersistentStoreRequest*)request 
         withContext:(NSManagedObjectContext*)context 
               error:(NSError**)error {
    if(request.requestType == NSFetchRequestType)
    {
        NSFetchRequest *fetchRequest = (NSFetchRequest*)request;
        if(fetchRequest.resultType == NSManagedObjectResultType) {
            return [self fetchObjects:fetchRequest withContext:context];
        }
    }
    
    NSLog(@"unimplemented request: %@", request);    
    return nil;
} 

- (id)fetchObjects:(NSFetchRequest*)request 
       withContext:(NSManagedObjectContext*)context {
    NSArray* items = [BandCampAPI apiRequestEntitiesWithName:request.entityName 
                                                   predicate:request.predicate];
    return [items map:^(id item) {
        NSManagedObjectID* oid = [self objectIdForNewObjectOfEntity:request.entity 
                                                        cacheValues:item];
        return [context objectWithID:oid];
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

@end
