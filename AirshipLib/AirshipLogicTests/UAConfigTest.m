/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAConfigTest.h"

#import "UAConfig+Internal.h"

#import <OCMock/OCMock.h>

@implementation UAConfigTest

/* setup and teardown */

- (void)setUp {
    [super setUp];

}

- (void)tearDown {
    [super tearDown];
}

/* tests */

- (void)testUnknownKeyHandling {
    // ensure that unknown values don't crash the app with an unkown key exception

    UAConfig *config =[[UAConfig alloc] init];
    XCTAssertNoThrow([config setValue:@"someValue" forKey:@"thisKeyDoesNotExist"], @"Invalid key incorrectly throws an exception.");
}

- (void)testProductionProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];
    XCTAssertTrue([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a production profile");
}

- (void)testDevelopmentProfileParsing {
    NSString *profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"development-embedded" ofType:@"mobileprovision"];
    XCTAssertFalse([UAConfig isProductionProvisioningProfile:profilePath], @"Incorrectly evaluated a development profile");
}

- (void)testMissingEmbeddedProfile {
    XCTAssertTrue([UAConfig isProductionProvisioningProfile:@""], @"Missing profiles should result in a production mode determination.");
}

- (void)testDeviceTypeDetermination {
    // Make sure we're correctly determining whether or not the config lives on a simulator
    id mockDeviceClass = [OCMockObject niceMockForClass:[UIDevice class]];
    [[[mockDeviceClass stub] andReturn:mockDeviceClass] currentDevice];
    [[[mockDeviceClass expect] andReturn:@"AFakeiPhoneSimulator"] model];

    // First make sure the simulator string works
    UAConfig *simulatorConfig = [[UAConfig alloc] init];
    XCTAssertTrue(simulatorConfig.isSimulator, @"The configuration init method incorrectly determined the isSimulator value on a simulator.");

    // Now make sure the device model string works
    [[[mockDeviceClass expect] andReturn:@"ARealiPhoneDevice"] model];
    UAConfig *deviceConfig = [[UAConfig alloc] init];
    XCTAssertFalse(deviceConfig.isSimulator, @"The configuration init method incorrectly determined the isSimulator value on a device.");

    // OK, back to normal
    [mockDeviceClass stopMocking];
}

- (void)testSimulatorFallback {

    // Ensure that the simulator falls back to the inProduction flag as it was set if there isn't a profile

    UAConfig *configInProduction = [[UAConfig alloc] init];
    configInProduction.profilePath = nil;
    configInProduction.inProduction = YES;
    configInProduction.detectProvisioningMode = YES;
    configInProduction.isSimulator = YES;
    XCTAssertTrue(configInProduction.inProduction, @"Simulators with provisioning detection enabled should return the production value as set.");

    UAConfig *configInDevelopment = [[UAConfig alloc] init];
    configInDevelopment.profilePath = nil;
    configInDevelopment.inProduction = NO;
    configInDevelopment.detectProvisioningMode = YES;
    configInDevelopment.isSimulator = YES;
    XCTAssertFalse(configInDevelopment.inProduction, @"Simulators with provisioning detection enabled should return the production value as set.");
}

- (void)testMissingProvisioningOnDeviceFallback {

    // Ensure that a device falls back to YES rather than inProduction when there isn't a profile

    UAConfig *configInDevelopment =[[UAConfig alloc] init];
    configInDevelopment.profilePath = nil;
    configInDevelopment.inProduction = NO;
    configInDevelopment.detectProvisioningMode = YES;
    configInDevelopment.isSimulator = YES;
    XCTAssertFalse(configInDevelopment.inProduction, @"Devices without embedded provisioning profiles AND provisioning detection enabled should return YES for inProduction as a safety measure.");
}

- (void)testProductionFlag {
    UAConfig *config = [[UAConfig alloc] init];

    // initialize with a custom profile path that is accessible from this test environment
    config.profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"production-embedded" ofType:@"mobileprovision"];

    // populate dev and prod keys, then toggle between them
    config.developmentAppKey = @"devAppKey";
    config.developmentAppSecret = @"devAppSecret";
    config.developmentLogLevel = UALogLevelTrace;//not the default
    
    config.productionAppKey = @"prodAppKey";
    config.productionAppSecret = @"prodAppSecret";
    config.productionLogLevel = UALogLevelNone;//not the default

    XCTAssertFalse(config.inProduction, @"inProduction defaults to NO.");
    XCTAssertFalse(config.detectProvisioningMode, @"detectProvisioningMode defaults to NO.");

    XCTAssertEqualObjects(config.appKey, config.developmentAppKey, @"Incorrect app key resolution.");
    XCTAssertEqualObjects(config.appSecret, config.developmentAppSecret, @"Incorrect app secret resolution.");
    XCTAssertEqual(config.logLevel, config.developmentLogLevel, @"Incorrect log level resolution.");

    config.inProduction = YES;
    XCTAssertEqualObjects(config.appKey, config.productionAppKey, @"Incorrect app key resolution.");
    XCTAssertEqualObjects(config.appSecret, config.productionAppSecret, @"Incorrect app secret resolution.");
    XCTAssertEqual(config.logLevel, config.productionLogLevel, @"Incorrect log level resolution.");

    config.inProduction = NO;
    config.detectProvisioningMode = YES;

    XCTAssertTrue(config.inProduction, @"The embedded provisioning profile is a production profile.");

    // ensure that our dispatch_once block works when wrapping the in production flag
    config.profilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"development-embedded" ofType:@"mobileprovision"];
    XCTAssertTrue(config.inProduction, @"The development profile path should not be used as the file will only be read once.");
}

