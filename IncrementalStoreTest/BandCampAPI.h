//
//  BandCampAPI.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BandCampAPI : NSObject

+ (NSArray*)apiRequestEntitiesWithName:(NSString*)name predicate:(NSPredicate*)predicate;
+ (NSArray*)apiDiscographyForBandWithId:(NSString*)bandId;

@end
