/*
 Copyright (c) 2016, Jeffrey Pfau

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS''
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

#import "mGBAGameCoreBridge.h"

@import libmGBA;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVEmulatorCore;
@import PVAudio;


#include <mgba-util/common.h>

#include <mgba/core/blip_buf.h>
#include <mgba/core/core.h>
#include <mgba/core/cheats.h>
#include <mgba/core/serialize.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gba/cheats.h>
#include <mgba/internal/gba/input.h>
#include <mgba-util/circle-buffer.h>
#include <mgba-util/memory.h>
#include <mgba-util/vfs.h>

#define SAMPLES 1024

const int GBAMap[] = {
    GBA_KEY_UP,
    GBA_KEY_DOWN,
    GBA_KEY_LEFT,
    GBA_KEY_RIGHT,
    GBA_KEY_A,
    GBA_KEY_B,
    GBA_KEY_L,
    GBA_KEY_R,
    GBA_KEY_START,
    GBA_KEY_SELECT
};

const char* const binaryName = "mGBA";

@interface PVmGBAGameCoreBridge () <PVGBASystemResponderClient> {
	struct mCore* core;
	void* outputBuffer;
	NSMutableDictionary *cheatSets;
}
@end

static void _log(struct mLogger* log,
                 int category,
                 enum mLogLevel level,
                 const char* format,
                 va_list args)
{}

static struct mLogger logger = { .log = _log };

@implementation PVmGBAGameCoreBridge

- (instancetype)init {
	if ((self = [super init])) {
	
	}

	return self;
}

- (void)dealloc {
    mCoreConfigDeinit(&core->config);
	core->deinit(core);
	free(outputBuffer);
}

#pragma mark - Execution


-(void)initialize {
    [super initialize];
    core = GBACoreCreate();
    mCoreInitConfig(core, nil);

    struct mCoreOptions opts = {
        .useBios = true,
    };
    
    // Set up a logger. The default logger prints everything to STDOUT, which is not usually desirable.
    mLogSetDefaultLogger(&logger);

    mCoreConfigLoadDefaults(&core->config, &opts);
    core->init(core);
    outputBuffer = nil;

    unsigned width, height;
    core->desiredVideoDimensions(core, &width, &height);
    outputBuffer = malloc(width * height * BYTES_PER_PIXEL);
    core->setVideoBuffer(core, outputBuffer, width);
    core->setAudioBufferSize(core, SAMPLES);

    cheatSets = [[NSMutableDictionary alloc] init];
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *batterySavesDirectory = [self batterySavesPath];
	[[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:batterySavesDirectory]
	                                withIntermediateDirectories:YES
	                                attributes:nil
	                                error:nil];
	if (core->dirs.save) {
		core->dirs.save->close(core->dirs.save);
	}
	core->dirs.save = VDirOpen([batterySavesDirectory fileSystemRepresentation]);

	if (!mCoreLoadFile(core, [path fileSystemRepresentation])) {
		if (error) {
            *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                         code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                     userInfo:nil];
		}
		return NO;
	}
	mCoreAutoloadSave(core);

	core->reset(core);
	return YES;
}

- (void)executeFrame {
	core->runFrame(core);

	int16_t samples[SAMPLES * 2];
	int available = 0;
	available = blip_samples_avail(core->getAudioChannel(core, 0));
	blip_read_samples(core->getAudioChannel(core, 0), samples, available, true);
	blip_read_samples(core->getAudioChannel(core, 1), samples + 1, available, true);
	[[self ringBufferAtIndex:0] write:samples size:available * 4];
}

- (void)resetEmulation {
	core->reset(core);
}

- (void)setupEmulation {
	blip_set_rates(core->getAudioChannel(core, 0), core->frequency(core), 32768);
	blip_set_rates(core->getAudioChannel(core, 1), core->frequency(core), 32768);
}

#pragma mark - Video

- (CGSize)aspectSize {
	return CGSizeMake(3, 2);
}

- (CGRect)screenRect {
	unsigned width, height;
	core->desiredVideoDimensions(core, &width, &height);
    return CGRectMake(0, 0, width, height);
}

- (CGSize)bufferSize {
	unsigned width, height;
	core->desiredVideoDimensions(core, &width, &height);
    return CGSizeMake(width, height);
}

- (const void *)getVideoBufferWithHint:(void *)hint {
	CGSize bufferSize = [self bufferSize];

	if (!hint) {
		hint = outputBuffer;
	}

	outputBuffer = hint;
	core->setVideoBuffer(core, hint, bufferSize.width);

	return hint;
}

- (GLenum)pixelFormat {
    return GL_RGBA;
}

- (GLenum)pixelType {
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    return GL_UNSIGNED_INT_8_8_8_8_REV;
#else
    return GL_UNSIGNED_INT;
#endif
}

- (NSTimeInterval)frameInterval {
	return core->frequency(core) / (double) core->frameCycles(core);
}

#pragma mark - Audio

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return 32768;
}

#pragma mark - Save State

- (NSData *)serializeStateWithError:(NSError **)outError
{
	struct VFile* vf = VFileMemChunk(nil, 0);
	if (!mCoreSaveStateNamed(core, vf, SAVESTATE_SAVEDATA)) {
		if (outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:nil];
		}
		vf->close(vf);
		return nil;
	}
	size_t size = vf->size(vf);
	void* data = vf->map(vf, size, MAP_READ);
	NSData *nsdata = [NSData dataWithBytes:data length:size];
	vf->unmap(vf, data, size);
	vf->close(vf);
	return nsdata;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
	struct VFile* vf = VFileFromConstMemory(state.bytes, state.length);
	if (!mCoreLoadStateNamed(core, vf, SAVESTATE_SAVEDATA)) {
		if (outError) {
			*outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:nil];
		}
		vf->close(vf);
		return NO;
	}
	vf->close(vf);
	return YES;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	struct VFile* vf = VFileOpen([fileName fileSystemRepresentation], O_CREAT | O_TRUNC | O_RDWR);
    BOOL success = mCoreSaveStateNamed(core, vf, 0);
    if(!success) {
        NSError *error = nil;
            error = [NSError errorWithDomain:@"org.provenance.GameCore.ErrorDomain"
                                        code:-5
                                    userInfo:@{
                NSLocalizedDescriptionKey : @"Jagar Could not load the current state.",
                NSFilePathErrorKey : fileName
            }];
        block(error);
    } else {
        block(nil);
    }
	vf->close(vf);
    return success;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	struct VFile* vf = VFileOpen([fileName fileSystemRepresentation], O_RDONLY);
    BOOL success = mCoreLoadStateNamed(core, vf, 0);
    if(!success) {
        NSError *error = nil;
            error = [NSError errorWithDomain:@"org.provenance.GameCore.ErrorDomain"
                                        code:-5
                                    userInfo:@{
                NSLocalizedDescriptionKey : @"Jagar Could not load the current state.",
                NSFilePathErrorKey : fileName
            }];
        block(error);
    } else {
        block(nil);
    }
	vf->close(vf);
    return success;
}

#pragma mark - Input

- (oneway void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player {
	UNUSED(player);
	core->addKeys(core, 1 << GBAMap[button]);
}

- (oneway void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player {
	UNUSED(player);
	core->clearKeys(core, 1 << GBAMap[button]);
}

#pragma mark - Cheats

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
	code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

	NSString *codeId = [code stringByAppendingFormat:@"/%@", type];
	struct mCheatSet* cheatSet = [[cheatSets objectForKey:codeId] pointerValue];
	if (cheatSet) {
		cheatSet->enabled = enabled;
		return;
	}
	struct mCheatDevice* cheats = core->cheatDevice(core);
	cheatSet = cheats->createSet(cheats, [codeId UTF8String]);
	size_t size = mCheatSetsSize(&cheats->cheats);
	if (size) {
		cheatSet->copyProperties(cheatSet, *mCheatSetsGetPointer(&cheats->cheats, size - 1));
	}
	int codeType = GBA_CHEAT_AUTODETECT;
	// NOTE: This is deprecated and was only meant to test cheats with the UI using cheats-database.xml
	// Will be replaced with a sqlite database in the future.
//    if ([type isEqual:@"GameShark"]) {
//        codeType = GBA_CHEAT_GAMESHARK;
//    } else if ([type isEqual:@"Action Replay"]) {
//        codeType = GBA_CHEAT_PRO_ACTION_REPLAY;
//    }
	NSArray *codeSet = [code componentsSeparatedByString:@"+"];
	for (id c in codeSet) {
//        if ([c length] == 12)
//            codeType = GBA_CHEAT_CODEBREAKER;
//        if ([c length] == 16) // default to GS/AR v1/v2 code (can't determine GS/AR v1/v2 vs AR v3 because same length)
//            codeType = GBA_CHEAT_GAMESHARK;
		mCheatAddLine(cheatSet, [c UTF8String], codeType);
	}
	cheatSet->enabled = enabled;
	[cheatSets setObject:[NSValue valueWithPointer:cheatSet] forKey:codeId];
	mCheatAddSet(cheats, cheatSet);
}
@end
