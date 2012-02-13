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
           cp.rightExpression.expressionType == NSConstantValueExpressionType &&
           [cp.rightExpression.constantValue isKindOfClass:[NSString class]]) {
            NSString* key = cp.leftExpression.keyPath;
            NSString* value = [cp.rightExpression.constantValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString* queryPart = [NSString stringWithFormat:@"&%@=%@", key, value];
            return queryPart;
        } else {
            NSLog(@"didn't understand predicate: %@", predicate);
        }
    } else {
        NSLog(@"didn't understand predicate: %@", predicate);
    }
    return nil;
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if (request.requestType == NSFetchRequestType)
    {
        NSFetchRequest *fRequest = (NSFetchRequest*) request;
        if (fRequest.resultType==NSManagedObjectResultType) { //see the class reference for a discussion of the types
            if ([fRequest.entityName isEqualToString:@"Band"]) {
                NSString* searchURLString = @"http://api.bandcamp.com/api/band/3/search?key=snaefellsjokull&debug";
                if(fRequest.predicate != nil) {
                    NSString* queryPart = [self generateQueryPartForPredicate:fRequest.predicate];
                    searchURLString = [searchURLString stringByAppendingString:queryPart];
                }
                NSURL* searchURL = [NSURL URLWithString:searchURLString];
                NSData* data = [NSData dataWithContentsOfURL:searchURL];
                NSDictionary* response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                NSArray* items = [response objectForKey:@"results"];
                NSMutableArray* result = [NSMutableArray arrayWithCapacity:[items count]]; 
                for(NSDictionary* item in items) {
                    id jsonId = [item objectForKey:@"band_id"];
                    NSManagedObjectID *oid = [self newObjectIDForEntity:fRequest.entity referenceObject:jsonId];
                    NSIncrementalStoreNode * node = [[NSIncrementalStoreNode alloc] initWithObjectID: oid withValues:item version:1];
                    [cache setObject:node forKey:oid];
                    NSManagedObject* object = [context objectWithID:oid];
                    [result addObject:object];

                }
                return result;

            } else {
                NSLog(@"unexpected entitiy: %@", fRequest.entityName);
            }
        } else {
            NSLog(@"unknown result type: %d", fRequest.resultType);
        }
    } else {
        NSLog(@"unkonwn request: %@", request);
    }
    
    return nil;
} 

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    return [cache objectForKey:objectID];
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error {
    NSLog(@"obtain permanent ids"); // todo
    return nil;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    NSLog(@"obtain permanent ids");
    if([relationship.entity.name isEqualToString:@"Band"]) {
        if ([relationship.name isEqualToString:@"discography"]) {
            NSManagedObject* band = [context objectWithID:objectID];
            NSString* bandId = [band valueForKey:@"band_id"];
            NSString* searchURLString = [NSString stringWithFormat:@"http://api.bandcamp.com/api/band/3/discography?key=snaefellsjokull&band_id=%@", bandId];
            NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:searchURLString]];
            NSDictionary* discography = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSMutableArray* results = [NSMutableArray array];
            for(NSDictionary* album in [discography objectForKey:@"discography"]) {
                // todo copy pasted
                id jsonId = [album objectForKey:@"album_id"];
                NSManagedObjectID *oid = [self newObjectIDForEntity:relationship.destinationEntity referenceObject:jsonId];
                NSIncrementalStoreNode * node = [[NSIncrementalStoreNode alloc] initWithObjectID: oid withValues:album version:1];
                [cache setObject:node forKey:oid];
                [results addObject:oid];
            }
            return results;
        }
    }
    NSLog(@"relationship for unknown entity: %@", relationship.entity);
    return nil;
}

@end
