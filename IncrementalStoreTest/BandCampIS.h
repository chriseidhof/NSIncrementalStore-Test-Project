//
//  BandCampIS.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface BandCampIS : NSIncrementalStore

/**
 *  @returns The type identifier of BandCampIS stores
 */
+ (NSString*)type;

@end
