import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'icon_set.dart';

/// The base icons of every ShipGlows app, one name per meaning, drawn from
/// Lucide (ISC license). Use the constants where the icon is fixed; shared
/// packages go through [of] so an app can swap any of them with a
/// [ShipglowsIconSet] in its theme.
abstract final class ShipglowsIcons {
  /// Open in a window or the browser.
  static const IconData open = LucideIcons.externalLink;

  /// Settings.
  static const IconData settings = LucideIcons.settings;

  /// About, details.
  static const IconData info = LucideIcons.info;

  /// Update, refresh, sync now.
  static const IconData update = LucideIcons.refreshCw;

  /// Quit the app.
  static const IconData quit = LucideIcons.power;

  /// Send feedback.
  static const IconData feedback = LucideIcons.messageSquareText;

  /// User manual, documentation.
  static const IconData manual = LucideIcons.bookOpen;

  /// What's new.
  static const IconData whatsNew = LucideIcons.sparkles;

  /// Troubleshooting, diagnostics.
  static const IconData troubleshoot = LucideIcons.wrench;

  /// Help.
  static const IconData help = LucideIcons.circleHelp;

  /// Community.
  static const IconData community = LucideIcons.users;

  /// Screenshot.
  static const IconData screenshot = LucideIcons.scanLine;

  /// Video, screen recording.
  static const IconData video = LucideIcons.video;

  /// Audio, microphone.
  static const IconData audio = LucideIcons.mic;

  /// Search.
  static const IconData search = LucideIcons.search;

  /// Command bar.
  static const IconData commandBar = LucideIcons.command;

  /// Keyboard, shortcuts.
  static const IconData keyboard = LucideIcons.keyboard;

  /// Add, create.
  static const IconData add = LucideIcons.plus;

  /// Remove one, decrease.
  static const IconData remove = LucideIcons.minus;

  /// Edit, rename.
  static const IconData edit = LucideIcons.pencil;

  /// Note.
  static const IconData note = LucideIcons.stickyNote;

  /// Date, calendar.
  static const IconData calendar = LucideIcons.calendar;

  /// Folder.
  static const IconData folder = LucideIcons.folder;

  /// Open folder, browse.
  static const IconData folderOpen = LucideIcons.folderOpen;

  /// Document, article.
  static const IconData document = LucideIcons.fileText;

  /// Copy.
  static const IconData copy = LucideIcons.copy;

  /// Favorite.
  static const IconData star = LucideIcons.star;

  /// Pin, keep on top.
  static const IconData pin = LucideIcons.pin;

  /// Close, dismiss.
  static const IconData close = LucideIcons.x;

  /// Done, selected.
  static const IconData check = LucideIcons.check;

  /// Delete, move to trash.
  static const IconData delete = LucideIcons.trash2;

  /// Undo.
  static const IconData undo = LucideIcons.undo2;

  /// Restore, reset.
  static const IconData restore = LucideIcons.rotateCcw;

  /// History.
  static const IconData history = LucideIcons.history;

  /// Main menu.
  static const IconData menu = LucideIcons.menu;

  /// More actions.
  static const IconData more = LucideIcons.ellipsis;

  /// Drag handle.
  static const IconData drag = LucideIcons.gripVertical;

  /// Back.
  static const IconData back = LucideIcons.arrowLeft;

  /// Forward, next step.
  static const IconData forward = LucideIcons.arrowRight;

  /// Previous, collapse to the left.
  static const IconData chevronLeft = LucideIcons.chevronLeft;

  /// Next, open a sub-level.
  static const IconData chevronRight = LucideIcons.chevronRight;

  /// Collapse.
  static const IconData chevronUp = LucideIcons.chevronUp;

  /// Expand, drop-down.
  static const IconData chevronDown = LucideIcons.chevronDown;

  /// Success state.
  static const IconData success = LucideIcons.circleCheck;

  /// Warning state.
  static const IconData warning = LucideIcons.triangleAlert;

  /// Error state.
  static const IconData error = LucideIcons.circleAlert;

  /// Waiting, in progress.
  static const IconData loading = LucideIcons.loaderCircle;

  /// Cloud, synced storage.
  static const IconData cloud = LucideIcons.cloud;

  /// Synced.
  static const IconData synced = LucideIcons.cloudCheck;

  /// Sending to the cloud.
  static const IconData syncUpload = LucideIcons.cloudUpload;

  /// Offline, not synced.
  static const IconData offline = LucideIcons.cloudOff;

  /// Download, export.
  static const IconData download = LucideIcons.download;

  /// Upload, import.
  static const IconData upload = LucideIcons.upload;

  /// Share.
  static const IconData share = LucideIcons.share2;

  /// Link.
  static const IconData link = LucideIcons.link;

  /// Filter.
  static const IconData filter = LucideIcons.funnel;

  /// Show, visible.
  static const IconData show = LucideIcons.eye;

  /// Hide, hidden.
  static const IconData hide = LucideIcons.eyeOff;

  /// Locked, private.
  static const IconData lock = LucideIcons.lock;

