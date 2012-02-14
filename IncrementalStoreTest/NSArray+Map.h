//
//  NSArray+Map.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef id(^MapBlock)(id block);

@interface NSArray (Map)

- (NSArray*)map:(MapBlock)block;

@end
