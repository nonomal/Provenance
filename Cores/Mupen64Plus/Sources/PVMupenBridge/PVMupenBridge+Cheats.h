//
//  MupenGameCore+Controls.h
//  MupenGameCore
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVMupenBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVMupenBridge (Cheats)
- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END