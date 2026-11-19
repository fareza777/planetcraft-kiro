extends Node
## AdMob integration. Banner is menu-only and is placed above Android's navigation bar.
## Interstitials run after planet jumps / respawns with a cooldown. Rewarded ads grant shards.
## Everything no-ops on desktop, in the editor, and after Remove Ads is owned.

signal banner_changed(visible: bool, height_dp: int, screen_height_dp: int)
signal rewarded_granted(shards: int)
signal rewarded_failed(reason: String)

const TEST_BANNER := "ca-app-pub-3940256099942544/9214589741"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const REWARD_SHARDS := 25
const NAV_MARGIN_DP := 56
const BANNER_WIDTH_DP := 320
const INTERSTITIAL_GAP := 120.0
const INTERSTITIAL_MAX := 2
const INTERSTITIAL_WARMUP := 60.0

var available := false
var initialized := false
var reward_ready := false

var _started := false
var _disabled := false
var _banner_wanted := false
var _banner: AdView
var _banner_loaded := false
var _banner_height := 0
var _density := 1.0
var _screen_dp := Vector2i(1280, 720)
var _interstitial: InterstitialAd
var _interstitial_loader: InterstitialAdLoader
var _interstitial_showing := false
var _rewarded: RewardedAd
var _rewarded_loader: RewardedAdLoader
var _last_interstitial := -9999.0
var _interstitial_count := 0
var _session_start := 0.0
var _consent_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_start = _now()
	available = OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob")
	if available and Iap != null:
		Iap.purchased.connect(disable_ads)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func start() -> void:
	if _started or _disabled:
		return
	_started = true
	if not available or Game.remove_ads():
		return
	_request_consent()


func _request_consent() -> void:
	if _consent_done:
		return
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		params, _on_consent_update, _on_consent_update_failed)


func _on_consent_update() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_failed)
	else:
		_init_sdk()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	form.show(_on_consent_form_dismissed)


func _on_consent_form_dismissed(_e: FormError) -> void:
	_init_sdk()


func _on_consent_form_failed(_e: FormError) -> void:
	_init_sdk()


func _on_consent_update_failed(_e: FormError) -> void:
	_init_sdk()


func _init_sdk() -> void:
	_consent_done = true
	if initialized:
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		initialized = true
		_preload_interstitial()
		_preload_rewarded()
		if _banner_wanted:
			_create_banner()
	MobileAds.initialize(listener)


func show_banner() -> void:
	if _disabled or Game.remove_ads():
		return
	_banner_wanted = true
	if initialized:
		_create_banner()


func hide_banner() -> void:
	_banner_wanted = false
	if _banner != null:
		_banner.hide()
		banner_changed.emit(false, 0, _screen_dp.y)


func _create_banner() -> void:
	if _banner != null:
		_banner.show()
		_place_banner()
		return
	if not available or not initialized:
		return
	var full := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	if full == null or full.width <= 0:
		full = AdSize.new(0, 0)
	_compute_metrics(full)
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(BANNER_WIDTH_DP)
	if size == null or size.width <= 0:
		size = AdSize.new(BANNER_WIDTH_DP, 50)
	var pos := AdPosition.custom(_banner_x(size), _banner_y(size))
	_banner = AdView.new(_banner_id(), size, pos)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_loaded = true
		_banner_height = _banner.get_height()
		if not _banner_wanted:
			_banner.hide()
			return
		_place_banner()
		banner_changed.emit(true, _banner_height, _screen_dp.y)
	listener.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		push_warning("[Ads] banner failed: %s" % err.message)
		banner_changed.emit(false, 0, _screen_dp.y)
	listener.on_ad_closed = func() -> void:
		if _banner_wanted:
			_banner.show()
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())


func _compute_metrics(size: AdSize) -> void:
	# The adaptive banner asks for the full display width in dp, so the ratio to the
	# window width gives Android's real density (more reliable than screen_get_dpi).
	var win := DisplayServer.window_get_size()
	_density = maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	if size.width > 0 and win.x > 0:
		_density = maxf(1.0, float(win.x) / float(size.width))
	_screen_dp = Vector2i(int(round(win.x / _density)), int(round(win.y / _density)))


func _safe_bottom_dp() -> int:
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var inset_px := maxi(0, screen.y - (safe.position.y + safe.size.y))
	return int(ceil(inset_px / _density))


func _safe_right_dp() -> int:
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var inset_px := maxi(0, screen.x - (safe.position.x + safe.size.x))
	return int(ceil(inset_px / _density))


