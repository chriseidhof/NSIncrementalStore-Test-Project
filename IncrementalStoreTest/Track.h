//
//  Track.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Track : NSManagedObject

@property (nonatomic, retain) NSNumber * track_id;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * number;
@property (nonatomic, retain) NSNumber * duration;

@end
