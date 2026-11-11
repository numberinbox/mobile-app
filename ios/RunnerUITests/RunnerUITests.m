@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

// The Patrol CLI defines these on its xcodebuild command line; the fallbacks
// keep standalone builds working with the safe defaults.
#ifndef FULL_ISOLATION
#define FULL_ISOLATION 0
#endif
#ifndef CLEAR_PERMISSIONS
#define CLEAR_PERMISSIONS 0
#endif

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