- (void)testOldPlistFormat {
    NSString *legacyPlistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-Legacy-NeXTStep" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:legacyPlistPath];

    XCTAssertTrue([config validate], @"Legacy Config File is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 5, @"Development log level was improperly loaded.");
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");

}

- (void)testPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];


    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"AirshipConfig (modern) File is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");
    XCTAssertEqualObjects(config.customConfig, @{@"customKey": @"customValue"}, @"Custom config was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    XCTAssertEqual(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
}

- (void)testNeXTStepPlistParsing {
    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid-NeXTStep" ofType:@"plist"];

    NSString *validAppValue = @"0A00000000000000000000";
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    XCTAssertTrue([config validate], @"NeXTStep plist file is invalid.");

    XCTAssertEqualObjects(config.productionAppKey, validAppValue, @"Production app key was improperly loaded.");
    XCTAssertEqualObjects(config.productionAppSecret, validAppValue, @"Production app secret was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppKey, validAppValue, @"Development app key was improperly loaded.");
    XCTAssertEqualObjects(config.developmentAppSecret, validAppValue, @"Development app secret was improperly loaded.");

    XCTAssertEqual(config.developmentLogLevel, 1, @"Development log level was improperly loaded.");
    XCTAssertEqual(config.productionLogLevel, 5, @"Production log level was improperly loaded.");
    XCTAssertTrue(config.detectProvisioningMode, @"detectProvisioningMode was improperly loaded.");

    //special case this one since we have to disable detectProvisioningMode
    config.detectProvisioningMode = NO;
    XCTAssertTrue(config.inProduction, @"inProduction was improperly loaded.");
}

- (void)testValidation {

    NSString *plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirshipConfig-Valid" ofType:@"plist"];

    NSString *validAppValue = @"0A00000000000000000000";
    NSString *invalidValue = @" invalid!!! ";
    
    UAConfig *config = [UAConfig configWithContentsOfFile:plistPath];

    config.inProduction = NO;
    config.detectProvisioningMode = NO;

    // Make it invalid and then valid again, asserting the whole way.
    
    config.developmentAppKey = invalidValue;
    XCTAssertFalse([config validate], @"Development App Key is improperly verified.");
    config.developmentAppKey = validAppValue;

    config.developmentAppSecret = invalidValue;
    XCTAssertFalse([config validate], @"Development App Secret is improperly verified.");
    config.developmentAppSecret = validAppValue;

    //switch to production mode as validation only strictly checks the current keypair
    config.inProduction = YES;

    config.productionAppKey = invalidValue;
    XCTAssertFalse([config validate], @"Production App Key is improperly verified.");
    config.productionAppKey = validAppValue;

    config.productionAppSecret = invalidValue;
    XCTAssertFalse([config validate], @"Production App Secret is improperly verified.");
    config.productionAppSecret = validAppValue;

}

- (void) testSetAnalyticsURL {
    UAConfig *config =[[UAConfig alloc] init];

    config.analyticsURL = @"http://some-other-url.com";
    XCTAssertEqualObjects(@"http://some-other-url.com", config.analyticsURL, @"Analytics URL does not set correctly");
    
    config.analyticsURL = @"http://some-url.com/";
    XCTAssertEqualObjects(@"http://some-url.com", config.analyticsURL, @"Analytics URL still contains trailing slash");
}

- (void) testSetDeviceAPIURL {
    UAConfig *config =[[UAConfig alloc] init];

    config.deviceAPIURL = @"http://some-other-url.com";
    XCTAssertEqualObjects(@"http://some-other-url.com", config.deviceAPIURL, @"Device API URL does not set correctly");
    
    config.deviceAPIURL = @"http://some-url.com/";
    XCTAssertEqualObjects(@"http://some-url.com", config.deviceAPIURL, @"Device API URL still contains trailing slash");
}

@end
