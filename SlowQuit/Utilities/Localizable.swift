//
//  Localizable.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Foundation

/// 本地化字符串辅助类
enum L10n {
    /// 获取本地化字符串
    static func string(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }

    // MARK: - Menu Bar
    static let menuEnable = string("menu.enable")
    static let menuSettings = string("menu.settings")
    static let menuLaunchAtLogin = string("menu.launch_at_login")
    static let menuAbout = string("menu.about")
    static let menuQuit = string("menu.quit")
    static let menuCheckUpdate = string("menu.check_update")
    static let menuOpenLogs = string("menu.open_logs")
    static let menuCheckPermissions = string("menu.check_permissions")

    // MARK: - About Dialog
    static var aboutVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let versionLabel = string("about.version_label")
        return "\(versionLabel) \(version) (\(build))"
    }
    static let aboutDescription = string("about.description")

    // MARK: - Permission Dialog
    static let permissionTitle = string("permission.title")
    static let permissionMessage = string("permission.message")
    static let permissionOpenSettings = string("permission.open_settings")
    static let permissionGrant = string("permission.grant")
    static let permissionLater = string("permission.later")
    static let permissionDescription = string("permission.description")
    static let permissionReadyTitle = string("permission.ready_title")
    static let permissionReadyMessage = string("permission.ready_message")
    static let permissionStillRequiredTitle = string("permission.still_required_title")
    static let permissionStillRequiredMessage = string("permission.still_required_message")
    static let permissionGuideTitle = string("permission.guide_title")
    static let permissionGuideSubtitle = string("permission.guide_subtitle")
    static let permissionGuideFootnote = string("permission.guide_footnote")
    static let permissionAccessibilityTitle = string("permission.accessibility_title")
    static let permissionAccessibilityDescription = string("permission.accessibility_description")
    static let permissionOpenAccessibility = string("permission.open_accessibility")
    static let permissionRecheck = string("permission.recheck")
    static let permissionGranted = string("permission.granted")
    static let permissionNotGranted = string("permission.not_granted")

    // MARK: - Overlay
    static let overlayHoldToQuit = string("overlay.hold_to_quit")
    static let overlayHoldToClose = string("overlay.hold_to_close")

    // MARK: - Alerts
    static let alertError = string("alert.error")
    static let alertOk = string("alert.ok")
    static let alertConfirm = string("alert.confirm")

    // MARK: - Secure Input Alert
    static let secureInputAlertTitle = string("secure_input.alert_title")
    static let secureInputAlertMessage = string("secure_input.alert_message")

    // MARK: - Common
    static let commonBack = string("common.back")

    // MARK: - Error Messages
    static let errorLaunchAtLogin = string("error.launch_at_login")
    static let errorLaunchAtLoginEnable = string("error.launch_at_login_enable")
    static let errorLaunchAtLoginDisable = string("error.launch_at_login_disable")
    static let errorLaunchAtLoginManualSetup = string("error.launch_at_login_manual_setup")

    // MARK: - Log Messages
    static let logEnabled = string("log.enabled")
    static let logDisabled = string("log.disabled")

    // MARK: - Settings
    static let settingsTitle = string("settings.title")
    static let settingsDelayLabel = string("settings.delay_label")
    static let settingsDelayDescription = string("settings.delay_description")
    static let settingsDelayUnit = string("settings.delay_unit")
    static let settingsHelpText = string("settings.help_text")
    static let settingsSlowCloseTitle = string("settings.slowclose_title")
    static let settingsSlowCloseDescription = string("settings.slowclose_description")

    // MARK: - App List
    static let appListModeLabel = string("app_list.mode_label")
    static let appListModeGlobal = string("app_list.mode_global")
    static let appListModeWhitelist = string("app_list.mode_whitelist")
    static let appListModeBlacklist = string("app_list.mode_blacklist")
    static let appListModeGlobalDesc = string("app_list.mode_global_desc")
    static let appListModeWhitelistDesc = string("app_list.mode_whitelist_desc")
    static let appListModeBlacklistDesc = string("app_list.mode_blacklist_desc")
    static let appListTitle = string("app_list.title")
    static let appListEmpty = string("app_list.empty")
    static let appListAddButton = string("app_list.add_button")
    static let appListRemove = string("app_list.remove")
    static let appListManageButton = string("app_list.manage_button")
    static let appListManageTitle = string("app_list.manage_title")
    static let appListWhitelistTitle = string("app_list.whitelist_title")
    static let appListBlacklistTitle = string("app_list.blacklist_title")
    static let appListWhitelistSubtitle = string("app_list.whitelist_subtitle")
    static let appListBlacklistSubtitle = string("app_list.blacklist_subtitle")
    static let appListWhitelistEmpty = string("app_list.whitelist_empty")
    static let appListBlacklistEmpty = string("app_list.blacklist_empty")
    static let appListManageWhitelist = string("app_list.manage_whitelist")
    static let appListManageBlacklist = string("app_list.manage_blacklist")

    // MARK: - App Picker
    static let appPickerTitle = string("app_picker.title")
    static let appPickerSearch = string("app_picker.search")
    static let appPickerNoApps = string("app_picker.no_apps")
    static let appPickerNoResults = string("app_picker.no_results")
    static let appPickerLoading = string("app_picker.loading")
    static let appPickerAdded = string("app_picker.added")

    // MARK: - Update
    static let updateAvailableTitle = string("update.available_title")
    static let updateNewVersion = string("update.new_version")
    static let updateForceRequired = string("update.force_required")
    static let updateNow = string("update.now")
    static let updateLater = string("update.later")
    static let updateSkip = string("update.skip")
    static let updateCheckFailed = string("update.check_failed")
    static let updateNoNewVersion = string("update.no_new_version")
    static let updateAlreadyLatest = string("update.already_latest")
}
