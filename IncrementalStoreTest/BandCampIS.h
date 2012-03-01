//
//  BandCampIS.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "NSIncrementalStore+Async.h"

@interface BandCampIS : NSIncrementalStore <NSIncrementalStoreExecuteRequestCached, NSIncrementalStoreExecuteRequestBlocking>

/**
 *  @returns The type identifier of BandCampIS stores
 */
+ (NSString*)type;

/**
 *	@returns The model for the managed objects in a BandCampIS store
 */
+ (NSManagedObjectModel*)model;

@end
