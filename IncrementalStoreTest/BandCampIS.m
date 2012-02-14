//
//  BandCampIS.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "BandCampIS.h"

NSString *MY_STORE_TYPE = @"BandCampIS";

@interface BandCampIS () {
@private
NSMutableDictionary* cache;
}

- (NSManagedObjectID*)objectIdForNewObjectOfEntity:(NSEntityDescription*)entityDescription
                                         nativeKey:(NSString*)nativeKey
                                            values:(NSDictionary*)values;
@end

// TODO: there is code duplication here

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
    [self setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:MY_STORE_TYPE,NSStoreTypeKey,uuid,NSStoreUUIDKey, nil]];
    return YES;
}

- (NSString*)generateQueryPartForPredicate:(NSPredicate*)predicate {
    if([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate* cp = (NSComparisonPredicate*)predicate;
        if(cp.predicateOperatorType == NSEqualToPredicateOperatorType &&
           cp.leftExpression.expressionType == NSKeyPathExpressionType &&
           cp.rightExpression.expressionType == NSConstantValueExpressionType
           ) {
            id rightExpression = cp.rightExpression.constantValue;
            NSString* value = nil;
            if([rightExpression isKindOfClass:[NSString class]]) {
               value = [rightExpression stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]; 
            } else if([rightExpression isKindOfClass:[NSNumber class]]) {
                value = [rightExpression stringValue];
            }
            if(value) {
                NSString* key = cp.leftExpression.keyPath;
                NSString* queryPart = [NSString stringWithFormat:@"&%@=%@", key, value];
                return queryPart;
            }
        }
    }
    NSLog(@"didn't understand predicate");
    return nil;
}

- (NSString*)apiMethodForPredicate:(NSPredicate*)predicate {
    if([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate* cp = (NSComparisonPredicate*)predicate;
        if(cp.leftExpression.expressionType == NSKeyPathExpressionType &&
           [cp.leftExpression.keyPath isEqualToString:@"name"]) {
            return @"search";
        }
    }
    return @"info";
}

- (NSInteger)apiVersionForEntityName:(NSString*)entityName {
    if([entityName isEqualToString:@"Band"]) return 3;
    if([entityName isEqualToString:@"Album"]) return 2;
    if([entityName isEqualToString:@"Track"]) return 1;
    if([entityName isEqualToString:@"URL"]) return 1;
    
    return 1;
}

- (NSArray*)apiRequestEntitiesWithName:(NSString*)name predicate:(NSPredicate*)predicate {
    NSString* lowercaseName = [name lowercaseString];
    NSInteger version = [self apiVersionForEntityName:name];
    NSString* method = [self apiMethodForPredicate:predicate];
    NSString* searchURLString = [NSString stringWithFormat:@"http://api.bandcamp.com/api/%@/%d/%@?key=snaefellsjokull", lowercaseName, version, method];
    if(predicate != nil) {
        NSString* queryPart = [self generateQueryPartForPredicate:predicate];
        searchURLString = [searchURLString stringByAppendingString:queryPart];
    }
    NSURL* searchURL = [NSURL URLWithString:searchURLString];
    NSData* data = [NSData dataWithContentsOfURL:searchURL];
    NSDictionary* response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if([method isEqualToString:@"search"]) {
      return [response objectForKey:@"results"];
    }
    return [NSArray arrayWithObject:response];
}

- (NSString*)nativeKeyForEntityName:(NSString*)entityName {
   NSString* lowercaseName = [entityName lowercaseString];
    return [lowercaseName stringByAppendingString:@"_id"];
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if (request.requestType == NSFetchRequestType)
    {
        NSFetchRequest *fRequest = (NSFetchRequest*) request;
        if (fRequest.resultType==NSManagedObjectResultType) { //see the class reference for a discussion of the types
            NSArray* items = [self apiRequestEntitiesWithName:fRequest.entityName predicate:fRequest.predicate];
            NSMutableArray* result = [NSMutableArray arrayWithCapacity:[items count]]; 
            NSString* nativeKey = [self nativeKeyForEntityName:fRequest.entityName];
            for(NSDictionary* item in items) {
                NSManagedObjectID* oid = [self objectIdForNewObjectOfEntity:fRequest.entity nativeKey:nativeKey values:item];
                NSManagedObject* object = [context objectWithID:oid];
                [result addObject:object];
            }
            return result;
        } else {
            NSLog(@"unknown result type: %d", fRequest.resultType);
        }
    } else {
        NSLog(@"unkonwn request: %@", request);
    }
    
    return nil;
} 

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    NSDictionary* values = [cache objectForKey:objectID];
    NSIncrementalStoreNode* node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:values version:1];
    return node;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error {
    NSLog(@"obtain permanent ids"); // todo
    return nil;
}

- (NSArray*)discographyForBandWithId:(NSString*)bandId {
    // todo cache?
    NSString* searchURLString = [NSString stringWithFormat:@"http://api.bandcamp.com/api/band/3/discography?key=snaefellsjokull&band_id=%@", bandId];
    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:searchURLString]];
    NSDictionary* discography = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [discography objectForKey:@"discography"];
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if([relationship.entity.name isEqualToString:@"Band"]) {
        if ([relationship.name isEqualToString:@"discography"]) {
            id bandId = [self referenceObjectForObjectID:objectID];
            NSMutableArray* results = [NSMutableArray array];
            for(NSDictionary* album in [self discographyForBandWithId:bandId]) {
                NSManagedObjectID* oid = [self objectIdForNewObjectOfEntity:relationship.destinationEntity nativeKey:@"album_id" values:album];
                [results addObject:oid];
            }
            return results;
        }
    } else if([relationship.entity.name isEqualToString:@"Album"]) {
        if([relationship.name isEqualToString:@"tracks"]) {
            NSDictionary* values = [cache objectForKey:objectID];
            NSArray* tracks = [values objectForKey:@"tracks"];
            NSMutableArray* results = [NSMutableArray array];
            for(NSDictionary* trackData in tracks) {
                NSManagedObjectID* oid = [self objectIdForNewObjectOfEntity:relationship.destinationEntity nativeKey:@"track_id" values:trackData];
                [results addObject:oid];
            }
            return results;
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
