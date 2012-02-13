//
//  Band.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Album;

@interface Band : NSManagedObject

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * offsite_url;
@property (nonatomic, retain) NSString * subdomain;
@property (nonatomic, retain) NSNumber * band_id;
@property (nonatomic, retain) NSSet *discography;
@end

@interface Band (CoreDataGeneratedAccessors)

- (void)addDiscographyObject:(Album *)value;
- (void)removeDiscographyObject:(Album *)value;
- (void)addDiscography:(NSSet *)values;
- (void)removeDiscography:(NSSet *)values;

@end
