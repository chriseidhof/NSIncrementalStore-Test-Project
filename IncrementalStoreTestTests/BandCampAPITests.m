//
//  BandCampAPITests.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/18/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "BandCampAPITests.h"
#import "BandCampAPI.h"
#import "NSURLConnectionVCR.h"

#define QUOTE(str) #str
#define EXPAND_AND_QUOTE(str) QUOTE(str)

@implementation BandCampAPITests

- (void)setUp {
    [super setUp];
    
    NSError* error = nil;
    NSString* path = [NSString stringWithFormat:@"%s/IncrementalStoreTestTests/Fixtures/VCRTapes", EXPAND_AND_QUOTE(SRCROOT)];
    STAssertTrue([NSURLConnectionVCR startVCRWithPath:path error:&error], @"VCR failed to start: %@", error);
}

- (void)tearDown {
    NSError* error = nil;
    STAssertTrue([NSURLConnectionVCR stopVCRWithError:&error], @"VCR failed to stop: %@", error);
    
    [super tearDown];
}

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
