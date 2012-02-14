//
//  Album.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Album : NSManagedObject

@property (nonatomic, retain) NSString * artist;
@property (nonatomic, retain) NSString * large_art_url;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSSet *tracks;
@end

@interface Album (CoreDataGeneratedAccessors)

- (void)addTracksObject:(NSManagedObject *)value;
- (void)removeTracksObject:(NSManagedObject *)value;
- (void)addTracks:(NSSet *)values;
- (void)removeTracks:(NSSet *)values;

@end
