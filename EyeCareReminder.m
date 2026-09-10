#import <Cocoa/Cocoa.h>

static NSString * const WorkMinutesKey = @"workMinutes";
static NSString * const EyeBreakSecondsKey = @"eyeBreakSeconds";
static NSString * const LongBreakEveryKey = @"longBreakEvery";
static NSString * const LongBreakMinutesKey = @"longBreakMinutes";

static NSInteger Preference(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

@interface BreakController : NSWindowController <NSWindowDelegate>
@property(nonatomic) NSInteger totalSeconds;
@property(nonatomic) NSInteger remainingSeconds;
@property(nonatomic, strong) NSTextField *countdownLabel;
@property(nonatomic, strong) NSProgressIndicator *progress;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL didFinish;
@property(nonatomic, copy) void (^onComplete)(void);
@property(nonatomic, copy) void (^onSnooze)(void);
- (instancetype)initWithLongBreak:(BOOL)isLong duration:(NSInteger)duration;
- (void)start;
@end

@implementation BreakController

- (instancetype)initWithLongBreak:(BOOL)isLong duration:(NSInteger)duration {
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 520, 340)
                                                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    self = [super initWithWindow:panel];
    if (self) {
        self.totalSeconds = MAX(duration, 1);
        self.remainingSeconds = MAX(duration, 1);
        panel.title = isLong ? @"该活动一下了" : @"让眼睛休息一下";
        panel.titleVisibility = NSWindowTitleHidden;
        panel.titlebarAppearsTransparent = YES;
        panel.movableByWindowBackground = YES;
        panel.level = NSFloatingWindowLevel;
        panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
        panel.releasedWhenClosed = NO;
        panel.delegate = self;
        [self buildContentForLongBreak:isLong];
    }
    return self;
}

- (void)buildContentForLongBreak:(BOOL)isLong {
    NSView *content = self.window.contentView;

    NSImageView *icon = [[NSImageView alloc] init];
    icon.image = [NSImage imageWithSystemSymbolName:(isLong ? @"figure.walk" : @"eye") accessibilityDescription:nil];
    icon.contentTintColor = NSColor.systemGreenColor;
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:42 weight:NSFontWeightMedium];

    NSTextField *title = [NSTextField labelWithString:(isLong ? @"离开屏幕，活动一下身体" : @"看看 6 米以外的地方")];
    title.font = [NSFont systemFontOfSize:25 weight:NSFontWeightSemibold];
    title.alignment = NSTextAlignmentCenter;

    NSTextField *hint = [NSTextField wrappingLabelWithString:(isLong
        ? @"站起来走动，转转肩膀和脖子，顺便喝点水。"
        : @"放松眼睛，不看手机。慢慢眨眼，让肩膀自然下沉。")];
    hint.font = [NSFont systemFontOfSize:15];
    hint.textColor = NSColor.secondaryLabelColor;
    hint.alignment = NSTextAlignmentCenter;

    self.countdownLabel = [NSTextField labelWithString:@""];
    self.countdownLabel.font = [NSFont monospacedDigitSystemFontOfSize:38 weight:NSFontWeightMedium];
    self.countdownLabel.alignment = NSTextAlignmentCenter;

    self.progress = [[NSProgressIndicator alloc] init];
    self.progress.indeterminate = NO;
    self.progress.minValue = 0;
    self.progress.maxValue = self.totalSeconds;
    self.progress.doubleValue = self.totalSeconds;
    self.progress.controlSize = NSControlSizeSmall;

    NSButton *finishButton = [NSButton buttonWithTitle:@"提前完成" target:self action:@selector(completeNow:)];
    finishButton.bezelStyle = NSBezelStyleRounded;
    finishButton.keyEquivalent = @"\r";

    NSButton *snoozeButton = [NSButton buttonWithTitle:@"稍后 5 分钟" target:self action:@selector(snooze:)];
    snoozeButton.bezelStyle = NSBezelStyleRounded;

    NSStackView *buttons = [NSStackView stackViewWithViews:@[snoozeButton, finishButton]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 12;
    buttons.distribution = NSStackViewDistributionFillEqually;

    NSStackView *stack = [NSStackView stackViewWithViews:@[icon, title, hint, self.countdownLabel, self.progress, buttons]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:42],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-42],
        [stack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor constant:8],
        [icon.widthAnchor constraintEqualToConstant:52],
        [icon.heightAnchor constraintEqualToConstant:52],
        [hint.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [self.countdownLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [self.progress.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [buttons.widthAnchor constraintEqualToConstant:290]
    ]];

    [self updateCountdown];
}

