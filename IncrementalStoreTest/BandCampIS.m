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

NSString *BANDCAMP_STORE_TYPE = @"BandCampIS";

@interface BandCampIS () {
@private
NSMutableDictionary* cache;
}

- (NSManagedObjectID*)objectIdForNewObjectOfEntity:(NSEntityDescription*)entityDescription
                                         nativeKey:(NSString*)nativeKey
                                            values:(NSDictionary*)values;

@end

@implementation BandCampIS

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)root configurationName:(NSString *)name URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:root configurationName:name URL:url options:options];
    if (self) {
        cache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    //todo hack
    NSString* uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [self setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:BANDCAMP_STORE_TYPE,NSStoreTypeKey,uuid,NSStoreUUIDKey, nil]];
    return YES;
}

- (NSString*)nativeKeyForEntityName:(NSString*)entityName {
   NSString* lowercaseName = [entityName lowercaseString];
    return [lowercaseName stringByAppendingString:@"_id"];
}

- (id)fetchObjects:(NSFetchRequest*)request withContext:(NSManagedObjectContext*)context {
    NSArray* items = [BandCampAPI apiRequestEntitiesWithName:request.entityName predicate:request.predicate];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:[items count]]; 
    NSString* nativeKey = [self nativeKeyForEntityName:request.entityName];
    for(NSDictionary* item in items) {
        NSManagedObjectID* oid = [self objectIdForNewObjectOfEntity:request.entity nativeKey:nativeKey values:item];
        NSManagedObject* object = [context objectWithID:oid];
        [result addObject:object];
    }
    return result;
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if(request.requestType == NSFetchRequestType)
    {
        NSFetchRequest *fetchRequest = (NSFetchRequest*) request;
        if (fetchRequest.resultType==NSManagedObjectResultType) {
            return [self fetchObjects:fetchRequest withContext:context];
        }
    }
    
    NSLog(@"unknown request: %@", request);    
    return nil;
} 

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    NSDictionary* values = [cache objectForKey:objectID];
    NSIncrementalStoreNode* node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:values version:1];
    return node;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error {
    // not implemented, we don't support saving
    return nil;
}

// todo refactor

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if([relationship.entity.name isEqualToString:@"Band"]) {
        if ([relationship.name isEqualToString:@"discography"]) {
            id bandId = [self referenceObjectForObjectID:objectID];            
            NSArray* discographyData = [BandCampAPI apiDiscographyForBandWithId:bandId];
            return [discographyData map:^(id album) {
                return [self objectIdForNewObjectOfEntity:relationship.destinationEntity nativeKey:@"album_id" values:album];

            }];
        }
    } else if([relationship.entity.name isEqualToString:@"Album"]) {
        if([relationship.name isEqualToString:@"tracks"]) {
            NSDictionary* values = [cache objectForKey:objectID];
            NSArray* tracks = [values objectForKey:@"tracks"];
            return [tracks map:^(id trackData){
                return [self objectIdForNewObjectOfEntity:relationship.destinationEntity nativeKey:@"track_id" values:trackData];

            }];
        }
    }
    NSLog(@"relationship for unknown entity: %@", relationship.entity);
    return nil;
}

- (NSManagedObjectID*)objectIdForNewObjectOfEntity:(NSEntityDescription*)entityDescription
                                         nativeKey:(NSString*)nativeKey
                                            values:(NSDictionary*)values {
    id jsonId = [values objectForKey:nativeKey];
    NSManagedObjectID *oid = [self newObjectIDForEntity:entityDescription referenceObject:jsonId];
    [cache setObject:values forKey:oid];
    return oid;
}

@end
