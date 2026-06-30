#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW);
        if (!handle) {
            fprintf(stderr, "Error loading CoreBrightness framework\n");
            return 1;
        }

        Class clientClass = NSClassFromString(@"KeyboardBrightnessClient");
        if (!clientClass) {
            fprintf(stderr, "Error: KeyboardBrightnessClient class not found\n");
            return 1;
        }

        id client = [[clientClass alloc] init];
        if (!client) {
            fprintf(stderr, "Error: failed to instantiate KeyboardBrightnessClient\n");
            return 1;
        }

        if (argc < 2) {
            printf("Usage:\n  %s get\n  %s set <value>\n", argv[0], argv[0]);
            return 1;
        }

        NSString *command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"get"]) {
            SEL copyIDsSelector = NSSelectorFromString(@"copyKeyboardBacklightIDs");
            NSArray *ids = nil;
            if ([client respondsToSelector:copyIDsSelector]) {
                typedef NSArray* (*CopyIDsFunc)(id, SEL);
                CopyIDsFunc copyIDs = (CopyIDsFunc)[client methodForSelector:copyIDsSelector];
                ids = copyIDs(client, copyIDsSelector);
            }

            if (!ids || ids.count == 0) {
                ids = @[@1]; // fallback default keyboard ID
            }

            SEL getBrightnessSelector = NSSelectorFromString(@"brightnessForKeyboard:");
            if (![client respondsToSelector:getBrightnessSelector]) {
                fprintf(stderr, "Error: client does not respond to brightnessForKeyboard:\n");
                return 1;
            }

            typedef float (*GetBrightnessFunc)(id, SEL, unsigned long long);
            GetBrightnessFunc getBrightness = (GetBrightnessFunc)[client methodForSelector:getBrightnessSelector];
            
            for (NSNumber *kbId in ids) {
                float val = getBrightness(client, getBrightnessSelector, [kbId unsignedLongLongValue]);
                printf("%f\n", val);
                return 0;
            }
        } else if ([command isEqualToString:@"set"] && argc == 3) {
            float val = atof(argv[2]);
            if (val < 0.0) val = 0.0;
            if (val > 1.0) val = 1.0;

            SEL copyIDsSelector = NSSelectorFromString(@"copyKeyboardBacklightIDs");
            NSArray *ids = nil;
            if ([client respondsToSelector:copyIDsSelector]) {
                typedef NSArray* (*CopyIDsFunc)(id, SEL);
                CopyIDsFunc copyIDs = (CopyIDsFunc)[client methodForSelector:copyIDsSelector];
                ids = copyIDs(client, copyIDsSelector);
            }
            if (!ids || ids.count == 0) {
                ids = @[@1];
            }

            SEL setBrightnessSelector = NSSelectorFromString(@"setBrightness:forKeyboard:");
            if (![client respondsToSelector:setBrightnessSelector]) {
                fprintf(stderr, "Error: client does not respond to setBrightness:forKeyboard:\n");
                return 1;
            }

            typedef BOOL (*SetBrightnessFunc)(id, SEL, float, unsigned long long);
            SetBrightnessFunc setBrightness = (SetBrightnessFunc)[client methodForSelector:setBrightnessSelector];

            for (NSNumber *kbId in ids) {
                BOOL success = setBrightness(client, setBrightnessSelector, val, [kbId unsignedLongLongValue]);
                if (!success) {
                    fprintf(stderr, "Warning: failed to set brightness for keyboard ID %llu\n", [kbId unsignedLongLongValue]);
                }
            }
            return 0;
        } else {
            fprintf(stderr, "Invalid command or arguments\n");
            return 1;
        }
    }
    return 0;
}
