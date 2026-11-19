extends Node
## Google Play Billing for the one-time "Remove Ads" product (USD 4.99, product id
## `remove_ads`). The price shown is the localized Play price when available.
## No-ops on desktop; entitlement is persisted locally and restored from Play.

signal purchased
signal failed(reason: String)
signal state_changed

const PRODUCT := "remove_ads"

var available := false
var connected := false
var price := "$4.99"
var status := ""

var _client: BillingClient
var _started := false
var _products_ok := false
var _restoring := false
var _busy := false


func _ready() -> void:
	available = OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling")


func start() -> void:
	if _started or not available:
		return
	_started = true
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_products)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledge)
	_client.start_connection()


func _on_connected() -> void:
	connected = true
	_products_ok = false
	status = ""
	_client.query_product_details([PRODUCT], BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)
	state_changed.emit()


func _on_disconnected() -> void:
	connected = false
	state_changed.emit()


func _on_connect_error(code: int, message: String) -> void:
	connected = false
	status = "Google Play is unavailable (%d)." % code
	push_warning("[Iap] connect error %d: %s" % [code, message])
	state_changed.emit()


func _money_offer(p: Dictionary) -> String:
	var offers = p.get("one_time_purchase_offer_details_list", [])
	if offers is Array:
		for o in offers:
			if o is Dictionary and String(o.get("formatted_price", "")) != "":
				return String(o["formatted_price"])
	return ""


func _on_products(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		status = "Remove Ads is not configured in Play Console yet."
		state_changed.emit()
		return
	for p in r.get("product_details", []):
		if p is Dictionary and String(p.get("product_id", "")) == PRODUCT:
			_products_ok = true
			var money := _money_offer(p)
			if money != "":
				price = money
			status = ""
			state_changed.emit()
			return
	status = "Remove Ads is not available."
	state_changed.emit()


func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		if _restoring:
			_restoring = false
			failed.emit("Could not reach Google Play. Check your connection.")
		return
	var found := false
	for p in r.get("purchases", []):
		if p is Dictionary and _handle_purchase(p):
			found = true
	if _restoring:
		_restoring = false
		if not found:
			if Game.remove_ads():
				Game.set_remove_ads(false)
				Ads.disable_ads()
			status = "No previous purchase found for this Google account."
			failed.emit(status)
			state_changed.emit()
	elif Game.remove_ads() and not found:
		pass  # keep the local entitlement when Play returns nothing at startup


func _on_purchase_updated(r: Dictionary) -> void:
	_busy = false
	var code := int(r.get("response_code", -1))
	if code != BillingClient.BillingResponseCode.OK:
		if code == BillingClient.BillingResponseCode.USER_CANCELED:
			status = "Purchase cancelled."
			state_changed.emit()
		else:
			status = String(r.get("debug_message", "The purchase could not be completed."))
			failed.emit(status)
			state_changed.emit()
		return
	for p in r.get("purchases", []):
		if p is Dictionary:
			_handle_purchase(p)


func _handle_purchase(p: Dictionary) -> bool:
	var ids = p.get("product_ids", [])
	if not (ids is Array and PRODUCT in ids):
		return false
	var state := int(p.get("purchase_state", 0))
	if state == BillingClient.PurchaseState.PURCHASED:
		if not bool(p.get("is_acknowledged", false)):
			var token := String(p.get("purchase_token", ""))
			if token != "" and _client != null:
				_client.acknowledge_purchase(token)
		_unlock()
		return true
	if state == BillingClient.PurchaseState.PENDING:
		status = "Purchase pending. It unlocks when Google Play completes it."
		failed.emit(status)
		state_changed.emit()
		return true
	return false


func _unlock() -> void:
	if Game.remove_ads():
		status = "Remove Ads is active. Thank you."
		state_changed.emit()
		return
	Game.set_remove_ads(true)
	status = "Ads removed. Thank you."
	purchased.emit()
	state_changed.emit()


func _on_acknowledge(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		push_warning("[Iap] acknowledge failed; will retry on next launch")


func buy() -> bool:
	if not available:
		failed.emit("Google Play purchases are only available in the Android build.")
		return false
	if Game.remove_ads():
		return true
	if not _started:
		start()
	if not connected:
		status = "Connecting to Google Play. Try again in a moment."
		failed.emit(status)
		state_changed.emit()
		return false
	if _busy:
		return false
	if not _products_ok:
		_client.query_product_details([PRODUCT], BillingClient.ProductType.INAPP)
		status = "Checking the store. Try again in a moment."
		failed.emit(status)
		state_changed.emit()
		return false
	var r: Dictionary = _client.purchase(PRODUCT)
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		status = String(r.get("debug_message", "The store could not start the purchase."))
		failed.emit(status)
		state_changed.emit()
		return false
	_busy = true
	status = "Follow the Google Play purchase sheet."
	state_changed.emit()
	return true


func restore() -> void:
	if not available:
		failed.emit("Google Play purchases are only available in the Android build.")
		return
	if not _started:
		start()
	if not connected:
		failed.emit("Connecting to Google Play. Try again in a moment.")
		return
	_restoring = true
	_client.query_purchases(BillingClient.ProductType.INAPP)