- (void)start {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window center];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    NSBeep();
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                 target:self
                                               selector:@selector(tick:)
                                               userInfo:nil
                                                repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)tick:(NSTimer *)timer {
    self.remainingSeconds -= 1;
    [self updateCountdown];
    if (self.remainingSeconds <= 0) {
        [self completeNow:nil];
    }
}

- (void)updateCountdown {
    self.countdownLabel.stringValue = [NSString stringWithFormat:@"%02ld:%02ld",
        (long)(self.remainingSeconds / 60), (long)(self.remainingSeconds % 60)];
    self.progress.doubleValue = self.remainingSeconds;
}

- (void)completeNow:(id)sender {
    if (self.didFinish) return;
    self.didFinish = YES;
    [self.timer invalidate];
    self.timer = nil;
    [self.window orderOut:nil];
    if (self.onComplete) self.onComplete();
}

- (void)snooze:(id)sender {
    if (self.didFinish) return;
    self.didFinish = YES;
    [self.timer invalidate];
    self.timer = nil;
    [self.window orderOut:nil];
    if (self.onSnooze) self.onSnooze();
}

- (void)windowWillClose:(NSNotification *)notification {
    [self completeNow:nil];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *statusMenu;
@property(nonatomic, strong) NSMenuItem *statusLine;
@property(nonatomic, strong) NSMenuItem *pauseItem;
@property(nonatomic, strong) NSTimer *ticker;
@property(nonatomic, strong) NSDate *nextReminderAt;
@property(nonatomic) BOOL paused;
@property(nonatomic) NSInteger completedWorkPeriods;
@property(nonatomic, strong) BreakController *breakController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        WorkMinutesKey: @20,
        EyeBreakSecondsKey: @20,
        LongBreakEveryKey: @4,
        LongBreakMinutesKey: @5
    }];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self configureStatusItem];
    [self scheduleRegularReminder];

    self.ticker = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(tick:)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.ticker forMode:NSRunLoopCommonModes];
}

- (void)configureStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"eye.fill" accessibilityDescription:@"护眼提醒"];
    self.statusItem.button.image.template = YES;
    self.statusItem.button.toolTip = @"护眼提醒";

    self.statusMenu = [[NSMenu alloc] init];
    self.statusMenu.delegate = self;

    self.statusLine = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.statusLine.enabled = NO;
    [self.statusMenu addItem:self.statusLine];
    [self.statusMenu addItem:NSMenuItem.separatorItem];

    self.pauseItem = [[NSMenuItem alloc] initWithTitle:@"暂停提醒" action:@selector(togglePause:) keyEquivalent:@"p"];
    self.pauseItem.target = self;
    [self.statusMenu addItem:self.pauseItem];

    NSMenuItem *restNow = [[NSMenuItem alloc] initWithTitle:@"现在休息" action:@selector(restNow:) keyEquivalent:@"r"];
    restNow.target = self;
    [self.statusMenu addItem:restNow];

    NSMenuItem *delay = [[NSMenuItem alloc] initWithTitle:@"推迟 5 分钟" action:@selector(delayFiveMinutes:) keyEquivalent:@"d"];
    delay.target = self;
    [self.statusMenu addItem:delay];
    [self.statusMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"设置…" action:@selector(showSettings:) keyEquivalent:@","];
    settings.target = self;
    [self.statusMenu addItem:settings];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"退出护眼提醒" action:@selector(quitApp:) keyEquivalent:@"q"];
    quit.target = self;
    [self.statusMenu addItem:quit];

    self.statusItem.menu = self.statusMenu;
    [self updateMenu];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self updateMenu];
}

- (void)tick:(NSTimer *)timer {
    if (!self.paused && !self.breakController && self.nextReminderAt && [self.nextReminderAt timeIntervalSinceNow] <= 0) {
        [self startBreakForcedShort:NO];
    }
}

- (void)startBreakForcedShort:(BOOL)forceShort {
    if (self.breakController) return;

    self.completedWorkPeriods += 1;
    BOOL isLong = !forceShort && self.completedWorkPeriods % Preference(LongBreakEveryKey) == 0;
    NSInteger duration = isLong ? Preference(LongBreakMinutesKey) * 60 : Preference(EyeBreakSecondsKey);
    BreakController *controller = [[BreakController alloc] initWithLongBreak:isLong duration:duration];
    __weak typeof(self) weakSelf = self;
    __weak BreakController *weakController = controller;

    controller.onComplete = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.breakController == weakController) self.breakController = nil;
        [self scheduleRegularReminder];
    };
    controller.onSnooze = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.breakController == weakController) self.breakController = nil;
        self.nextReminderAt = [NSDate dateWithTimeIntervalSinceNow:5 * 60];
        [self updateMenu];
    };

    self.breakController = controller;
    self.nextReminderAt = nil;
    [controller start];
    [self updateMenu];
}

