//
//  BandCampAPI.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "BandCampAPI.h"

@implementation BandCampAPI

+ (NSString*)generateQueryPartForPredicate:(NSPredicate*)predicate {
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

+ (NSString*)apiMethodForPredicate:(NSPredicate*)predicate {
    if([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate* cp = (NSComparisonPredicate*)predicate;
        if(cp.leftExpression.expressionType == NSKeyPathExpressionType &&
           [cp.leftExpression.keyPath isEqualToString:@"name"]) {
            return @"search";
        }
    }
    return @"info";
}

+ (NSInteger)apiVersionForEntityName:(NSString*)entityName {
    if([entityName isEqualToString:@"Band"]) return 3;
    if([entityName isEqualToString:@"Album"]) return 2;
    if([entityName isEqualToString:@"Track"]) return 1;
    if([entityName isEqualToString:@"URL"]) return 1;
    
    return 1;
}

+ (NSArray*)apiRequestEntitiesWithName:(NSString*)name predicate:(NSPredicate*)predicate {
    NSString* lowercaseName = [name lowercaseString];
    NSInteger version = [self apiVersionForEntityName:name];
    NSString* method = [self apiMethodForPredicate:predicate];
    NSString* searchURLString = [NSString stringWithFormat:@"http://api.bandcamp.com/api/%@/%d/%@?key=snaefellsjokull", lowercaseName, version, method];
    if(predicate != nil) {
        NSString* queryPart = [self generateQueryPartForPredicate:predicate];
        searchURLString = [searchURLString stringByAppendingString:queryPart];
    }
    NSURL* searchURL = [NSURL URLWithString:searchURLString];
    NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:searchURL] returningResponse:nil error:nil];
    NSDictionary* response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if([method isEqualToString:@"search"]) {
        return [response objectForKey:@"results"];
    }
    return [NSArray arrayWithObject:response];
}

+ (NSArray*)apiDiscographyForBandWithId:(NSString*)bandId {
    // todo cache?
    NSString* searchURLString = [NSString stringWithFormat:@"http://api.bandcamp.com/api/band/3/discography?key=snaefellsjokull&band_id=%@", bandId];
    NSURL* searchURL = [NSURL URLWithString:searchURLString];
    NSData* data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:searchURL] returningResponse:nil error:nil];
    NSDictionary* discography = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [discography objectForKey:@"discography"];
}

@end
