//
//  NSArray+Map.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/14/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "NSArray+Map.h"

@implementation NSArray (Map)

- (NSArray*)map:(MapBlock)block {
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:self.count];
    for(id item in self) {
        [result addObject:block(item)];
    }
    return result;
}

@end