- (void)scheduleRegularReminder {
    self.nextReminderAt = [NSDate dateWithTimeIntervalSinceNow:Preference(WorkMinutesKey) * 60];
    self.paused = NO;
    [self updateMenu];
}

- (void)updateMenu {
    if (self.breakController) {
        self.statusLine.title = @"正在休息";
    } else if (self.paused) {
        self.statusLine.title = @"提醒已暂停";
    } else if (self.nextReminderAt) {
        NSInteger remaining = MAX(0, (NSInteger)ceil(self.nextReminderAt.timeIntervalSinceNow));
        self.statusLine.title = [NSString stringWithFormat:@"下次提醒：%02ld:%02ld",
            (long)(remaining / 60), (long)(remaining % 60)];
    } else {
        self.statusLine.title = @"准备提醒";
    }
    self.pauseItem.title = self.paused ? @"继续提醒" : @"暂停提醒";
}

- (void)togglePause:(id)sender {
    self.paused = !self.paused;
    if (self.paused) {
        self.nextReminderAt = nil;
        [self updateMenu];
    } else {
        [self scheduleRegularReminder];
    }
}

- (void)restNow:(id)sender {
    [self startBreakForcedShort:YES];
}

- (void)delayFiveMinutes:(id)sender {
    self.paused = NO;
    self.nextReminderAt = [NSDate dateWithTimeIntervalSinceNow:5 * 60];
    [self updateMenu];
}

- (NSTextField *)numberFieldWithValue:(NSInteger)value frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.integerValue = value;
    field.alignment = NSTextAlignmentRight;
    return field;
}

- (void)addLabel:(NSString *)text toView:(NSView *)view y:(CGFloat)y {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = NSMakeRect(0, y, 190, 24);
    label.alignment = NSTextAlignmentRight;
    [view addSubview:label];
}

- (void)showSettings:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"设置你的工作与休息节奏";
    alert.informativeText = @"默认采用 20-20-20 规则：每工作 20 分钟，看 6 米外至少 20 秒。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"取消"];

    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 330, 160)];
    [self addLabel:@"工作间隔（分钟）" toView:form y:126];
    [self addLabel:@"护眼休息（秒）" toView:form y:88];
    [self addLabel:@"每几次进入长休息" toView:form y:50];
    [self addLabel:@"长休息（分钟）" toView:form y:12];

    NSTextField *workField = [self numberFieldWithValue:Preference(WorkMinutesKey) frame:NSMakeRect(210, 124, 90, 24)];
    NSTextField *eyeField = [self numberFieldWithValue:Preference(EyeBreakSecondsKey) frame:NSMakeRect(210, 86, 90, 24)];
    NSTextField *everyField = [self numberFieldWithValue:Preference(LongBreakEveryKey) frame:NSMakeRect(210, 48, 90, 24)];
    NSTextField *longField = [self numberFieldWithValue:Preference(LongBreakMinutesKey) frame:NSMakeRect(210, 10, 90, 24)];
    [form addSubview:workField];
    [form addSubview:eyeField];
    [form addSubview:everyField];
    [form addSubview:longField];
    alert.accessoryView = form;

    [NSApp activateIgnoringOtherApps:YES];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    NSInteger work = workField.integerValue;
    NSInteger eye = eyeField.integerValue;
    NSInteger every = everyField.integerValue;
    NSInteger longBreak = longField.integerValue;
    BOOL valid = work >= 1 && work <= 180 && eye >= 5 && eye <= 300 &&
                 every >= 1 && every <= 12 && longBreak >= 1 && longBreak <= 30;
    if (!valid) {
        NSAlert *warning = [[NSAlert alloc] init];
        warning.messageText = @"请检查设置";
        warning.informativeText = @"工作间隔 1–180 分钟，护眼休息 5–300 秒，长休息频率 1–12 次，长休息 1–30 分钟。";
        warning.alertStyle = NSAlertStyleWarning;
        [warning runModal];
        return;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setInteger:work forKey:WorkMinutesKey];
    [defaults setInteger:eye forKey:EyeBreakSecondsKey];
    [defaults setInteger:every forKey:LongBreakEveryKey];
    [defaults setInteger:longBreak forKey:LongBreakMinutesKey];
    if (!self.paused) [self scheduleRegularReminder];
}

- (void)quitApp:(id)sender {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