func _banner_y(size: AdSize) -> int:
	var h := _banner_height if _banner_loaded else size.height
	return safe_banner_y(_screen_dp.y, h, _safe_bottom_dp())


static func safe_banner_y(screen_h_dp: int, banner_h_dp: int, nav_inset_dp: int) -> int:
	var margin := maxi(NAV_MARGIN_DP, nav_inset_dp + 8)
	return clampi(screen_h_dp - banner_h_dp - margin, 0, maxi(0, screen_h_dp - banner_h_dp))


func _banner_x(size: AdSize) -> int:
	var w := _banner.get_width() if _banner_loaded and _banner != null else size.width
	return safe_banner_x(_screen_dp.x, w, _safe_right_dp())


static func safe_banner_x(screen_w_dp: int, banner_w_dp: int, right_inset_dp: int) -> int:
	var margin := maxi(NAV_MARGIN_DP, right_inset_dp + 8)
	return maxi(8, screen_w_dp - banner_w_dp - margin)


func _place_banner() -> void:
	if _banner == null:
		return
	var size := AdSize.new(_banner.get_width() if _banner_loaded else 0, _banner_height)
	_banner.set_position(AdPosition.custom(_banner_x(size), _banner_y(size)))


func _banner_id() -> String:
	return String(ProjectSettings.get_setting("planetcraft/ads/banner_unit", TEST_BANNER))


func _interstitial_id() -> String:
	return String(ProjectSettings.get_setting("planetcraft/ads/interstitial_unit", TEST_INTERSTITIAL))


func _rewarded_id() -> String:
	return String(ProjectSettings.get_setting("planetcraft/ads/rewarded_unit", TEST_REWARDED))


func _preload_interstitial() -> void:
	if _disabled or not available or Game.remove_ads():
		return
	_interstitial_loader = InterstitialAdLoader.new()
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		var fs := FullScreenContentCallback.new()
		fs.on_ad_dismissed_full_screen_content = func() -> void:
			_interstitial = null
			_interstitial_showing = false
			_preload_interstitial()
		fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
			_interstitial = null
			_interstitial_showing = false
			_preload_interstitial()
		_interstitial.full_screen_content_callback = fs
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		push_warning("[Ads] interstitial failed: %s" % err.message)
	_interstitial_loader.load(_interstitial_id(), AdRequest.new(), cb)


func maybe_interstitial(_reason := "") -> void:
	if _disabled or not available or Game.remove_ads() or not initialized:
		return
	if _interstitial == null or _interstitial_showing or _interstitial_count >= INTERSTITIAL_MAX:
		return
	var now := _now()
	if now - _session_start < INTERSTITIAL_WARMUP:
		return
	if now - _last_interstitial < INTERSTITIAL_GAP:
		return
	_last_interstitial = now
	_interstitial_count += 1
	_interstitial_showing = true
	_interstitial.show()


func _preload_rewarded() -> void:
	if _disabled or not available or Game.remove_ads():
		return
	reward_ready = false
	_rewarded_loader = RewardedAdLoader.new()
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		reward_ready = true
		var fs := FullScreenContentCallback.new()
		fs.on_ad_dismissed_full_screen_content = func() -> void:
			_rewarded = null
			_preload_rewarded()
		fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
			_rewarded = null
			rewarded_failed.emit("The ad could not be shown. Try again later.")
			_preload_rewarded()
		_rewarded.full_screen_content_callback = fs
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		reward_ready = false
		push_warning("[Ads] rewarded failed: %s" % err.message)
	_rewarded_loader.load(_rewarded_id(), AdRequest.new(), cb)


func show_rewarded() -> bool:
	if _disabled or not available or Game.remove_ads():
		rewarded_failed.emit("Rewarded ads are not available.")
		return false
	if _rewarded == null:
		if not reward_ready:
			_preload_rewarded()
		rewarded_failed.emit("The ad is still loading. Try again in a moment.")
		return false
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		Game.add_shards(REWARD_SHARDS)
		rewarded_granted.emit(REWARD_SHARDS)
	_rewarded.show(listener)
	return true


func privacy_options() -> bool:
	if not available:
		return false
	var required = UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	if int(required) != ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED:
		return false
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: pass)
	return true


func disable_ads() -> void:
	_disabled = true
	_banner_wanted = false
	reward_ready = false
	if _banner != null:
		_banner.destroy()
		_banner = null
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	banner_changed.emit(false, 0, _screen_dp.y)
