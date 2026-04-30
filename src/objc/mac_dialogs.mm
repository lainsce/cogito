// Native macOS open/save file dialogs for vinemu.
// Exposes a tiny C ABI so vinemu.c can call NSOpenPanel/NSSavePanel.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <string.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

static void copy_path(NSString *path, char *out, size_t outsz) {
    if (!out || outsz == 0) return;
    out[0] = '\0';
    if (!path) return;
    const char *u = [path UTF8String];
    if (!u) return;
    strncpy(out, u, outsz - 1);
    out[outsz - 1] = '\0';
}

static void apply_default(NSSavePanel *panel, const char *default_path) {
    if (!default_path || !default_path[0]) return;
    NSString *raw = [NSString stringWithUTF8String:default_path];
    if (!raw) return;
    NSString *expanded = [raw stringByExpandingTildeInPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL is_dir = NO;
    BOOL exists = [fm fileExistsAtPath:expanded isDirectory:&is_dir];
    if (exists && is_dir) {
        panel.directoryURL = [NSURL fileURLWithPath:expanded isDirectory:YES];
        return;
    }
    NSString *dir = [expanded stringByDeletingLastPathComponent];
    NSString *name = [expanded lastPathComponent];
    if (dir.length > 0 && [fm fileExistsAtPath:dir]) {
        panel.directoryURL = [NSURL fileURLWithPath:dir isDirectory:YES];
    }
    if (name.length > 0) {
        panel.nameFieldStringValue = name;
    }
}

static bool run_panel_modal(NSSavePanel *panel, char *out, size_t outsz) {
    // NSApp must exist and be configured as a regular app for the modal panel
    // to receive focus. SDL3 already initializes NSApplication, but ensure it.
    [NSApplication sharedApplication];
    if ([NSApp activationPolicy] == NSApplicationActivationPolicyProhibited) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse resp = [panel runModal];
    if (resp != NSModalResponseOK) return false;
    NSURL *url = panel.URL;
    if (!url) return false;
    copy_path([url path], out, outsz);
    return out[0] != '\0';
}

bool vimana_mac_open_file_dialog(const char *title,
                                 const char *default_path,
                                 char *out, size_t outsz) {
    if (out && outsz > 0) out[0] = '\0';
    __block bool ok = false;
    void (^work)(void) = ^{
        @autoreleasepool {
            NSOpenPanel *panel = [NSOpenPanel openPanel];
            panel.canChooseFiles = YES;
            panel.canChooseDirectories = NO;
            panel.allowsMultipleSelection = NO;
            panel.resolvesAliases = YES;
            if (title && title[0]) {
                NSString *t = [NSString stringWithUTF8String:title];
                if (t) panel.message = t;
            }
            apply_default(panel, default_path);
            ok = run_panel_modal(panel, out, outsz);
        }
    };
    if ([NSThread isMainThread]) work();
    else dispatch_sync(dispatch_get_main_queue(), work);
    return ok;
}

bool vimana_mac_save_file_dialog(const char *title,
                                 const char *default_path,
                                 char *out, size_t outsz) {
    if (out && outsz > 0) out[0] = '\0';
    __block bool ok = false;
    void (^work)(void) = ^{
        @autoreleasepool {
            NSSavePanel *panel = [NSSavePanel savePanel];
            panel.canCreateDirectories = YES;
            if (title && title[0]) {
                NSString *t = [NSString stringWithUTF8String:title];
                if (t) panel.message = t;
            }
            apply_default(panel, default_path);
            ok = run_panel_modal(panel, out, outsz);
        }
    };
    if ([NSThread isMainThread]) work();
    else dispatch_sync(dispatch_get_main_queue(), work);
    return ok;
}

#ifdef __cplusplus
}
#endif