  /// Notifications.
  static const IconData notifications = LucideIcons.bell;

  /// Light theme.
  static const IconData lightMode = LucideIcons.sun;

  /// Dark theme.
  static const IconData darkMode = LucideIcons.moon;

  /// Theme follows the system.
  static const IconData systemMode = LucideIcons.sunMoon;

  /// Home.
  static const IconData home = LucideIcons.house;

  /// Account, profile.
  static const IconData account = LucideIcons.user;

  /// Sign out.
  static const IconData signOut = LucideIcons.logOut;

  /// Phone, mobile device.
  static const IconData phone = LucideIcons.smartphone;

  /// Computer, desktop.
  static const IconData desktop = LucideIcons.monitor;

  /// Learn, tutorial.
  static const IconData learn = LucideIcons.graduationCap;

  /// Click or tap here.
  static const IconData tap = LucideIcons.pointer;

  /// Tip, idea.
  static const IconData idea = LucideIcons.lightbulb;

  /// Quick action, automation.
  static const IconData quick = LucideIcons.zap;

  /// Bug report.
  static const IconData bug = LucideIcons.bug;

  /// Maximize, full screen.
  static const IconData maximize = LucideIcons.maximize2;

  /// Restore size, exit full screen.
  static const IconData minimize = LucideIcons.minimize2;

  /// Go to a place inside the app.
  static const IconData jump = LucideIcons.arrowUpRight;

  /// Clear a list: logs, emptied trash.
  static const IconData clear = LucideIcons.brushCleaning;

  /// Delete for good, no way back.
  static const IconData deleteForever = LucideIcons.circleX;

  /// Waiting its turn.
  static const IconData pending = LucideIcons.hourglass;

  /// Guided tour.
  static const IconData guide = LucideIcons.signpost;

  /// Current step.
  static const IconData stepCurrent = LucideIcons.circleDot;

  /// Step still to come.
  static const IconData stepPending = LucideIcons.circle;

  /// Syncing.
  static const IconData syncing = LucideIcons.cloudSync;

  /// Two versions to compare.
  static const IconData conflict = LucideIcons.gitCompareArrows;

  /// Send to the tray, keep running.
  static const IconData toTray = LucideIcons.arrowDownRight;

  /// A value that went up, down, or did not move.
  static const IconData trendUp = LucideIcons.trendingUp;
  static const IconData trendDown = LucideIcons.trendingDown;
  static const IconData trendFlat = LucideIcons.moveRight;

  /// Every base icon by name, the names shared with the menu model and the
  /// Astro sites.
  static const Map<String, IconData> byName = {
    'open': open,
    'settings': settings,
    'info': info,
    'update': update,
    'quit': quit,
    'feedback': feedback,
    'manual': manual,
    'whatsNew': whatsNew,
    'troubleshoot': troubleshoot,
    'help': help,
    'community': community,
    'screenshot': screenshot,
    'video': video,
    'audio': audio,
    'search': search,
    'commandBar': commandBar,
    'keyboard': keyboard,
    'add': add,
    'remove': remove,
    'edit': edit,
    'note': note,
    'calendar': calendar,
    'folder': folder,
    'folderOpen': folderOpen,
    'document': document,
    'copy': copy,
    'star': star,
    'pin': pin,
    'close': close,
    'check': check,
    'delete': delete,
    'undo': undo,
    'restore': restore,
    'history': history,
    'menu': menu,
    'more': more,
    'drag': drag,
    'back': back,
    'forward': forward,
    'chevronLeft': chevronLeft,
    'chevronRight': chevronRight,
    'chevronUp': chevronUp,
    'chevronDown': chevronDown,
    'success': success,
    'warning': warning,
    'error': error,
    'loading': loading,
    'cloud': cloud,
    'synced': synced,
    'syncUpload': syncUpload,
    'offline': offline,
    'download': download,
    'upload': upload,
    'share': share,
    'link': link,
    'filter': filter,
    'show': show,
    'hide': hide,
    'lock': lock,
    'notifications': notifications,
    'lightMode': lightMode,
    'darkMode': darkMode,
    'systemMode': systemMode,
    'home': home,
    'account': account,
    'signOut': signOut,
    'phone': phone,
    'desktop': desktop,
    'learn': learn,
    'tap': tap,
    'idea': idea,
    'quick': quick,
    'bug': bug,
    'maximize': maximize,
    'minimize': minimize,
    'jump': jump,
    'clear': clear,
    'deleteForever': deleteForever,
    'pending': pending,
    'guide': guide,
    'stepCurrent': stepCurrent,
    'stepPending': stepPending,
    'syncing': syncing,
    'conflict': conflict,
    'toTray': toTray,
    'trendUp': trendUp,
    'trendDown': trendDown,
    'trendFlat': trendFlat,
  };

  /// The icon named [name] for [context]: the app's [ShipglowsIconSet]
  /// override, else the base icon, else null for an unknown name.
  static IconData? of(BuildContext context, String name) =>
      ShipglowsIconSet.maybeOf(context)?.overrides[name] ?? byName[name];
}
