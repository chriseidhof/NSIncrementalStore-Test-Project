//
//  BandCampAPITests.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/18/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "BandCampAPITests.h"
#import "BandCampAPI.h"

@implementation BandCampAPITests

- (void)testFetchBandByName
{
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"name == %@", @"Rue Royale"];
    NSArray* bands = [BandCampAPI apiRequestEntitiesWithName:@"Band"
                                                   predicate:predicate];
    NSDictionary* rueRoyale = [bands lastObject];
    STAssertEqualObjects([rueRoyale objectForKey:@"name"], @"Rue Royale", @"Name should be Rue Royale");
}

- (void)testFetchBandById {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"band_id == %d", 203035041];
    NSArray* bands = [BandCampAPI apiRequestEntitiesWithName:@"Band"
                                                   predicate:predicate];
    NSDictionary* sufjan = [bands lastObject];
    STAssertEqualObjects([sufjan objectForKey:@"name"], @"Sufjan Stevens", @"Name should be Sufjan Stevens");
}

- (void)testFetchAlbumById {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"album_id == %d", 781775666];
    NSArray* bands = [BandCampAPI apiRequestEntitiesWithName:@"Album"
                                                   predicate:predicate];
    NSDictionary* illinois = [bands lastObject];
    STAssertEqualObjects([illinois objectForKey:@"title"], @"Illinois", @"Album should be Illinois");
}

- (void)testFetchDiscography {
    NSString* sideditchId = [NSString stringWithFormat:@"2721182224"];
    NSArray* albums = [BandCampAPI apiDiscographyForBandWithId:sideditchId];
    STAssertTrue([albums count] >= 1, @"Sideditch should have at least 1 album");
}

@end
